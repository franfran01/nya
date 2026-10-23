import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/http.dart';
import '../models.dart';

/// Carga el embed en un WebView invisible y captura la primera petición a un .m3u8/.mp4.
/// Es el "último recurso": más lento (5-15 s) pero funciona con hosts cuyo enlace
/// se genera con JavaScript ofuscado o tokens temporales.
class WebViewSniffer {
  static final _media = RegExp(r'\.(m3u8|mp4)(\?|$)|/hls/|master\.txt', caseSensitive: false);

  Future<StreamSource?> sniff(String embedUrl, {Duration timeout = const Duration(seconds: 25)}) async {
    final found = Completer<StreamSource?>();
    final origin = Uri.parse(embedUrl).origin;

    void check(String? url) {
      if (url == null || found.isCompleted || !_media.hasMatch(url)) return;
      // Ignora anuncios VAST/pre-roll típicos.
      if (url.contains('vast') || url.contains('/ads/')) return;
      found.complete(StreamSource(
        url: url,
        isHls: !url.contains('.mp4'),
        headers: {'Referer': '$origin/', 'Origin': origin, 'User-Agent': kUserAgent},
      ));
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
        check(request.url.toString());
        return null; // no modificamos la petición
      },
      onLoadResource: (controller, resource) => check(resource.url?.toString()),
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
      await webView.run();
      return await found.future.timeout(timeout, onTimeout: () => null);
    } finally {
      ticker.cancel();
      await webView.dispose();
    }
  }
}
