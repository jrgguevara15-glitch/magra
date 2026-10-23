import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/db_errors.dart';
import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/recommendation/exercise_alternatives.dart';
import '../../core/recommendation/exercise_guides.dart' show guideFor;
import '../../core/recommendation/progression.dart';
import '../../core/recommendation/training_plan.dart';
import '../../core/widgets/sections.dart';
import '../plan/plan_inputs.dart';
import '../questionnaire/questionnaire.dart';
import '../../core/recommendation/warmup.dart';
import 'exercise_guide_page.dart';
import 'guided_routine_page.dart';
import 'workout_session_page.dart';

/// Pestaña Entreno: la rutina que MAGRA recomienda al usuario.
class TrainingPage extends ConsumerWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swaps = ref.watch(exerciseSwapsProvider).value ?? const {};
    return PlanGate(
      what: 'tu plan de entrenamiento',
      builder: (context, inputs) {
        final plan = applySwaps(
          recommendTraining(
            questionnaire: inputs.questionnaire,
            composition: inputs.composition,
            age: inputs.age,
          ),
          swaps,
        );
        return TrainingPlanView(plan: plan, inputs: inputs);
      },
    );
  }
}

enum _Tab { today, week, history }

class TrainingPlanView extends ConsumerStatefulWidget {
  const TrainingPlanView({super.key, required this.plan, required this.inputs});

  final TrainingPlan plan;
  final PlanInputs inputs;

  @override
  ConsumerState<TrainingPlanView> createState() => _TrainingPlanViewState();
}

class _TrainingPlanViewState extends ConsumerState<TrainingPlanView> {
  _Tab _tab = _Tab.today;

  TrainingPlan get plan => widget.plan;
  PlanInputs get inputs => widget.inputs;

