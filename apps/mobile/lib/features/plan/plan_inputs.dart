import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/formulas/formulas.dart';
import '../../core/recommendation/assessment.dart';
import '../../core/recommendation/nutrition_plan.dart';
import '../../core/recommendation/weekly_basis.dart';
import '../../core/recommendation/weekly_adjustment.dart';
import '../profile/user_profile.dart';
import '../progress/body_assessment.dart';
import '../progress/measurement.dart';
import '../questionnaire/questionnaire.dart';

/// Pestaña activa del menú principal (la cambian otras pantallas).
class HomeTab extends Notifier<int> {
  @override
  int build() => 0;

  void go(int index) => state = index;
}

final homeTabProvider = NotifierProvider<HomeTab, int>(HomeTab.new);

/// Índice de la pestaña Progreso.
const int kProgressTab = 3;

/// Índice de la pestaña Entreno.
const int kTrainingTab = 4;

/// Lo que el motor de recomendación necesita de un usuario.
class PlanInputs {
  const PlanInputs({
    required this.profile,
    required this.weightKg,
    required this.composition,
    required this.questionnaire,
    required this.age,
    required this.today,
    required this.measurements,
    this.assessments = const [],
    this.kcalAdjustment = 0,
  });

  /// Evaluaciones con foto (su % de grasa entra al plan).
  final List<BodyAssessment> assessments;

  /// Todas las mediciones, de la más antigua a la más reciente.
  final List<Measurement> measurements;

  final UserProfile profile;

  /// Último peso registrado.
  final double weightKg;

  /// De la última medición con perímetros (o solo el peso si no hay).
  final BodyComposition composition;
  final Questionnaire questionnaire;
  final int age;
  final DateTime today;

  /// Suma de los ajustes semanales aplicados.
  final int kcalAdjustment;

  /// Meta de la semana (la misma en toda la app).
  NutritionPlan get nutrition => weeklyNutrition(
        profile: profile,
        measurements: measurements,
        questionnaire: questionnaire,
        today: today,
        kcalAdjustment: kcalAdjustment,
        assessments: assessments,
      );

  List<HealthAlert> get alerts => healthAlerts(
      composition: composition, questionnaire: questionnaire, age: age);
}

/// Muestra [builder] cuando el usuario tiene perfil, una medición y el
/// cuestionario; si no, le dice qué le falta y lo lleva a Progreso.
class PlanGate extends ConsumerWidget {
  const PlanGate({super.key, required this.what, required this.builder});

  /// "tu plan nutricional", "tu plan de entrenamiento".
  final String what;
  final Widget Function(BuildContext context, PlanInputs inputs) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final measurements = ref.watch(measurementsProvider);
    final questionnaire = ref.watch(questionnaireProvider);
    final adjustments = ref.watch(kcalAdjustmentsProvider);
    if (profile.isLoading ||
        measurements.isLoading ||
        questionnaire.isLoading ||
        adjustments.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (profile.hasError ||
        measurements.hasError ||
        questionnaire.hasError ||
        adjustments.hasError) {
      return Center(
        child: OutlinedButton(
          onPressed: () {
            ref.invalidate(profileProvider);
            ref.invalidate(measurementsProvider);
            ref.invalidate(questionnaireProvider);
            ref.invalidate(kcalAdjustmentsProvider);
          },
          child: const Text('No se pudo cargar. Reintentar'),
        ),
      );
    }
    final p = profile.value;
    final list = measurements.value ?? const [];
    final q = questionnaire.value;
    final missing = [
      if (p == null) 'Completa tu perfil',
      if (list.isEmpty) 'Registra tu primera medición (peso, cuello y cintura)',
      if (q == null) 'Responde el cuestionario',
    ];
    if (missing.isNotEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Para armar $what me falta:',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final m in missing)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.radio_button_unchecked),
                    title: Text(m),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(homeTabProvider.notifier).go(kProgressTab),
                  child: const Text('Ir a Progreso'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final today = DateTime.now();
    final last = list.last;
    final full = list.lastWhere(
      (m) => m.compositionFor(p!).fatPct != null,
      orElse: () => last,
    );
    return builder(
      context,
      PlanInputs(
        profile: p!,
        weightKg: last.weightKg,
        composition: full.compositionFor(p),
        questionnaire: q!,
        age: p.ageOn(today),
        today: today,
        measurements: list,
        assessments: ref.watch(bodyAssessmentsProvider).value ?? const [],
        kcalAdjustment: totalAdjustment(adjustments.value ?? const []),
      ),
    );
  }
}

/// Avisos de salud como tarjetas.
class HealthAlertList extends StatelessWidget {
  const HealthAlertList({super.key, required this.alerts});

  final List<HealthAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final a in alerts)
          Card(
            color: a.blocking ? scheme.errorContainer : scheme.tertiaryContainer,
            child: ListTile(
              leading: Icon(Icons.health_and_safety_outlined,
                  color: a.blocking
                      ? scheme.onErrorContainer
                      : scheme.onTertiaryContainer),
              title: Text(a.title),
              subtitle: Text(a.detail),
            ),
          ),
      ],
    );
  }
}

/// Lista de "por qué" con viñetas.
class ReasonList extends StatelessWidget {
  const ReasonList({super.key, required this.title, required this.reasons});

  final String title;
  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final r in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(r)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Contenedor de página con ancho máximo y desplazamiento.
class PlanScroll extends StatelessWidget {
  const PlanScroll({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          ),
        ),
      ),
    );
  }
}
