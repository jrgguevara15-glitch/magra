import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/db_errors.dart';
import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import '../../core/theme.dart';
import '../training/outdoor_page.dart';
import 'activity_log.dart';

/// Ejercicio del día y cuánto suma a la meta.
class ExerciseCard extends ConsumerWidget {
  const ExerciseCard({super.key, required this.day, required this.weightKg});

  final DateTime day;
  final double weightKg;

  Future<void> _delete(BuildContext context, WidgetRef ref, ExerciseEntry e) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(exerciseLogRepositoryProvider).delete(e.id!);
      ref.invalidate(exerciseLogProvider(day));
      messenger.showSnackBar(SnackBar(content: Text('Quitaste ${e.name}.')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo quitar. Revisa tu conexión.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(exerciseLogProvider(day)).value ?? const [];
    final burned = entries.fold<double>(0, (a, e) => a + e.kcalNet);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Ejercicio', style: theme.textTheme.titleMedium)),
                if (entries.isNotEmpty)
                  Text('${fmt(burned)} kcal quemadas',
                      style: theme.textTheme.bodySmall),
                const SizedBox(width: 8),
              ],
            ),
            for (final e in entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.name),
                subtitle: Text([
                  if (e.distanceKm != null) '${fmt(e.distanceKm, 2)} km',
                  '${e.minutes} min',
                  '${fmt(e.kcalNet)} kcal',
                ].join(' · ')),
                trailing: e.id == null
                    ? null
                    : IconButton(
                        tooltip: 'Quitar ${e.name}',
                        icon: const Icon(Icons.close),
                        onPressed: () => _delete(context, ref, e),
                      ),
              ),
            if (entries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  'Suma +${fmt(exerciseBonusFor(entries))} kcal a lo que puedes '
                  'comer hoy (tu meta no cambia): la mitad de lo quemado, porque '
                  'los cálculos de gasto suelen quedar altos.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => AddExerciseSheet(day: day, weightKg: weightKg),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Agregar ejercicio'),
            ),
            if (DateUtils.isSameDay(day, ref.watch(clockProvider)()))
              TextButton.icon(
                onPressed: () => openOutdoor(context, day: day, weightKg: weightKg),
                icon: const Icon(Icons.directions_run),
                label: const Text('Correr, caminar o bici con GPS'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Hoja para anotar una actividad y sus minutos.
class AddExerciseSheet extends ConsumerStatefulWidget {
  const AddExerciseSheet({super.key, required this.day, required this.weightKg});

  final DateTime day;
  final double weightKg;

  @override
  ConsumerState<AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<AddExerciseSheet> {
  Activity? _activity;
  final _minutes = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  int? get _mins {
    final v = parseNum(_minutes.text);
    if (v == null || v < 1 || v > 600) return null;
    return v.round();
  }

  Future<void> _save() async {
    final activity = _activity;
    final mins = _mins;
    if (activity == null || mins == null) {
      setState(() => _error = 'Elige la actividad y los minutos (1–600).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(exerciseLogRepositoryProvider).add(ExerciseEntry.fromActivity(
          activity, mins,
          date: widget.day, weightKg: widget.weightKg));
      ref.invalidate(exerciseLogProvider(widget.day));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = _activity;
    final mins = _mins;
    final net = activity != null && mins != null
        ? netBurnKcal(activity, mins.toDouble(), widget.weightKg)
        : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Agregar ejercicio', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<Activity>(
              initialValue: activity,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Actividad'),
              items: [
                for (final a in activities)
                  DropdownMenuItem(value: a, child: Text(a.name)),
              ],
              onChanged: (a) => setState(() {
                _activity = a;
                _error = null;
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Minutos', suffixText: 'min'),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (net != null) ...[
              const SizedBox(height: 8),
              Text(
                '≈ ${fmt(net)} kcal quemadas además del reposo · suma '
                '+${fmt(exerciseBonusKcal(net))} kcal a tu meta',
                style: theme.textTheme.titleSmall,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Cálculo con MET (Compendio de Actividad Física) y tu peso de '
              '${fmt(widget.weightKg, 1)} kg. Es una estimación.',
              style: theme.textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Agregar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Temporizador de ayuno con sus avisos. Solo para quien puede ayunar.
class FastingCard extends ConsumerStatefulWidget {
  const FastingCard({
    super.key,
    required this.blockReason,
    required this.recommendedHours,
  });

  /// Por qué no debe ayunar (`null` si puede).
  final String? blockReason;

  /// Protocolo sugerido: el del plan o 12 h (lo más suave).
  final int recommendedHours;

  @override
  ConsumerState<FastingCard> createState() => _FastingCardState();
}

class _FastingCardState extends ConsumerState<FastingCard> {
  late int _target = widget.recommendedHours;
  DateTime? _start;
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresca el tiempo transcurrido.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(latestFastProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo guardar. Revisa tu conexión.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickStart() async {
    final now = ref.read(clockProvider)();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start ?? now),
      helpText: '¿A qué hora fue tu última comida?',
    );
    if (picked == null || !mounted) return;
    var start = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (start.isAfter(now)) start = start.subtract(const Duration(days: 1));
    setState(() => _start = start);
  }

  String _hhmm(DateTime t) => TimeOfDay.fromDateTime(t).format(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = widget.blockReason;
    if (reason != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.no_food_outlined),
          title: const Text('Ayuno no recomendado'),
          subtitle: Text('MAGRA no te propone ayunar: $reason.'),
        ),
      );
    }
    final now = ref.watch(clockProvider)();
    final fast = ref.watch(latestFastProvider).value;
    final active = fast != null && fast.active ? fast : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ayuno', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (active != null) ..._active(theme, active, now) else ..._idle(theme, fast, now),
          ],
        ),
      ),
    );
  }

  List<Widget> _active(ThemeData theme, Fast fast, DateTime now) {
    final elapsed = fast.elapsed(now);
    final remaining = fast.targetEnd.difference(now);
    final over = fast.overLimit(now);
    final done = fast.reached(now);
    return [
      Text(
        '${fmtDuration(elapsed)} de ${fast.targetHours} h',
        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: fast.progress(now),
          minHeight: 8,
          color: over ? MagraColors.bad : (done ? MagraColors.good : null),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        over
            ? 'Llevas más de $fastingHardLimitHours h sin comer. MAGRA no '
                'recomienda ayunos tan largos: come ahora y termina el ayuno.'
            : done
                ? '¡Cumpliste tu ayuno! Rómpelo con una comida con proteína '
                    'y sin excesos.'
                : 'Empezó a las ${_hhmm(fast.start)} · termina a las '
                    '${_hhmm(fast.targetEnd)} (faltan ${fmtDuration(remaining)}).',
        style: theme.textTheme.bodyMedium?.copyWith(
            color: over ? MagraColors.bad : (done ? MagraColors.good : null)),
      ),
      const SizedBox(height: 8),
      Text(
        'Agua, café o té sin azúcar están permitidos. Si sientes mareo, '
        'debilidad, palpitaciones o malestar, come y termina el ayuno.',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() => ref
                    .read(fastRepositoryProvider)
                    .end(fast.id!, ref.read(clockProvider)())),
            child: const Text('Terminar ayuno'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() => ref.read(fastRepositoryProvider).delete(fast.id!)),
            child: const Text('Lo empecé por error'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _idle(ThemeData theme, Fast? last, DateTime now) {
    final start = _start;
    return [
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [
          for (final h in fastingProtocols)
            ButtonSegment(value: h, label: Text('$h:${24 - h}')),
        ],
        selected: {_target},
        onSelectionChanged: (s) => setState(() => _target = s.first),
      ),
      const SizedBox(height: 4),
      Text(
        _target == widget.recommendedHours
            ? '$_target h sin comer y ${24 - _target} h de ventana: el que te '
                'recomienda MAGRA.'
            : '$_target h sin comer y ${24 - _target} h de ventana. MAGRA te '
                'recomienda ${widget.recommendedHours}:${24 - widget.recommendedHours}.',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Text(start == null
                ? 'Empieza ahora'
                : 'Empezó a las ${_hhmm(start)}'),
          ),
          TextButton(
            onPressed: _busy ? null : _pickStart,
            child: const Text('Cambiar hora'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _busy
            ? null
            : () => _run(() async {
                  await ref
                      .read(fastRepositoryProvider)
                      .start(start ?? ref.read(clockProvider)(), _target);
                  _start = null;
                }),
        icon: const Icon(Icons.timer_outlined),
        label: Text('Empezar ayuno $_target:${24 - _target}'),
      ),
      if (last != null && last.end != null) ...[
        const SizedBox(height: 8),
        Text(
          'Último ayuno: ${fmtDuration(last.elapsed(now))} '
          '(meta ${last.targetHours} h)${last.reached(now) ? ' ✓' : ''}.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    ];
  }
}


/// Pasos del día contra la meta del plan. En el navegador se anotan a mano
/// (el número sale de la app Salud o Google Fit del teléfono); la app
/// instalada los leerá sola.
class StepsCard extends ConsumerWidget {
  const StepsCard({super.key, required this.day, required this.goal});

  final DateTime day;
  final int goal;

  Future<void> _edit(BuildContext context, WidgetRef ref, int? current) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _StepsDialog(current: current),
    );
    if (value == null) return;
    try {
      await ref.read(stepsRepositoryProvider).set(day, value);
      ref.invalidate(stepsProvider(day));
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(saveErrorMessage(err, migration: '0014_gps_steps.sql'))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final steps = ref.watch(stepsProvider(day)).value;
    final progress = steps == null ? 0.0 : (steps / goal).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Pasos', style: theme.textTheme.titleMedium)),
                Text(steps == null ? 'Meta ${fmt(goal)}' : '${fmt(steps)} / ${fmt(goal)}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: MagraColors.outlineSoft,
                color: progress >= 1 ? MagraColors.lime : MagraColors.cyan,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              steps == null
                  ? 'Caminar suma: tu meta de hoy es ${fmt(goal)} pasos.'
                  : steps >= goal
                      ? '¡Cumpliste tu meta de pasos!'
                      : 'Te faltan ${fmt(goal - steps)} pasos.',
              style: theme.textTheme.bodySmall,
            ),
            TextButton.icon(
              onPressed: () => _edit(context, ref, steps),
              icon: const Icon(Icons.edit_outlined),
              label: Text(steps == null ? 'Anotar pasos' : 'Corregir pasos'),
            ),
            Text(
              'Los pasos ya están considerados en tu nivel de actividad: no suman '
              'calorías extra a tu meta. En la app instalada se contarán solos.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}


class _StepsDialog extends StatefulWidget {
  const _StepsDialog({this.current});

  final int? current;

  @override
  State<_StepsDialog> createState() => _StepsDialogState();
}

class _StepsDialogState extends State<_StepsDialog> {
  late final _ctrl = TextEditingController(text: widget.current?.toString() ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Pasos del día'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pasos', suffixText: 'pasos'),
            ),
            const SizedBox(height: 8),
            const Text('Míralos en la app Salud (iPhone) o Google Fit (Android) y anótalos aquí.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(_ctrl.text.replaceAll(RegExp('[^0-9]'), ''));
              if (v != null && v >= 0 && v <= 150000) Navigator.pop(context, v);
            },
            child: const Text('Guardar'),
          ),
        ],
      );
}
