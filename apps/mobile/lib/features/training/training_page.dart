import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/recommendation/progression.dart';
import '../../core/recommendation/training_plan.dart';
import '../plan/plan_inputs.dart';
import '../questionnaire/questionnaire.dart';
import 'workout_session_page.dart';

/// Pestaña Entreno: la rutina que MAGRA recomienda al usuario.
class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlanGate(
      what: 'tu plan de entrenamiento',
      builder: (context, inputs) {
        final plan = recommendTraining(
          questionnaire: inputs.questionnaire,
          composition: inputs.composition,
          age: inputs.age,
        );
        return TrainingPlanView(plan: plan, inputs: inputs);
      },
    );
  }
}

class TrainingPlanView extends StatelessWidget {
  const TrainingPlanView({super.key, required this.plan, required this.inputs});

  final TrainingPlan plan;
  final PlanInputs inputs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = plan.days.first;
    return PlanScroll(children: [
      Text('Tu plan de entrenamiento', style: theme.textTheme.headlineSmall),
      const SizedBox(height: 12),
      HealthAlertList(
          alerts: [for (final a in inputs.alerts) if (a.blocking) a]),
      WorkoutCard(plan: plan, inputs: inputs),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _Figure('${plan.days.length} días', 'por semana'),
              _Figure(
                  '${first.strengthMinutes}${first.cardioMinutes > 0 ? ' + ${first.cardioMinutes}' : ''} min',
                  first.cardioMinutes > 0 ? 'fuerza + cardio' : 'fuerza'),
              _Figure('${plan.zone2.$1}–${plan.zone2.$2}', 'ppm en cardio (zona 2)'),
              _Figure(fmt(plan.stepsStart), 'pasos diarios para empezar'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      ReasonList(title: 'Por qué esta rutina', reasons: plan.reasons),
      if (plan.cautions.isNotEmpty) ...[
        const SizedBox(height: 8),
        ReasonList(title: 'Cuidados', reasons: plan.cautions),
      ],
      const SizedBox(height: 8),
      for (final d in plan.days)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${weekdayName(d.weekday)} · ${d.title}',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final e in d.exercises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name),
                        Text(e.prescription, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                if (d.cardioMinutes > 0)
                  Text(
                    'Cardio ${d.cardioMinutes} min: ${plan.cardio.toLowerCase()}, '
                    'en zona 2 (${plan.zone2.$1}–${plan.zone2.$2} ppm, puedes '
                    'hablar en frases cortas).',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      const ReasonList(title: 'Cómo progresar', reasons: [
        'Anota cada sesión: cuando completes todas las series en el tope de '
            'repeticiones, MAGRA te sube el peso (2,5 kg piernas, 1 kg el '
            'resto); si fallas 3 veces seguidas, baja 10 %.',
        'Cada 2 semanas suma 1.000 pasos diarios hasta llegar a 10.000.',
        'Cada 6.ª semana baja el volumen a la mitad para recuperarte.',
        'Técnica antes que peso. Si algo duele (no cansancio), detente.',
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
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Próxima sesión según la rotación y el historial de fuerza.
class WorkoutCard extends ConsumerWidget {
  const WorkoutCard({super.key, required this.plan, required this.inputs});

  final TrainingPlan plan;
  final PlanInputs inputs;

  Future<void> _start(BuildContext context, TrainingDay day,
      List<WorkoutSession> history) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => WorkoutSessionPage(
        day: day,
        history: history,
        weightKg: inputs.weightKg,
        today: DateUtils.dateOnly(inputs.today),
        intense: inputs.questionnaire.experience == Experience.advanced,
      ),
    ));
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sesión guardada. Sus calorías ya están en Hoy.')));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, WorkoutSession s) async {
    try {
      await ref.read(workoutRepositoryProvider).delete(s.id!);
      ref.invalidate(workoutsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo borrar.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(workoutsProvider);
    final history = async.value ?? const <WorkoutSession>[];
    final next = nextSession(plan, history);
    final today = DateUtils.dateOnly(inputs.today);
    final doneToday = history.any((s) => s.date == today);
    final recent = history.reversed.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(doneToday ? 'Próxima sesión' : 'Hoy te toca',
                style: theme.textTheme.labelLarge),
            Text(next.title, style: theme.textTheme.titleLarge),
            Text(
              [for (final e in next.exercises) e.name].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: async.isLoading ? null : () => _start(context, next, history),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Empezar sesión'),
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Últimas sesiones', style: theme.textTheme.titleSmall),
              for (final s in recent)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
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
                          onPressed: () => _delete(context, ref, s),
                        ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