  Future<void> _start(TrainingDay day, List<WorkoutSession> history) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => WorkoutSessionPage(
        day: day,
        history: history,
        weightKg: inputs.weightKg,
        today: DateUtils.dateOnly(inputs.today),
        intense: inputs.questionnaire.experience == Experience.advanced,
      ),
    ));
    if (saved == true && mounted) {
      final cool = coolDown(focus: focusOf(day), questionnaire: inputs.questionnaire);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Sesión guardada. Sus calorías ya están en Hoy.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Estirar',
          onPressed: () => openGuidedRoutine(context, 'Estiramiento', cool),
        ),
      ));
    }
  }

  Future<void> _delete(WorkoutSession s) async {
    try {
      await ref.read(workoutRepositoryProvider).delete(s.id!);
      ref.invalidate(workoutsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo borrar.')));
      }
    }
  }

  Widget _exercise(Exercise e) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          leading: ExerciseThumb(exercise: e.name),
          title: Text(e.name),
          subtitle: Text(e.prescription),
          trailing: IconButton(
            tooltip: 'Cambiar ${e.name}',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => showExerciseSwap(context, e, inputs.questionnaire),
          ),
          onTap: () => openExerciseGuide(context, e.name, prescription: e.prescription),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = plan.days.first;
    final async = ref.watch(workoutsProvider);
    final history = async.value ?? const <WorkoutSession>[];
    final next = nextSession(plan, history);
    final today = DateUtils.dateOnly(inputs.today);
    final doneToday = history.any((s) => s.date == today);
    final warm = warmUp(focus: focusOf(next), questionnaire: inputs.questionnaire, lowImpact: plan.lowImpact);
    final cool = coolDown(focus: focusOf(next), questionnaire: inputs.questionnaire);

    final body = switch (_tab) {
      _Tab.today => [
          Text(doneToday ? 'Próxima sesión' : 'Hoy te toca', style: theme.textTheme.labelLarge),
          Text(next.title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(
            '${next.exercises.length} ejercicios · ${next.strengthMinutes + next.cardioMinutes} min · '
            'calentar ${routineMinutes(warm)} min',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final e in next.exercises) _exercise(e),
          if (next.cardioMinutes > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Cardio ${next.cardioMinutes} min: ${plan.cardio.toLowerCase()}, en zona 2 '
                '(${plan.zone2.$1}–${plan.zone2.$2} ppm, puedes hablar en frases cortas).',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => openGuidedRoutine(context, 'Calentamiento', warm),
            icon: const Icon(Icons.local_fire_department_outlined),
            label: Text('Calentar · ${routineMinutes(warm)} min'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: async.isLoading ? null : () => _start(next, history),
            icon: const Icon(Icons.play_arrow),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Empezar entreno'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => openGuidedRoutine(context, 'Estiramiento', cool),
            icon: const Icon(Icons.self_improvement),
            label: Text('Estirar al terminar · ${routineMinutes(cool)} min'),
          ),
        ],
      _Tab.week => [
          for (final d in plan.days)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${weekdayName(d.weekday)} · ${d.title}', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _RoutineButtons(plan: plan, day: d, questionnaire: inputs.questionnaire),
                    const SizedBox(height: 4),
                    for (final e in d.exercises)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ExerciseThumb(exercise: e.name),
                        title: Text(e.name),
                        subtitle: Text(e.prescription),
                        trailing: IconButton(
                          tooltip: 'Cambiar ${e.name}',
                          icon: const Icon(Icons.swap_horiz),
                          onPressed: () => showExerciseSwap(context, e, inputs.questionnaire),
                        ),
                        onTap: () => openExerciseGuide(context, e.name, prescription: e.prescription),
                      ),
                    if (d.cardioMinutes > 0)
                      Text(
                        'Cardio ${d.cardioMinutes} min: ${plan.cardio.toLowerCase()}, '
                        'en zona 2 (${plan.zone2.$1}–${plan.zone2.$2} ppm, puedes '
                        'hablar en frases cortas).',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
        ],
      _Tab.history => [
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Aún no registras sesiones. Tu primer entreno queda aquí.',
                  style: theme.textTheme.bodyMedium),
            ),
          for (final s in history.reversed)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${fmtDate(s.date)} · ${s.title}'),
                subtitle: Text(
                  '${s.exercises.fold<int>(0, (a, e) => a + e.sets.length)} series'
                  '${s.volume > 0 ? ' · ${fmt(s.volume)} kg movidos' : ''}'
                  ' · ${s.minutes} min',
                ),
                trailing: s.id == null
                    ? null
                    : IconButton(
                        tooltip: 'Borrar sesión del ${fmtDate(s.date)}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(s),
                      ),
              ),
            ),
        ],
    };

    return PlanScroll(children: [
      Text('Tu plan de entrenamiento', style: theme.textTheme.headlineSmall),
      const SizedBox(height: 12),
      HealthAlertList(alerts: [for (final a in inputs.alerts) if (a.blocking) a]),
      Wrap(
        spacing: 8,
        children: [
          for (final (t, label) in [(_Tab.today, 'Hoy'), (_Tab.week, 'Semana'), (_Tab.history, 'Historial')])
            ChoiceChip(
              showCheckmark: false,
              label: Text(label),
              selected: _tab == t,
              onSelected: (_) => setState(() => _tab = t),
            ),
        ],
      ),
      const SizedBox(height: 14),
      ...body,
      const SizedBox(height: 18),
      SectionList(sections: [
        PageSection(
          title: 'Resumen',
          icon: Icons.insights_outlined,
          summary: '${plan.days.length} días · zona 2: ${plan.zone2.$1}–${plan.zone2.$2} ppm',
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _Figure('${plan.days.length} días', 'por semana'),
                  _Figure('${first.strengthMinutes}${first.cardioMinutes > 0 ? ' + ${first.cardioMinutes}' : ''} min',
                      first.cardioMinutes > 0 ? 'fuerza + cardio' : 'fuerza'),
                  _Figure('${plan.zone2.$1}–${plan.zone2.$2}', 'ppm en cardio (zona 2)'),
                  _Figure(fmt(plan.stepsStart), 'pasos diarios para empezar'),
                ],
              ),
            ),
          ),
        ),
        PageSection(
          title: 'Por qué',
          icon: Icons.lightbulb_outline,
          summary: plan.reasons.isEmpty ? null : plan.reasons.first,
          child: ReasonList(title: 'Por qué esta rutina', reasons: plan.reasons),
        ),
        if (plan.cautions.isNotEmpty)
          PageSection(
            title: 'Cuidados',
            icon: Icons.health_and_safety_outlined,
            summary: '${plan.cautions.length} ${plan.cautions.length == 1 ? 'aviso' : 'avisos'}',
            child: ReasonList(title: 'Cuidados', reasons: plan.cautions),
          ),
        const PageSection(
          title: 'Cómo progresar',
          icon: Icons.trending_up,
          summary: 'Carga, pasos y descarga',
          child: ReasonList(title: 'Cómo progresar', reasons: [
            'Anota cada sesión: cuando completes todas las series en el tope de '
                'repeticiones, MAGRA te sube el peso (2,5 kg piernas, 1 kg el '
                'resto); si fallas 3 veces seguidas, baja 10 %.',
            'Cada 2 semanas suma 1.000 pasos diarios hasta llegar a 10.000.',
            'Cada 6.ª semana baja el volumen a la mitad para recuperarte.',
            'Técnica antes que peso. Si algo duele (no cansancio), detente.',
          ]),
        ),
      ]),
    ]);
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Botones de calentamiento y estiramiento de una sesión.
class _RoutineButtons extends StatelessWidget {
  const _RoutineButtons({required this.plan, required this.day, required this.questionnaire});

