import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/recommendation/nutrition_plan.dart';
import '../../core/recommendation/seasoning.dart';
import '../../core/widgets/sections.dart';
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
    final names = mealNames(plan.meals);
    final pKcal = plan.protein * 4, cKcal = plan.carbs * 4, fKcal = plan.fat * 9;
    final total = pKcal + cKcal + fKcal;
    int pct(double v) => total <= 0 ? 0 : (v / total * 100).round();
    return PlanScroll(children: [
      Text('Tu plan nutricional', style: theme.textTheme.headlineSmall),
      const SizedBox(height: 12),
      HealthAlertList(alerts: inputs.alerts),
      Text('${fmt(plan.kcal)} kcal',
          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
      Text(
        [
          plan.maintenanceOnly ? 'mantención' : 'por día',
          '${plan.meals.length} comidas${plan.fastingHours == null ? '' : ' en 8 h · ayuno ${plan.fastingHours} h'}',
          'proteína ${fmt(plan.protein)} g · carbos ${fmt(plan.carbs)} g · grasas ${fmt(plan.fat)} g',
        ].join(' · '),
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 10,
          child: Row(children: [
            Expanded(flex: pct(pKcal).clamp(1, 100), child: Container(color: MagraColors.protein)),
            Expanded(flex: pct(cKcal).clamp(1, 100), child: Container(color: MagraColors.carb)),
            Expanded(flex: pct(fKcal).clamp(1, 100), child: Container(color: MagraColors.lipid)),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Text('${pct(pKcal)} % proteína · ${pct(cKcal)} % carbohidratos · ${pct(fKcal)} % grasas',
          style: theme.textTheme.bodySmall),
      const SizedBox(height: 18),
      Text('CÓMO SE REPARTE EN TUS ${plan.meals.length} COMIDAS',
          style: theme.textTheme.labelMedium?.copyWith(color: MagraColors.textSoft, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              const _MealHeader(),
              for (var i = 0; i < plan.meals.length; i++)
                _MealRow(name: names[i], meal: plan.meals[i], last: i == plan.meals.length - 1),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text('Toca una comida para ver ejemplos en gramos.', style: theme.textTheme.bodySmall),
      const SizedBox(height: 14),
      Text('Por qué se reparte así', style: theme.textTheme.titleMedium),
      for (final r in distributionReasons(plan))
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6, right: 8),
                child: Icon(Icons.circle, size: 6, color: MagraColors.lime),
              ),
              Expanded(child: Text(r, style: theme.textTheme.bodyMedium)),
            ],
          ),
        ),
      const SizedBox(height: 18),
      SectionList(sections: [
        PageSection(
          title: 'Por qué',
          icon: Icons.lightbulb_outline,
          summary: plan.reasons.isEmpty ? null : plan.reasons.first,
          child: ReasonList(title: 'Por qué este plan', reasons: plan.reasons),
        ),
        PageSection(
          title: 'Grasas saludables',
          icon: Icons.water_drop_outlined,
          summary: 'Oliva, palta, semillas: cuánto y cómo',
          child: ReasonList(
              title: 'Grasas saludables recomendadas',
              reasons: healthyFatTips(inputs.questionnaire)),
        ),
        PageSection(
          title: 'Condimentos',
          icon: Icons.eco_outlined,
          summary: 'Sabor sin calorías ni exceso de sal',
          child: ReasonList(
              title: 'Condimentos y sazón',
              reasons: seasoningTipsFor(inputs.questionnaire)),
        ),
      ]),
    ]);
  }
}

class _MealHeader extends StatelessWidget {
  const _MealHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: MagraColors.textSoft);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text('COMIDA', style: style)),
        SizedBox(width: 52, child: Text('KCAL', style: style, textAlign: TextAlign.right)),
        for (final l in const ['P', 'C', 'G']) SizedBox(width: 38, child: Text(l, style: style, textAlign: TextAlign.right)),
        const SizedBox(width: 24),
      ]),
    );
  }
}

/// Una fila del reparto: hora, nombre, kcal y macros; al tocarla muestra
/// ejemplos de alimentos en gramos.
class _MealRow extends StatefulWidget {
  const _MealRow({required this.name, required this.meal, required this.last});

  final String name;
  final PlannedMeal meal;
  final bool last;

  @override
  State<_MealRow> createState() => _MealRowState();
}

class _MealRowState extends State<_MealRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meal = widget.meal;
    final role = switch (meal.role) {
      MealRole.preWorkout => 'Antes de entrenar',
      MealRole.postWorkout => 'Después de entrenar',
      MealRole.regular => null,
    };
    Widget n(double v) => SizedBox(width: 38, child: Text(fmt(v), textAlign: TextAlign.right));
    return Container(
      decoration: BoxDecoration(
        border: widget.last ? null : const Border(bottom: BorderSide(color: MagraColors.outlineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${meal.time.format(context)} · ${widget.name}', style: theme.textTheme.titleSmall),
                        if (role != null)
                          Text(role, style: theme.textTheme.bodySmall?.copyWith(color: MagraColors.lime)),
                      ],
                    ),
                  ),
                  SizedBox(width: 52, child: Text(fmt(meal.kcal), textAlign: TextAlign.right)),
                  n(meal.protein),
                  n(meal.carbs),
                  n(meal.fat),
                  SizedBox(
                    width: 24,
                    child: Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18, color: MagraColors.textSoft),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Group('Proteína', MagraColors.protein, meal.examples[MacroGroup.protein] ?? const []),
                  _Group('Carbohidratos', MagraColors.carb, meal.examples[MacroGroup.carb] ?? const []),
                  _Group('Grasa', MagraColors.lipid, meal.examples[MacroGroup.fat] ?? const []),
                  const _Group('Vegetales', MagraColors.vegetable, ['a gusto: ensalada o verduras cocidas']),
                  const SizedBox(height: 6),
                  Text(
                    'Elige una opción de cada grupo. Pesa avena, pasta y harinas en crudo; lo '
                    'demás, cocido. MAGRA orienta y no reemplaza a un nutricionista o médico.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
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
