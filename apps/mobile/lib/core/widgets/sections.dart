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
    this.value,
    this.initiallyOpen = false,
  });

  /// Cifra corta para la tarjeta de la cuadrícula ("3.240 / 7.000").
  final String? value;

  final String title;
  final IconData icon;

  /// Lo esencial de la sección en una línea (se ve cerrada).
  final String? summary;
  final Widget child;
  final bool initiallyOpen;
}

/// Secciones que se abren y cierran: la pantalla muestra lo esencial y el
/// detalle queda a un toque.
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

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      key: ValueKey('section-${open ? 'open' : 'closed'}-${section.title}'),
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

/// Secciones secundarias como tarjetas pequeñas en dos columnas: cada una
/// muestra su cifra y, al tocarla, su detalle aparece debajo (una a la vez).
class SectionGrid extends StatefulWidget {
  const SectionGrid({super.key, required this.sections});

  final List<PageSection> sections;

  @override
  State<SectionGrid> createState() => _SectionGridState();
}

class _SectionGridState extends State<SectionGrid> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = widget.sections.where((s) => s.title == _open).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in widget.sections)
                SizedBox(
                  width: w,
                  child: Material(
                    key: ValueKey('section-${s.title == _open ? 'open' : 'closed'}-${s.title}'),
                    color: s.title == _open ? MagraColors.surfaceHigh : MagraColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: s.title == _open ? MagraColors.lime : Colors.transparent),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(() => _open = _open == s.title ? null : s.title),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(s.icon, size: 15, color: MagraColors.textSoft),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(s.title, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                            const SizedBox(height: 3),
                            Text(
                              s.value ?? s.summary ?? '',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (open.summary != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, left: 2),
                          child: Text(open.summary!, style: theme.textTheme.bodySmall),
                        ),
                      open.child,
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
