import 'package:flutter/material.dart';

import '../theme.dart';

/// Tarjeta destacada con degradado violeta y efecto al tocar o pasar el
/// mouse: para lo más importante de cada pantalla.
class HeroCard extends StatefulWidget {
  const HeroCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scale = _down ? 0.98 : (_hover ? 1.01 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF5B3DF5), Color(0xFF2A2163), MagraColors.surface],
                stops: [0, 0.55, 1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: MagraColors.violet.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: MagraColors.violet.withValues(alpha: _hover ? 0.35 : 0.18),
                  blurRadius: _hover ? 28 : 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
