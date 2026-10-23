import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../data/models.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/focusable.dart';
import '../widgets/poster_card.dart';
import 'grid_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<({List<MediaCard> episodes, List<MediaCard> animes})> _future = scraper.home();

  @override
  Widget build(BuildContext context) {
    final pad = isLargeScreen(context) ? 48.0 : 16.0;
    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          future: _future,
          onRetry: () => setState(() => _future = scraper.home()),
          builder: (data) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Row(children: [
                  const Text('nya',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kAccent)),
                  const Spacer(),
                  _NavButton(
                    icon: Icons.search,
                    label: 'Buscar',
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                  ),
                  const SizedBox(width: 12),
                  _NavButton(
                    icon: Icons.grid_view_rounded,
                    label: 'Directorio',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GridScreen(
                          title: 'Directorio',
                          loadPage: (p) => scraper.directory(page: p),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              _Row(title: 'Últimos episodios', cards: data.episodes, pad: pad, autofocusFirst: true,
                  cardWidth: 240),
              _Row(title: 'Destacados', cards: data.animes, pad: pad),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String title;
  final List<MediaCard> cards;
  final double pad;
  final bool autofocusFirst;
  final double cardWidth;

  const _Row({
    required this.title,
    required this.cards,
    required this.pad,
    this.autofocusFirst = false,
    this.cardWidth = 160,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final height = cardWidth * (cards.first.isEpisode ? 200 / 260 : 3 / 2) + 70;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(pad, 28, pad, 12),
        child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      SizedBox(
        height: height,
        // FocusTraversalGroup: izquierda/derecha se mueve dentro de la fila,
        // arriba/abajo salta a la fila vecina.
        child: FocusTraversalGroup(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (context, i) => PosterCard(
              card: cards[i],
              width: cardWidth,
              autofocus: autofocusFirst && i == 0,
              onTap: () => openCard(context, cards[i]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: onTap,
      radius: BorderRadius.circular(24),
      focusScale: 1.05,
      child: Container(
        color: kSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ]),
      ),
    );
  }
}
