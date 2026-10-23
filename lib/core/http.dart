import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const kBaseUrl = 'https://jkanime.net';
const kUserAgent =
    'Mozilla/5.0 (Linux; Android 12; Android TV) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

final _client = http.Client();

/// Error con un mensaje legible para mostrar en pantalla (la TV no tiene logcat a mano).
class AppError implements Exception {
  final String message;
  const AppError(this.message);

  @override
  String toString() => message;
}

/// GET que devuelve el HTML decodificado como UTF-8 (el sitio sirve UTF-8).
Future<String> fetchHtml(String url, {String? referer}) async {
  final uri = Uri.parse(url);
  final http.Response res;
  try {
    res = await _client.get(uri, headers: {
      'User-Agent': kUserAgent,
      'Accept-Language': 'es-ES,es;q=0.9',
      if (referer != null) 'Referer': referer,
    }).timeout(const Duration(seconds: 20));
  } on TimeoutException {
    throw AppError('${uri.host} no respondió en 20 s');
  } catch (e) {
    // DNS, sin conexión, certificado TLS rechazado (fecha de la box mal puesta, CA viejas)...
    throw AppError('no se pudo conectar con ${uri.host}: $e');
  }
  if (res.statusCode >= 400) {
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    final why = body.contains('FortiGuard') || body.contains('Web Filter')
        ? ' (bloqueado por el filtro web de la red)'
        : body.contains('cf-chl') || body.contains('Just a moment')
            ? ' (desafío de Cloudflare)'
            : '';
    throw AppError('HTTP ${res.statusCode} en ${uri.host}$why');
  }
  return utf8.decode(res.bodyBytes, allowMalformed: true);
}
