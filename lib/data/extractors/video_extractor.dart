import '../../core/http.dart';
import '../models.dart';
import 'js_unpacker.dart';
import 'webview_sniffer.dart';

/// Convierte la URL de un embed (iframe) en un enlace directo m3u8/mp4.
///
/// Estrategia en cascada:
///   1. Extractores específicos por host (rápidos, sólo HTTP).
///   2. Extractor genérico: busca .m3u8/.mp4 en el HTML (también dentro de eval(p,a,c,k,e,d)).
///   3. WebView headless que carga el embed y "escucha" las peticiones de red del reproductor.
class VideoExtractor {
  final _sniffer = WebViewSniffer();

  /// Orden de preferencia. Desu y Magi (propios de jkanime) dan un m3u8 H.264 directo en el HTML:
  /// rápido y decodificado por hardware en cualquier Android TV / Google TV. El resto, por orden del sitio.
  static const _priority = ['desu', 'magi', 'mp4upload'];

  List<VideoServer> sortByPreference(List<VideoServer> servers) {
    int rank(VideoServer s) {
      final i = _priority.indexOf(s.name.toLowerCase());
      return i < 0 ? _priority.length : i;
    }

    return [...servers]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  /// Prueba cada método y, si ninguno sirve, lanza un [AppError] con lo que falló en cada paso.
  Future<StreamSource> extract(VideoServer server) async {
    final url = server.embedUrl;
    final host = Uri.parse(url).host;
    final steps = <String>[];

    if (host.contains('mp4upload')) {
      try {
        final src = await _mp4upload(url);
        if (src != null) return src;
        steps.add('MP4Upload: no hay enlace .mp4 en la página');
      } catch (e) {
        steps.add('MP4Upload: $e');
      }
    }

    // Desu/Magi (jkanime.net/jkplayer/um|umv) caen aquí: la playlist exige Referer jkanime.net.
    try {
      final generic = await _generic(url);
      if (generic != null) return generic;
      steps.add('HTML: sin enlace m3u8/mp4');
    } catch (e) {
      steps.add('HTML: $e');
    }

    // Voe, Filemoon, Streamwish... generan el enlace con JS ofuscado → WebView.
    try {
      return await _sniffer.sniff(url);
    } catch (e) {
      steps.add('WebView: $e');
    }

    throw AppError('$host → ${steps.join(' · ')}');
  }

  Future<StreamSource?> _mp4upload(String url) async {
    final page = await fetchHtml(url, referer: '$kBaseUrl/');
    final m = RegExp(r'''src:\s*["']([^"']+\.mp4[^"']*)["']''').firstMatch(page);
    if (m == null) return null;
    // MP4Upload valida el Referer al servir el archivo.
    return StreamSource(
      url: m.group(1)!,
      isHls: false,
      headers: {'Referer': 'https://www.mp4upload.com/', 'User-Agent': kUserAgent},
    );
  }

  Future<StreamSource?> _generic(String url) async {
    var page = await fetchHtml(url, referer: '$kBaseUrl/');
    for (final packed in JsUnpacker.findAll(page)) {
      page += '\n${JsUnpacker.unpack(packed)}';
    }
    final m = RegExp(r'''https?://[^\s"'<>\\]+?\.(m3u8|mp4)(\?[^\s"'<>\\]*)?''').firstMatch(page);
    if (m == null) return null;
    final origin = Uri.parse(url).origin;
    return StreamSource(
      url: m.group(0)!,
      isHls: m.group(1) == 'm3u8',
      headers: {'Referer': '$origin/', 'Origin': origin, 'User-Agent': kUserAgent},
    );
  }
}
