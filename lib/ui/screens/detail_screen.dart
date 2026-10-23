import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../data/models.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/focusable.dart';
import '../widgets/poster_card.dart';
import 'player_screen.dart';

class DetailScreen extends StatefulWidget {
  final String url;
  final String title;

  const DetailScreen({super.key, required this.url, required this.title});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<AnimeDetail> _future = scraper.detail(widget.url);
  bool _descending = true;

  void _play(AnimeDetail d, Episode ep) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        title: '${d.title} · Episodio ${ep.number}',
        episodeUrl: ep.url,
        playlist: d.episodes,
        animeTitle: d.title,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final large = isLargeScreen(context);
    final pad = large ? 48.0 : 16.0;
    return Scaffold(
      body: AsyncView<AnimeDetail>(
        future: _future,
        onRetry: () => setState(() => _future = scraper.detail(widget.url)),
        builder: (d) {
          final eps = _descending ? d.episodes.reversed.toList() : d.episodes;
          final header = _Header(detail: d, large: large, onPlayFirst: d.episodes.isEmpty
              ? null
              : () => _play(d, d.episodes.first));
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: header),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 24, pad, 8),
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  Text('Episodios (${d.episodes.length})',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Focusable(
                    onTap: () => setState(() => _descending = !_descending),
                    radius: BorderRadius.circular(20),
                    focusScale: 1.05,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(_descending ? 'Más recientes ↓' : 'Primeros ↑'),
                    ),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 8, pad, 48),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: large ? 180 : 110,
                  mainAxisExtent: 56,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemCount: eps.length,
                itemBuilder: (context, i) => Focusable(
                  focusScale: 1.06,
                  onTap: () => _play(d, eps[i]),
                  child: Container(
                    color: kSurface,
                    alignment: Alignment.center,
                    child: Text('Ep. ${eps[i].number}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AnimeDetail detail;
  final bool large;
  final VoidCallback? onPlayFirst;

  const _Header({required this.detail, required this.large, this.onPlayFirst});

  @override
  Widget build(BuildContext context) {
    final pad = large ? 48.0 : 16.0;
    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: large ? 220 : 120, child: AspectRatio(aspectRatio: 2 / 3, child: NetImage(detail.poster))),
    );
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(detail.title,
          style: TextStyle(fontSize: large ? 34 : 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in detail.genres)
          Chip(label: Text(g), visualDensity: VisualDensity.compact, side: BorderSide.none),
      ]),
      const SizedBox(height: 12),
      Text(detail.synopsis,
          maxLines: large ? 6 : 8,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: kTextDim, height: 1.4)),
      const SizedBox(height: 18),
      if (onPlayFirst != null)
        Focusable(
          autofocus: true,
          onTap: onPlayFirst!,
          radius: BorderRadius.circular(28),
          focusScale: 1.05,
          child: Container(
            color: kAccent,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow_rounded),
              SizedBox(width: 6),
              Text('Ver episodio 1', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
    ]);

    return Stack(children: [
      // Fondo difuminado con el póster
      Positioned.fill(
        child: Opacity(opacity: 0.18, child: NetImage(detail.poster)),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kBg.withValues(alpha: 0.3), kBg],
            ),
          ),
        ),
      ),
      SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            poster,
            SizedBox(width: large ? 36 : 16),
            Expanded(child: info),
          ]),
        ),
      ),
    ]);
  }
}
