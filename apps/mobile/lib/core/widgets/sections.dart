import 'package:flutter/material.dart';

import '../theme.dart';

/// Una parte de una pantalla: título, ícono, resumen de una línea y su
/// contenido, que se abre con un toque.
class PageSection {
  const PageSection({
    required this.title,
    required this.icon,
    required this.child,
    this.summary,
    this.initiallyOpen = false,
  });

  final String title;
  final IconData icon;

  /// Lo esencial de la sección en una línea (se ve cerrada).
  final String? summary;
  final Widget child;
  final bool initiallyOpen;
}

/// Índice de subtítulos tocables y secciones que se abren y cierran: la
/// pantalla muestra lo esencial y el detalle queda a un toque.
class SectionList extends StatefulWidget {
  const SectionList({super.key, required this.sections});

  final List<PageSection> sections;

  @override
  State<SectionList> createState() => _SectionListState();
}

class _SectionListState extends State<SectionList> {
  late final Set<String> _open = {
    for (final s in widget.sections) if (s.initiallyOpen) s.title,
  };
  final _keys = <String, GlobalKey>{};

  GlobalKey _key(String title) => _keys.putIfAbsent(title, GlobalKey.new);

  void _toggle(String title) => setState(
      () => _open.contains(title) ? _open.remove(title) : _open.add(title));

  void _goTo(String title) {
    setState(() => _open.add(title));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _key(title).currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sections.length > 1) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sections)
                ActionChip(
                  avatar: Icon(s.icon, size: 16, color: MagraColors.lime),
                  label: Text(s.title),
                  onPressed: () => _goTo(s.title),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        for (final s in sections) ...[
          _SectionTile(
            key: _key(s.title),
            section: s,
            open: _open.contains(s.title),
            onTap: () => _toggle(s.title),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open.contains(s.title)
                ? Padding(padding: const EdgeInsets.only(bottom: 8), child: s.child)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({super.key, required this.section, required this.open, required this.onTap});

  final PageSection section;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: open ? MagraColors.lime : MagraColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(section.icon, size: 20,
                    color: open ? MagraColors.background : MagraColors.lime),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title, style: theme.textTheme.titleMedium),
                    if (section.summary != null && section.summary!.isNotEmpty)
                      Text(section.summary!, style: theme.textTheme.bodySmall,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Semantics(
                label: open ? 'Cerrar ${section.title}' : 'Abrir ${section.title}',
                child: AnimatedRotation(
                  turns: open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.chevron_right, color: MagraColors.textSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
