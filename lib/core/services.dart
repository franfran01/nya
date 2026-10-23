import '../data/extractors/video_extractor.dart';
import '../data/jkanime_scraper.dart';

// Instancias únicas (la app es pequeña: no hace falta un contenedor de DI).
final scraper = JkAnimeScraper();
final videoExtractor = VideoExtractor();
