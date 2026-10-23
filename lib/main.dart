import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnimeFlvTvApp());
}

class AnimeFlvTvApp extends StatelessWidget {
  const AnimeFlvTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nya',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Botón central del D-pad (select/OK) y Enter del mando = "activar" el elemento enfocado.
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
      },
      home: const HomeScreen(),
    );
  }
}
