import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import '../../core/recommendation/progression.dart';
import '../../core/recommendation/training_plan.dart';
import '../today/activity_log.dart';

/// Registrar una sesión de fuerza: cada serie con repeticiones y kilos,
/// partiendo de la carga que MAGRA sugiere según el historial.
class WorkoutSessionPage extends ConsumerStatefulWidget {
  const WorkoutSessionPage({
    super.key,
    required this.day,
    required this.history,
    required this.weightKg,
    required this.today,
    this.intense = false,
  });

  final TrainingDay day;
  final List<WorkoutSession> history;
  final double weightKg;
  final DateTime today;

  /// Para las calorías: pesas intensas (avanzado) o moderadas.
  final bool intense;

  @override
  ConsumerState<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _Row {
  _Row({String kg = ''}) : kg = TextEditingController(text: kg);

  final reps = TextEditingController();
  final TextEditingController kg;

  void dispose() {
    reps.dispose();
    kg.dispose();
  }
}

class _WorkoutSessionPageState extends ConsumerState<WorkoutSessionPage> {
  late final List<NextTarget> _targets = [
    for (final e in widget.day.exercises)
      nextTarget(e, historyOf(e.name, widget.history)),
  ];
  late final List<List<_Row>> _rows = [
    for (var i = 0; i < widget.day.exercises.length; i++)
      [
        for (var k = 0; k < widget.day.exercises[i].sets; k++)
          _Row(kg: _kgText(_targets[i].kg)),
      ],
  ];
  late final _minutes =
      TextEditingController(text: '${widget.day.strengthMinutes}');
  bool _busy = false;
  String? _error;

  static String _kgText(double? kg) =>
      kg == null || kg == 0 ? '' : (kg % 1 == 0 ? kg.round().toString() : fmt(kg, 1));

  @override
  void dispose() {
    for (final list in _rows) {
      for (final r in list) {
        r.dispose();
      }
    }
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final logs = <ExerciseLog>[];
    for (var i = 0; i < widget.day.exercises.length; i++) {
      final sets = <SetLog>[];
      for (final r in _rows[i]) {
        final reps = parseNum(r.reps.text);
        if (reps == null || reps <= 0) continue;
        final kg = r.kg.text.trim().isEmpty ? 0.0 : parseNum(r.kg.text);
        if (reps > 100 || kg == null || kg < 0 || kg > 500) {
          setState(() => _error = 'Revisa ${widget.day.exercises[i].name}: '
              'repeticiones hasta 100 y kilos entre 0 y 500.');
          return;
        }
        sets.add(SetLog(reps.round(), kg));
      }
      if (sets.isNotEmpty) {
        logs.add(ExerciseLog(name: widget.day.exercises[i].name, sets: sets));
      }
    }
    final minutes = parseNum(_minutes.text)?.round();
    if (logs.isEmpty) {
      setState(() => _error = 'Anota las repeticiones de al menos una serie.');
      return;
    }
    if (minutes == null || minutes < 1 || minutes > 300) {
      setState(() => _error = 'Escribe cuántos minutos duró (1–300).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(workoutRepositoryProvider).add(WorkoutSession(
            date: widget.today,
            title: widget.day.title,
            minutes: minutes,
            exercises: logs,
          ));
      // Las calorías del entreno van a la tarjeta Ejercicio de Hoy.
      final activity = activityById(widget.intense ? 'pesas_vig' : 'pesas_mod')!;
      await ref.read(exerciseLogRepositoryProvider).add(ExerciseEntry.fromActivity(
          activity, minutes,
          date: widget.today, weightKg: widget.weightKg));
      ref.invalidate(workoutsProvider);
      ref.invalidate(exerciseLogProvider(widget.today));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      appBar: AppBar(title: Text(widget.day.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (var i = 0; i < widget.day.exercises.length; i++)
                  _exerciseCard(theme, i, decimal),
                const SizedBox(height: 8),
                TextField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duración de la fuerza',
                    suffixText: 'min',
                    helperText: 'Las calorías se suman solas a Ejercicio en Hoy.',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _finish,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Terminar sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _exerciseCard(ThemeData theme, int i, TextInputType decimal) {
    final ex = widget.day.exercises[i];
    final t = _targets[i];
    final weighted = ex.loadStep > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ex.name, style: theme.textTheme.titleMedium),
            Text(ex.prescription, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              t.kg != null && t.kg! > 0
                  ? 'Hoy: ${fmt(t.kg, t.kg! % 1 == 0 ? 0 : 1)} kg × ${t.reps}'
                  : 'Hoy: ${t.reps} repeticiones por serie',
              style: theme.textTheme.titleSmall?.copyWith(
                  color: t.deload ? theme.colorScheme.error : theme.colorScheme.primary),
            ),
            Text(t.note, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            for (var k = 0; k < _rows[i].length; k++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(width: 64, child: Text('Serie ${k + 1}')),
                    Expanded(
                      child: TextField(
                        controller: _rows[i][k].reps,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Reps',
                          hintText: '${t.reps}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _rows[i][k].kg,
                        keyboardType: decimal,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: weighted ? 'Kg' : 'Kg (opcional)',
                          suffixText: 'kg',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _rows[i].length >= 8
                    ? null
                    : () => setState(() => _rows[i].add(_Row(
                        kg: _rows[i].isEmpty ? '' : _rows[i].last.kg.text))),
                icon: const Icon(Icons.add),
                label: const Text('Serie'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
