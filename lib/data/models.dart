/// Tarjeta genérica: puede ser un anime (/slug/) o un episodio (/slug/N/).
class MediaCard {
  final String title;
  final String url;
  final String image;
  final String? badge; // "Ep 4", "Serie", etc.

  const MediaCard({required this.title, required this.url, required this.image, this.badge});

  bool get isEpisode => RegExp(r'/\d+/?$').hasMatch(url);
}

class AnimeDetail {
  final String title;
  final String poster;
  final String synopsis;
  final List<String> genres;
  final List<Episode> episodes; // orden ascendente

  const AnimeDetail({
    required this.title,
    required this.poster,
    required this.synopsis,
    required this.genres,
    required this.episodes,
  });
}

class Episode {
  final int number;
  final String url;

  const Episode({required this.number, required this.url});
}

/// Botón "OPCIÓN N" de la página del episodio.
class VideoServer {
  final String name; // HLS, Voe, MP4Upload...
  final String embedUrl; // data-src decodificado de Base64
  final String lang; // Sub / Lat

  const VideoServer({required this.name, required this.embedUrl, required this.lang});
}

/// Enlace final reproducible por ExoPlayer.
class StreamSource {
  final String url;
  final bool isHls;
  final Map<String, String> headers;

  const StreamSource({required this.url, required this.isHls, this.headers = const {}});

  @override
  String toString() => 'StreamSource($url, hls=$isHls)';
}
