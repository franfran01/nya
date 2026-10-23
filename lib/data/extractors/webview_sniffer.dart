import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/http.dart';
import '../models.dart';

/// Carga el embed en un WebView invisible y captura la primera petición a un .m3u8/.mp4.
/// Es el "último recurso": más lento (5-15 s) pero funciona con hosts cuyo enlace
/// se genera con JavaScript ofuscado o tokens temporales.
class WebViewSniffer {
  static final _media = RegExp(r'\.(m3u8|mp4)(\?|$)|/hls/|master\.txt', caseSensitive: false);

  /// Lanza un [AppError] que explica en qué punto se quedó: el WebView no arrancó, la página
  /// del embed falló, el JS del reproductor dio error, o nunca pidió un video.
  Future<StreamSource> sniff(String embedUrl, {Duration timeout = const Duration(seconds: 25)}) async {
    final found = Completer<StreamSource?>();
    final origin = Uri.parse(embedUrl).origin;
    String? pageError; // error al cargar el documento principal
    String? jsError; // primer error de JS: en un WebView viejo suele ser un SyntaxError
    var loaded = false;

    void check(String? url, [Map<String, String>? requestHeaders]) {
      if (url == null || found.isCompleted || !_media.hasMatch(url)) return;
      // Ignora anuncios VAST/pre-roll típicos.
      if (url.contains('vast') || url.contains('/ads/')) return;
      found.complete(_source(url, origin, requestHeaders));
    }

    final webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(embedUrl),
        headers: {'Referer': '$kBaseUrl/'},
      ),
      initialSettings: InAppWebViewSettings(
        userAgent: kUserAgent,
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        useShouldInterceptRequest: true,
        useOnLoadResource: true,
        supportMultipleWindows: false, // bloquea popups de anuncios
      ),
      shouldInterceptRequest: (controller, request) async {
        check(request.url.toString(), request.headers);
        return null; // no modificamos la petición
      },
      onLoadResource: (controller, resource) => check(resource.url?.toString()),
      onLoadStop: (controller, url) => loaded = true,
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame ?? false) pageError ??= error.description;
      },
      onReceivedHttpError: (controller, request, response) {
        if (request.isForMainFrame ?? false) pageError ??= 'HTTP ${response.statusCode}';
      },
      onConsoleMessage: (controller, msg) {
        if (msg.messageLevel == ConsoleMessageLevel.ERROR) jsError ??= msg.message;
      },
    );

    // Muchos reproductores (JWPlayer, Plyr, video.js) necesitan un "play" para pedir el stream.
    // Se reintenta cada 2 s: JW Player (Voe) se inicializa después de onLoadStop y tras una redirección.
    final ticker = Timer.periodic(const Duration(seconds: 2), (_) {
      webView.webViewController?.evaluateJavascript(source: '''
        (function(){
          try { if (window.jwplayer) { jwplayer().setMute(true); jwplayer().play(); } } catch(e) {}
          try { document.querySelectorAll('video').forEach(v => { v.muted = true; v.play(); }); } catch(e) {}
          var b = document.querySelector('.vjs-big-play-button, .plyr__control--overlaid, .jw-display-icon-container, #play, .play');
          if (b) b.click();
        })();
      ''');
    });

    try {
      // En TV boxes con un WebView del sistema viejo o ausente, run() puede no terminar nunca.
      try {
        await webView.run().timeout(const Duration(seconds: 10));
      } on TimeoutException {
        throw AppError('el WebView no arrancó en 10 s (${await _webViewVersion()})');
      }
      final src = await found.future.timeout(timeout, onTimeout: () => null);
      if (src != null) return src;

      final why = pageError != null
          ? 'la página del embed falló: $pageError'
          : !loaded
              ? 'la página del embed no terminó de cargar'
              : jsError != null
                  ? 'error de JS en el reproductor: ${_short(jsError!)}'
                  : 'el reproductor no pidió ningún video';
      throw AppError('$why en ${timeout.inSeconds} s (${await _webViewVersion()})');
    } finally {
      ticker.cancel();
      await webView.dispose();
    }
  }

  static Future<String> _webViewVersion() async {
    try {
      final p = await InAppWebViewController.getCurrentWebViewPackage();
      return 'WebView ${p?.versionName ?? 'desconocido'}';
    } catch (_) {
      return 'WebView desconocido';
    }
  }

  static String _short(String s) => s.length > 80 ? '${s.substring(0, 80)}…' : s;

  /// Copia las cabeceras que el WebView envió de verdad (Referer del iframe final tras las
  /// redirecciones, Origin...) y sus cookies: varios hosts devuelven 403 a ExoPlayer sin ellas.
  static Future<StreamSource> _source(String url, String origin, Map<String, String>? requestHeaders) async {
    final headers = {'Referer': '$origin/', 'Origin': origin, 'User-Agent': kUserAgent};
    for (final MapEntry(:key, :value) in (requestHeaders ?? const {}).entries) {
      headers.removeWhere((k, _) => k.toLowerCase() == key.toLowerCase());
      headers[key] = value;
    }
    headers['User-Agent'] = kUserAgent; // ExoPlayer lo toma de aquí
    try {
      final cookies = await CookieManager.instance().getCookies(url: WebUri(url));
      if (cookies.isNotEmpty) headers['Cookie'] = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    } catch (_) {}
    return StreamSource(url: url, isHls: !url.contains('.mp4'), headers: headers);
  }
}
