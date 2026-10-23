import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/db_errors.dart';
import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import '../../core/recommendation/alt_sessions.dart';
import '../../core/theme.dart';
import '../today/activity_log.dart';

/// kcal netas estimadas de [s] para [weightKg].
double altKcal(AltSession s, double weightKg, [int? minutes]) =>
    netBurnKcal(Activity('alt_${s.id}', s.name, s.met), (minutes ?? s.minutes).toDouble(), weightKg);

/// Elegir una sesión para variar el día. Devuelve el id, '' para volver a
/// la rutina o null si se cierra.
Future<String?> pickAltSession(BuildContext context,
        {required List<AltSession> options, required double weightKg, String? current}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, scroll) {
          final theme = Theme.of(sheet);
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text('Variar el entreno de hoy', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Cambia la rutina de hoy por otra sesión. Están adaptadas a tu equipo, tu '
                'nivel y tus cuidados; tu rutina sigue igual los demás días.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (current != null)
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheet, ''),
                  icon: const Icon(Icons.undo),
                  label: const Text('Volver a mi rutina'),
                ),
              for (final s in options)
                Card(
                  margin: const EdgeInsets.only(top: 8),
                  shape: s.id == current
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: MagraColors.lime),
                        )
                      : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                    title: Text(s.name),
                    subtitle: Text(
                      '${s.style} · ${s.minutes} min · intensidad ${s.intensity.label.toLowerCase()} · '
                      '~${fmt(altKcal(s, weightKg))} kcal\n${s.why}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(sheet, s.id),
                  ),
                ),
            ],
          );
        },
      ),
    );

/// Los bloques de una sesión alternativa.
class AltBlocks extends StatelessWidget {
  const AltBlocks({super.key, required this.session, this.done, this.onToggle});

  final AltSession session;

  /// Ítems marcados ("bloque-ítem"); sin [onToggle] no se marcan.
  final Set<String>? done;
  final void Function(String key)? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var b = 0; b < session.blocks.length; b++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.blocks[b].title, style: theme.textTheme.titleSmall),
                  for (var i = 0; i < session.blocks[b].items.length; i++)
                    onToggle == null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('• ${session.blocks[b].items[i]}'),
                          )
                        : CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: done!.contains('$b-$i'),
                            onChanged: (_) => onToggle!('$b-$i'),
                            title: Text(session.blocks[b].items[i]),
                          ),
                  if (session.blocks[b].note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(session.blocks[b].note!, style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          ),
        for (final c in session.cautions)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Cuidado: $c', style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// Hacer la sesión: cronómetro, ítems para marcar y guardarla como
/// ejercicio del día (con sus calorías).
class AltSessionPage extends ConsumerStatefulWidget {
  const AltSessionPage({super.key, required this.session, required this.day, required this.weightKg});

  final AltSession session;
  final DateTime day;
  final double weightKg;

  @override
  ConsumerState<AltSessionPage> createState() => _AltSessionPageState();
}

class _AltSessionPageState extends ConsumerState<AltSessionPage> {
  final _clock = Stopwatch();
  final _done = <String>{};
  Timer? _tick;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _toggleClock() {
    setState(() {
      if (_clock.isRunning) {
        _clock.stop();
        _tick?.cancel();
      } else {
        _clock.start();
        _tick = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  Future<void> _finish() async {
    final elapsed = (_clock.elapsed.inSeconds / 60).round();
    final minutes = TextEditingController(text: '${elapsed >= 5 ? elapsed : widget.session.minutes}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Guardar sesión'),
        content: TextField(
          controller: minutes,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutos', suffixText: 'min'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Seguir')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    final m = min(300, max(1, int.tryParse(minutes.text.trim()) ?? widget.session.minutes));
    final s = widget.session;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(exerciseLogRepositoryProvider).add(ExerciseEntry.fromActivity(
            Activity('alt_${s.id}', s.name, s.met),
            m,
            date: widget.day,
            weightKg: widget.weightKg,
          ));
      ref.invalidate(exerciseLogProvider(widget.day));
      _clock.stop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('¡Bien hecho! Guardaste ${s.name}: ${fmt(altKcal(s, widget.weightKg, m))} kcal en Hoy.')));
      Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = saveErrorMessage(err, migration: '0005_exercise_fasting.sql');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.session;
    final e = _clock.elapsed;
    String two(int v) => v.toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('${two(e.inMinutes)}:${two(e.inSeconds % 60)}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: MagraColors.lime)),
                Text('meta ${s.minutes} min · intensidad ${s.intensity.label.toLowerCase()}',
                    textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Center(
                  child: FilledButton.tonalIcon(
                    onPressed: _toggleClock,
                    icon: Icon(_clock.isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(_clock.isRunning ? 'Pausar' : (e == Duration.zero ? 'Iniciar' : 'Reanudar')),
                  ),
                ),
                const SizedBox(height: 16),
                AltBlocks(
                  session: s,
                  done: _done,
                  onToggle: (k) => setState(() => _done.contains(k) ? _done.remove(k) : _done.add(k)),
                ),
                if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _finish,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Terminar y guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
