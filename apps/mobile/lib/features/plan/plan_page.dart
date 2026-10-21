import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/recommendation/nutrition_plan.dart';
import '../../core/recommendation/seasoning.dart';
import '../../core/recommendation/reference_foods.dart';
import '../../core/theme.dart';
import 'plan_inputs.dart';

/// Pestaña Plan: el plan nutricional que MAGRA recomienda al usuario.
class PlanPage extends StatelessWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlanGate(
      what: 'tu plan nutricional',
      builder: (context, inputs) {
        final plan = inputs.nutrition;
        return NutritionPlanView(plan: plan, inputs: inputs);
      },
    );
  }
}

class NutritionPlanView extends StatelessWidget {
  const NutritionPlanView({super.key, required this.plan, required this.inputs});

  final NutritionPlan plan;
  final PlanInputs inputs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PlanScroll(children: [
      Text('Tu plan nutricional', style: theme.textTheme.headlineSmall),
      const SizedBox(height: 12),
      HealthAlertList(alerts: inputs.alerts),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _Figure('${fmt(plan.kcal)} kcal',
                  plan.maintenanceOnly ? 'mantención' : 'por día'),
              _Figure('${plan.meals.length} comidas',
                  plan.fastingHours == null
                      ? 'al día'
                      : 'en 8 h · ayuno ${plan.fastingHours} h'),
              _Figure('${fmt(plan.protein)} g', 'proteína',
                  color: MagraColors.protein),
              _Figure('${fmt(plan.carbs)} g', 'carbohidratos',
                  color: MagraColors.carb),
              _Figure('${fmt(plan.fat)} g', 'grasas', color: MagraColors.lipid),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      ReasonList(title: 'Por qué este plan', reasons: plan.reasons),
      const SizedBox(height: 8),
      ReasonList(
          title: 'Grasas saludables recomendadas',
          reasons: healthyFatTips(inputs.questionnaire)),
      const SizedBox(height: 8),
      ReasonList(
          title: 'Condimentos y sazón',
          reasons: seasoningTipsFor(inputs.questionnaire)),
      const SizedBox(height: 8),
      for (var i = 0; i < plan.meals.length; i++) _MealCard(index: i, meal: plan.meals[i]),
      const SizedBox(height: 8),
      Text(
        'Cada grupo muestra opciones equivalentes: elige una de proteína, una '
        'de carbohidratos y una de grasa, y agrega vegetales a gusto. Pesa '
        'avena, pasta y harinas en crudo; lo demás, cocido. MAGRA orienta y '
        'no reemplaza a un nutricionista o médico.',
        style: theme.textTheme.bodySmall,
      ),
    ]);
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label, {this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700, color: color)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.index, required this.meal});

  final int index;
  final PlannedMeal meal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = switch (meal.role) {
      MealRole.preWorkout => 'Antes de entrenar',
      MealRole.postWorkout => 'Después de entrenar',
      MealRole.regular => null,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${meal.time.format(context)} · Comida ${index + 1}',
                    style: theme.textTheme.titleMedium),
                if (role != null)
                  Chip(
                    label: Text(role),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            Text(
              '${fmt(meal.kcal)} kcal · P ${fmt(meal.protein)} g · '
              'C ${fmt(meal.carbs)} g · G ${fmt(meal.fat)} g',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _Group('Proteína', MagraColors.protein,
                meal.examples[MacroGroup.protein] ?? const []),
            _Group('Carbohidratos', MagraColors.carb,
                meal.examples[MacroGroup.carb] ?? const []),
            _Group('Grasa', MagraColors.lipid,
                meal.examples[MacroGroup.fat] ?? const []),
            const _Group('Vegetales', MagraColors.vegetable,
                ['a gusto: ensalada o verduras cocidas']),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.label, this.color, this.options);

  final String label;
  final Color color;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 18,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: options.join(' · o · ')),
            ])),
          ),
        ],
      ),
    );
  }
}
