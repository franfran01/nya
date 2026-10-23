import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../core/http.dart';
import 'models.dart';

/// Scraper de jkanime.net (sin API pública).
/// Todos los selectores están aquí: si el sitio cambia su HTML, sólo se toca este archivo.
class JkAnimeScraper {
  /// Portada: últimos episodios (pestaña "Animes") + destacados del carrusel.
  Future<({List<MediaCard> episodes, List<MediaCard> animes})> home() async {
    final doc = html.parse(await fetchHtml('$kBaseUrl/'));

    final episodes = [
      for (final a in doc.querySelectorAll('#animes .card > a'))
        MediaCard(
          title: a.querySelector('img')?.attributes['alt'] ?? _text(a.querySelector('.card-title')),
          url: a.attributes['href'] ?? '',
          image: a.querySelector('img')?.attributes['src'] ?? '',
          badge: _text(a.querySelector('.badge-primary')),
        ),
    ];

    final seen = <String>{};
    final animes = <MediaCard>[];
    for (final hero in doc.querySelectorAll('.hero__items')) {
      final url = hero.querySelector('a.slider-show')?.attributes['href'];
      if (url == null || !seen.add(url)) continue;
      animes.add(MediaCard(title: _text(hero.querySelector('h2')), url: url, image: _poster(url)));
    }
    return (episodes: episodes, animes: animes);
  }

  /// Directorio paginado: /directorio?p=N trae el listado como JSON embebido.
  Future<List<MediaCard>> directory({int page = 1}) async {
    final body = await fetchHtml('$kBaseUrl/directorio?p=$page');
    final json = RegExp(r'\{"current_page".*?"total":\d+\}', dotAll: true).firstMatch(body)?.group(0);
    if (json == null) return [];
    final data = jsonDecode(json) as Map<String, dynamic>;
    if (page > (data['last_page'] as int)) return [];
    return [
      for (final a in data['data'] as List)
        MediaCard(title: a['title'], url: a['url'], image: a['image'], badge: a['tipo']),
    ];
  }

  Future<List<MediaCard>> search(String query) async {
    final doc = html.parse(await fetchHtml('$kBaseUrl/buscar/${Uri.encodeComponent(query.trim())}/'));
    return [
      for (final item in doc.querySelectorAll('.page_directorio .anime__item'))
        MediaCard(
          title: _text(item.querySelector('h5 a')),
          url: item.querySelector('a')?.attributes['href'] ?? '',
          image: item.querySelector('.anime__item__pic')?.attributes['data-setbg'] ?? '',
          badge: _text(item.querySelector('li.anime')),
        ),
    ];
  }

  Future<AnimeDetail> detail(String animeUrl) async {
    final doc = html.parse(await fetchHtml(animeUrl));

    // <li><span>Episodios:</span> 12</li> — la ficha se repite (pc/móvil): vale la primera.
    final info = <String, String>{};
    for (final li in doc.querySelectorAll('li')) {
      final key = li.querySelector('span')?.text.trim() ?? '';
      if (key.endsWith(':')) info.putIfAbsent(key, () => _text(li).substring(key.length).trim());
    }

    // La lista real llega por AJAX (requiere sesión + CSRF). Las URLs son /slug/N/, así que basta
    // el último número: en emisión, el enlace al último episodio (#uep) — "Episodios:" ahí es el
    // total *planeado* (p. ej. 26 con 17 emitidos); en concluidos no hay #uep y "Episodios:" es real.
    // shortcut: asume episodios 1..N consecutivos; usar /ajax/episodes si aparecen huecos o un ep. 0.
    final uep = doc.querySelector('#uep')?.attributes['href'] ?? '';
    final last = int.tryParse(RegExp(r'/(\d+)/?$').firstMatch(uep)?.group(1) ?? '') ??
        int.tryParse(info['Episodios:'] ?? '') ??
        0;
    final base = animeUrl.endsWith('/') ? animeUrl : '$animeUrl/';

    return AnimeDetail(
      title: _text(doc.querySelector('.anime_info h3')),
      poster: doc.querySelector('.anime_pic img')?.attributes['src'] ?? _poster(animeUrl),
      synopsis: _text(doc.querySelector('.anime_info p.scroll')),
      genres: (info['Generos:'] ?? '').split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList(),
      episodes: [for (var n = 1; n <= last; n++) Episode(number: n, url: '$base$n/')],
    );
  }

  /// Servidores de un episodio: los propios (Desu, Magi) vienen como iframes en `video[i]`;
  /// los externos en `var servers = [...]` con la URL del embed en Base64.
  Future<List<VideoServer>> servers(String episodeUrl) async {
    final page = await fetchHtml(episodeUrl);
    final doc = html.parse(page);
    final result = <VideoServer>[];

    for (final m in RegExp(r'''video\[(\d+)\] = '<iframe[^>]+src="([^"]+)"''').allMatches(page)) {
      final name = _text(doc.querySelector('a.servers[data-id="${m.group(1)}"]'));
      result.add(VideoServer(name: name.isEmpty ? 'Opción ${m.group(1)}' : name, embedUrl: m.group(2)!, lang: 'Sub'));
    }

    final json = RegExp(r'var servers = (\[.*?\]);').firstMatch(page)?.group(1);
    for (final s in jsonDecode(json ?? '[]') as List) {
      final name = s['server'] as String;
      if (const {'Mediafire', '1Fichier', 'Mega'}.contains(name)) continue; // descargas, no streaming
      try {
        final url = utf8.decode(base64.decode(s['remote'] as String)).trim();
        result.add(VideoServer(name: name, embedUrl: url, lang: s['lang'] == 1 ? 'Sub' : 'Latino'));
      } on FormatException {
        // remote corrupto: se ignora ese servidor
      }
    }
    return result;
  }

  // Los pósters siguen un patrón fijo por slug.
  String _poster(String animeUrl) {
    final slug = Uri.parse(animeUrl).pathSegments.firstWhere((s) => s.isNotEmpty, orElse: () => '');
    return 'https://cdn.jkdesa.com/assets/images/animes/image/$slug.jpg';
  }

  String _text(Element? e) => e?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
}
