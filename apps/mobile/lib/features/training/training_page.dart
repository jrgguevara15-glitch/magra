import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/recommendation/training_plan.dart';
import '../plan/plan_inputs.dart';

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
        'Cuando completes todas las series en el tope de repeticiones, sube '
            'el peso 2,5–5 %.',
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
