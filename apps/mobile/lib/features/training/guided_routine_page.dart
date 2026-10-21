import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/recommendation/exercise_guides.dart' show imageCredit;
import '../../core/recommendation/warmup.dart';
import '../../core/theme.dart';
import '../../core/widgets/progress_ring.dart';
import 'exercise_guide_page.dart';

Future<void> openGuidedRoutine(BuildContext context, String title, List<Drill> drills) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GuidedRoutinePage(title: title, drills: drills),
    ));

/// Rutina guiada paso a paso: foto animada, temporizador por ejercicio
/// (o repeticiones), avance solo al terminar y controles para saltar.
class GuidedRoutinePage extends StatefulWidget {
  const GuidedRoutinePage({super.key, required this.title, required this.drills});

  final String title;
  final List<Drill> drills;

  @override
  State<GuidedRoutinePage> createState() => _GuidedRoutinePageState();
}

class _GuidedRoutinePageState extends State<GuidedRoutinePage> {
  int _index = 0;
  int _left = 0;
  bool _running = false;
  bool _done = false;
  Timer? _timer;

  Drill get _drill => widget.drills[_index];

  @override
  void initState() {
    super.initState();
    _load(0, autostart: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _load(int i, {bool autostart = true}) {
    _timer?.cancel();
    setState(() {
      _index = i;
      _done = false;
      _left = widget.drills[i].totalSeconds;
      _running = false;
    });
    if (autostart && widget.drills[i].seconds != null) _start();
  }

  void _start() {
    _timer?.cancel();
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left <= 1) {
        _next();
      } else {
        setState(() => _left--);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _next() {
    if (_index < widget.drills.length - 1) {
      _load(_index + 1);
    } else {
      _timer?.cancel();
      setState(() {
        _running = false;
        _done = true;
      });
    }
  }

  String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.drills.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _done ? _finished(theme) : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    for (var i = 0; i < total; i++)
                      Expanded(
                        child: Container(
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i <= _index ? MagraColors.lime : MagraColors.outlineSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('${_index + 1} de $total', style: theme.textTheme.labelLarge),
                Text(_drill.name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                if (_drill.images.isNotEmpty)
                  MoveFrames(key: ValueKey(_index), images: _drill.images, height: 200),
                const SizedBox(height: 12),
                Text(_drill.cue, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                Center(
                  child: _drill.seconds != null
                      ? ProgressRing(
                          key: ValueKey('ring$_index'),
                          value: _drill.totalSeconds == 0
                              ? 0
                              : 1 - _left / _drill.totalSeconds,
                          size: 120,
                          center: Text(_mmss(_left),
                              style: theme.textTheme.headlineSmall),
                        )
                      : Text(_drill.dose,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(color: theme.colorScheme.primary)),
                ),
                if (_drill.seconds != null && _drill.perSide)
                  Center(
                    child: Text(
                      _left > _drill.seconds! ? 'Primer lado' : 'Cambia de lado',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.outlined(
                      tooltip: 'Anterior',
                      onPressed: _index == 0 ? null : () => _load(_index - 1, autostart: false),
                      icon: const Icon(Icons.skip_previous),
                    ),
                    const SizedBox(width: 12),
                    if (_drill.seconds != null)
                      IconButton.filled(
                        iconSize: 36,
                        tooltip: _running ? 'Pausa' : 'Comenzar',
                        onPressed: _running ? _pause : _start,
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                      )
                    else
                      FilledButton(onPressed: _next, child: const Text('Listo')),
                    const SizedBox(width: 12),
                    IconButton.outlined(
                      tooltip: 'Siguiente',
                      onPressed: _next,
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('La rutina', style: theme.textTheme.titleMedium),
                for (var i = 0; i < total; i++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    selected: i == _index,
                    selectedColor: MagraColors.lime,
                    leading: Icon(i < _index
                        ? Icons.check_circle
                        : (i == _index ? Icons.play_circle : Icons.circle_outlined)),
                    title: Text(widget.drills[i].name),
                    trailing: Text(widget.drills[i].dose),
                    onTap: () => _load(i, autostart: false),
                  ),
                const SizedBox(height: 8),
                Text(imageCredit, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _finished(ThemeData theme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, size: 64, color: MagraColors.lime),
              const SizedBox(height: 12),
              Text('¡${widget.title} completo!', style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
}
