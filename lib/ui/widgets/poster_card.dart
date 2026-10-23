import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../theme.dart';
import 'focusable.dart';

class PosterCard extends StatelessWidget {
  final MediaCard card;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  final double width;

  const PosterCard({
    super.key,
    required this.card,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
    this.width = 170,
  });

  @override
  Widget build(BuildContext context) {
    // Episodios: miniatura 16:10; animes: póster vertical.
    final aspect = card.isEpisode ? 260 / 200 : 2 / 3;
    return SizedBox(
      width: width,
      child: Focusable(
        onTap: onTap,
        autofocus: autofocus,
        focusNode: focusNode,
        child: Container(
          color: kSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: aspect,
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(card.image),
                  if (card.badge != null && card.badge!.isNotEmpty)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(6)),
                        child: Text(card.badge!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Text(card.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NetImage extends StatelessWidget {
  final String url;
  const NetImage(this.url, {super.key});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const ColoredBox(color: kSurface);
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 400, // decodifica a baja resolución: clave en TVs con poca RAM
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: kSurface,
        child: Center(child: Icon(Icons.broken_image_outlined, color: kTextDim)),
      ),
    );
  }
}
