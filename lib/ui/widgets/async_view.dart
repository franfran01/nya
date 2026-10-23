import 'package:flutter/material.dart';

import '../theme.dart';
import 'focusable.dart';

/// FutureBuilder con estados de carga / error (con botón Reintentar enfocable).
class AsyncView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  const AsyncView({super.key, required this.future, required this.builder, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off, size: 48, color: kTextDim),
              const SizedBox(height: 12),
              Text('No se pudo cargar\n${snap.error}',
                  textAlign: TextAlign.center, style: const TextStyle(color: kTextDim)),
              const SizedBox(height: 16),
              Focusable(
                autofocus: true,
                onTap: onRetry,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Reintentar'),
                ),
              ),
            ]),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kAccent));
        return builder(snap.data as T);
      },
    );
  }
}