  final TrainingPlan plan;
  final TrainingDay day;
  final Questionnaire questionnaire;

  @override
  Widget build(BuildContext context) {
    final warm = warmUp(
        focus: focusOf(day), questionnaire: questionnaire, lowImpact: plan.lowImpact);
    final cool = coolDown(focus: focusOf(day), questionnaire: questionnaire);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => openGuidedRoutine(context, 'Calentamiento', warm),
          icon: const Icon(Icons.local_fire_department_outlined),
          label: Text('Calentar · ${routineMinutes(warm)} min'),
        ),
        OutlinedButton.icon(
          onPressed: () => openGuidedRoutine(context, 'Estiramiento', cool),
          icon: const Icon(Icons.self_improvement),
          label: Text('Estirar · ${routineMinutes(cool)} min'),
        ),
      ],
    );
  }
}


/// Hoja para cambiar un ejercicio de la rutina por otro parecido.
Future<void> showExerciseSwap(BuildContext context, Exercise e, Questionnaire q) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SwapSheet(exercise: e, questionnaire: q),
    );

class _SwapSheet extends ConsumerStatefulWidget {
  const _SwapSheet({required this.exercise, required this.questionnaire});

  final Exercise exercise;
  final Questionnaire questionnaire;

  @override
  ConsumerState<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends ConsumerState<_SwapSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _choose(String? chosen) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final e = widget.exercise;
    try {
      final repo = ref.read(exerciseSwapRepositoryProvider);
      if (chosen == null || chosen == e.slot) {
        await repo.clear(e.slot);
      } else {
        await repo.set(e.slot, chosen);
      }
      ref.invalidate(exerciseSwapsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) setState(() => _error = saveErrorMessage(err, migration: '0013_exercise_swaps.sql'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.exercise;
    final options = alternativesFor(e, widget.questionnaire)
        .where((o) => o.name != e.slot)
        .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cambiar ${e.name}', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Opciones que trabajan los mismos músculos, con tu equipo y '
                'cuidando tus lesiones. Se mantienen las series y repeticiones; '
                'el progreso del nuevo ejercicio parte de cero.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (e.original != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ExerciseThumb(exercise: e.original!),
                  title: Text('Volver a ${e.original}'),
                  subtitle: const Text('El de tu rutina original'),
                  trailing: const Icon(Icons.undo),
                  onTap: _busy ? null : () => _choose(null),
                ),
              for (final o in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ExerciseThumb(exercise: o.name),
                  title: Text(o.name),
                  subtitle: Text(guideFor(o.name).isEmpty
                      ? ''
                      : '${guideFor(o.name).first.muscles.take(3).join(', ')} · ${guideFor(o.name).first.equipment}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _choose(o.name),
                ),
              if (options.isEmpty && e.original == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No hay otra opción parecida con tu equipo y tus cuidados.'),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
