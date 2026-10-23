import 'package:flutter/material.dart';

import '../theme.dart';

/// Envoltorio enfocable para D-pad: al recibir foco escala, resalta el borde y
/// se desplaza a la vista. OK/Enter/tap ejecutan [onTap].
class Focusable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  final BorderRadius radius;
  final double focusScale;

  const Focusable({
    super.key,
    required this.child,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
    this.radius = const BorderRadius.all(Radius.circular(12)),
    this.focusScale = 1.08,
  });

  @override
  State<Focusable> createState() => _FocusableState();
}

class _FocusableState extends State<Focusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _focused ? widget.focusScale : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: widget.radius,
          border: Border.all(color: _focused ? kAccent : Colors.transparent, width: 3),
          boxShadow: _focused
              ? [BoxShadow(color: kAccent.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 1)]
              : const [],
        ),
        child: InkWell(
          // InkWell ya gestiona ActivateIntent (OK/Enter) y el tap táctil.
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          borderRadius: widget.radius,
          onTap: widget.onTap,
          onFocusChange: (f) {
            setState(() => _focused = f);
            if (f) {
              Scrollable.ensureVisible(context,
                  alignment: 0.5, duration: const Duration(milliseconds: 200));
            }
          },
          child: ClipRRect(borderRadius: widget.radius, child: widget.child),
        ),
      ),
    );
  }
}
