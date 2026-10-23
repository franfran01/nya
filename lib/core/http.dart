import 'dart:convert';

import 'package:http/http.dart' as http;

const kBaseUrl = 'https://jkanime.net';
const kUserAgent =
    'Mozilla/5.0 (Linux; Android 12; Android TV) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

final _client = http.Client();

/// GET que devuelve el HTML decodificado como UTF-8 (el sitio sirve UTF-8).
Future<String> fetchHtml(String url, {String? referer}) async {
  final res = await _client.get(Uri.parse(url), headers: {
    'User-Agent': kUserAgent,
    'Accept-Language': 'es-ES,es;q=0.9',
    if (referer != null) 'Referer': referer,
  }).timeout(const Duration(seconds: 20));
  if (res.statusCode >= 400) {
    throw http.ClientException('HTTP ${res.statusCode}', Uri.parse(url));
  }
  return utf8.decode(res.bodyBytes, allowMalformed: true);
}
