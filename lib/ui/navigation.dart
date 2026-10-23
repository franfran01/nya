import 'package:flutter/material.dart';

import '../data/models.dart';
import 'screens/detail_screen.dart';
import 'screens/player_screen.dart';

/// Un episodio abre directamente el reproductor; un anime abre su ficha.
void openCard(BuildContext context, MediaCard card) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => card.isEpisode
        ? PlayerScreen(title: card.title, episodeUrl: card.url)
        : DetailScreen(url: card.url, title: card.title),
  ));
}
