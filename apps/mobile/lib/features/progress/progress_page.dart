import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import '../../core/recommendation/assessment.dart';
import '../../core/recommendation/nutrition_plan.dart';
import '../../core/recommendation/weekly_adjustment.dart';
import '../../core/recommendation/weekly_basis.dart';
import '../../core/theme.dart';
import '../../core/widgets/sections.dart';
import '../profile/profile_form.dart';
import '../profile/user_profile.dart';
import '../questionnaire/questionnaire_page.dart';
import 'achievements_card.dart';
import 'body_assessment_page.dart';
import 'measurement.dart';
import 'measurement_form.dart';
import 'progress_photos_card.dart';
import 'weekly_check.dart';

/// Pestaña Progreso: perfil, evaluación actual e historial de mediciones.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _Retry(
        message: 'No se pudo cargar tu perfil.',
        onRetry: () => ref.invalidate(profileProvider),
      ),
      data: (p) => p == null ? const _Onboarding() : _Progress(profile: p),
    );
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding();

  @override
  Widget build(BuildContext context) {
    return _Page(children: [
      Text('Completa tu perfil',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      const Text('Con estos datos MAGRA calcula tu composición corporal, '
          'tus calorías y tus porciones con el método de un nutricionista '
          'deportivo.'),
      const SizedBox(height: 16),
      const ProfileForm(),
    ]);
  }
}

class _Progress extends ConsumerStatefulWidget {
  const _Progress({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_Progress> createState() => _ProgressState();
}

class _ProgressState extends ConsumerState<_Progress> {
  String _tab = 'Resumen';

  UserProfile get profile => widget.profile;

  @override
  Widget build(BuildContext context) {
    final measurements = ref.watch(measurementsProvider);
    final noQuestionnaire = ref.watch(questionnaireProvider).value == null;
    final theme = Theme.of(context);
    return measurements.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _Retry(
        message: 'No se pudieron cargar tus mediciones.',
        onRetry: () => ref.invalidate(measurementsProvider),
      ),
      data: (list) {
        final newButton = FilledButton.icon(
          onPressed: () => showMeasurementForm(context, sex: profile.sex),
          icon: const Icon(Icons.add),
          label: const Text('Nueva medición'),
        );
        final List<Widget> body;
        if (list.isEmpty) {
          body = [
            const QuestionnaireCard(),
            const SizedBox(height: 12),
            newButton,
            const SizedBox(height: 16),
            const Text('Aún no tienes mediciones. Registra tu peso, cuello y '
                'cintura para ver tu evaluación.'),
          ];
        } else {
          body = switch (_tab) {
            'Medidas' => [
                newButton,
                const SizedBox(height: 12),
                SectionList(sections: [
                  PageSection(
                    title: 'Historial',
                    icon: Icons.history,
                    initiallyOpen: true,
                    summary: '${list.length} ${list.length == 1 ? 'medición' : 'mediciones'}',
                    child: _History(profile: profile, measurements: list),
                  ),
                ]),
              ],
            'Fotos' => [
                SectionList(sections: [
                  PageSection(
                    title: 'Evaluación con foto',
                    icon: Icons.add_a_photo_outlined,
                    initiallyOpen: true,
                    summary: _photoSummary(ref),
                    child: BodyAssessmentCard(profile: profile, last: list.last),
                  ),
                  PageSection(
                    title: 'Fotos',
                    icon: Icons.photo_camera_outlined,
                    summary: 'Frente, perfil y espalda cada mes',
                    child: ProgressPhotosCard(profile: profile, measurements: list),
                  ),
                ]),
              ],
            'Logros' => [
                SectionList(sections: [
                  PageSection(
                    title: 'Logros',
                    icon: Icons.emoji_events_outlined,
                    initiallyOpen: true,
                    summary: 'Medallas por hitos reales',
                    child: AchievementsCard(profile: profile, measurements: list),
                  ),
                ]),
              ],
            _ => [
                _WeightHero(measurements: list),
                const SizedBox(height: 12),
                newButton,
                const SizedBox(height: 16),
                SectionList(sections: [
                  PageSection(
                    title: 'Evaluación',
                    icon: Icons.monitor_heart_outlined,
                    initiallyOpen: true,
                    summary: _evaluationSummary(profile, list),
                    child: EvaluationCard(
                      profile: profile,
                      measurements: list,
                      plan: _weekPlan(ref, list),
                    ),
                  ),
                  PageSection(
                    title: 'Tendencia y ajuste',
                    icon: Icons.show_chart,
                    summary: 'Peso de tendencia, gasto real y ajuste de la semana',
                    child: WeeklyCheckCard(profile: profile, measurements: list),
                  ),
                ]),
                if (!noQuestionnaire) ...[
                  const SizedBox(height: 12),
                  const QuestionnaireCard(),
                ],
              ],
          };
        }
        return _Page(children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name.isEmpty ? 'Tu progreso' : 'Hola, ${profile.name}',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Editar perfil',
                icon: const Icon(Icons.tune),
                onPressed: () => _editProfile(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (list.isNotEmpty && noQuestionnaire) ...[
            const QuestionnaireCard(),
            const SizedBox(height: 12),
          ],
          if (list.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in const ['Resumen', 'Medidas', 'Fotos', 'Logros'])
                  ChoiceChip(
                    key: ValueKey('tab-$t'),
                    showCheckmark: false,
                    label: Text(t),
                    selected: _tab == t,
                    onSelected: (_) => setState(() => _tab = t),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          ...body,
        ]);
      },
    );
  }

  void _editProfile(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 20),
        child: SingleChildScrollView(
          child: ProfileForm(
            initial: profile,
            onSaved: () => Navigator.of(sheet).pop(),
          ),
        ),
      ),
    );
  }
}

/// Evaluación con la última medición completa y el último peso.
/// Peso actual grande, cambio desde el primer registro, tendencia y gráfico.
class _WeightHero extends StatelessWidget {
  const _WeightHero({required this.measurements});

  final List<Measurement> measurements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weighIns = [for (final m in measurements) WeighIn(m.date, m.weightKg)];
    final line = trendLine(weighIns);
    final last = measurements.last;
    final first = measurements.first;
    final change = last.weightKg - first.weightKg;
    final weeks = last.date.difference(first.date).inDays / 7;
    final trend = weightTrend(weighIns, paceKgPerWeek: 0.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(fmt(last.weightKg, 1),
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Text('kg', style: theme.textTheme.titleMedium),
          ],
        ),
        Text(
          [
            if (measurements.length > 1)
              '${change <= 0 ? '−' : '+'}${fmt(change.abs(), 1)} kg en ${weeks < 2 ? '${last.date.difference(first.date).inDays} días' : '${fmt(weeks)} semanas'}',
            if (trend.kgPerWeek != null)
              'tendencia ${trend.kgPerWeek! <= 0 ? '−' : '+'}${fmt(trend.kgPerWeek!.abs(), 1)} kg/sem',
            if (measurements.length == 1) 'primer registro: ${fmtDate(last.date)}',
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (measurements.length > 1) ...[
          const SizedBox(height: 10),
          WeightChart(weighIns: weighIns, trend: line),
        ],
      ],
    );
  }
}

String _photoSummary(WidgetRef ref) {
  final list = ref.watch(bodyAssessmentsProvider).value ?? const [];
  return list.isEmpty
      ? 'La IA estima tu % de grasa con fotos y tus medidas'
      : '${fmt(list.last.finalFatPct, 1)} % de grasa · ${fmtDate(list.last.date)}';
}

/// El plan de la semana (el mismo de Hoy y Plan), si ya hay cuestionario.
NutritionPlan? _weekPlan(WidgetRef ref, List<Measurement> list) {
  final p = ref.watch(profileProvider).value;
  final q = ref.watch(questionnaireProvider).value;
  if (p == null || q == null || list.isEmpty) return null;
  return weeklyNutrition(
    profile: p,
    measurements: list,
    questionnaire: q,
    today: DateTime.now(),
    kcalAdjustment: totalAdjustment(ref.watch(kcalAdjustmentsProvider).value ?? const []),
            assessments: ref.watch(bodyAssessmentsProvider).value ?? const [],
  );
}

class EvaluationCard extends StatelessWidget {
  const EvaluationCard({
    super.key,
    required this.profile,
    required this.measurements,
    this.today,
    this.plan,
  });

  /// Meta de la semana; sin cuestionario se muestra la estimación base.
  final NutritionPlan? plan;

  final UserProfile profile;

  /// De la más antigua a la más reciente.
  final List<Measurement> measurements;

  /// Fecha de referencia para la edad (por defecto, hoy).
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final age = profile.ageOn(now);
    final last = measurements.last;
    final lastFull = measurements.lastWhere(
      (m) => m.compositionFor(profile).fatPct != null,
      orElse: () => last,
    );
    final comp = lastFull.compositionFor(profile);
    final currentBmi = bodyMassIndex(last.weightKg, profile.heightCm);
    final energy = energyTarget(
      sex: profile.sex,
      weightKg: last.weightKg,
      heightCm: profile.heightCm,
      age: age,
      activityFactor: profile.activityFactor,
      paceKgPerWeek: profile.paceKgPerWeek,
      split: profile.split,
      bodyFatPct: comp.fatPct,
    );

    final tiles = <Widget>[
      _Stat('Peso', '${fmt(last.weightKg, 1)} kg', fmtDate(last.date)),
      _Stat('IMC', fmt(currentBmi, 1), null, bmiRating(currentBmi)),
    ];
    if (comp.fatPct != null) {
      final whtr = comp.waistToHeight!;
      tiles.addAll([
        _Stat('% grasa', '${fmt(comp.fatPct, 1)} %',
            'medidas al ${fmtDate(lastFull.date)}',
            fatRating(profile.sex, age, comp.fatPct!)),
        _Stat('Masa grasa', '${fmt(comp.fatKg, 1)} kg', null),
        _Stat('Masa magra', '${fmt(comp.leanKg, 1)} kg', null),
        _Stat('IMCM', fmt(comp.imcm, 1), null,
            imcmRating(profile.sex, comp.imcm!)),
        _Stat('Cintura / estatura', fmt(whtr, 2), null,
            waistToHeightRating(whtr)),
      ]);
    }
    final pl = plan;
    tiles.addAll([
      _Stat('Metabolismo basal', '${fmt(pl?.bmr ?? energy.bmr)} kcal',
          (pl?.formula ?? energy.formula).label),
      _Stat('Meta diaria', '${fmt(pl?.kcal ?? energy.kcal)} kcal',
          pl == null
              ? 'déficit ${fmt(energy.deficit)} kcal'
              : 'déficit ${fmt(pl.deficit)} kcal · fija hasta el lunes'),
      _Stat('Proteína', '${fmt(pl?.protein ?? energy.grams.protein)} g',
          'C ${fmt(pl?.carbs ?? energy.grams.carbs)} g · L ${fmt(pl?.fat ?? energy.grams.lipids)} g'),
    ]);

    StagedGoal? goal;
    if (comp.leanKg != null) {
      goal = stagedGoal(
        weightKg: last.weightKg,
        leanKg: comp.leanKg!,
        goalFatPct: profile.goalFatPct,
        dailyDeficitKcal: plan?.deficit ?? energy.deficit,
      );
    }
    String inTime(double? weeks) => weeks == null
        ? 'sin déficit'
        : weeks < 9
            ? 'en ~${fmt(weeks)} semanas'
            : 'en ~${fmt(weeks / 4.345, 1)} meses';

    final omsRange = omsFatRangeFor(age).forSex(profile.sex);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evaluación actual',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _StatGrid(tiles: tiles),
            if (goal != null) ...[
              const SizedBox(height: 16),
              Text('Tu meta, por etapas',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _StatGrid(tiles: [
                _Stat(
                  goal.finalGoal == null ? 'Meta' : 'Etapa 1',
                  '${fmt(goal.firstStage.targetWeightKg, 1)} kg',
                  '−${fmt(goal.firstStage.kgToLose, 1)} kg ${inTime(goal.firstStage.weeks)}',
                ),
                if (goal.finalGoal != null)
                  _Stat(
                    'Meta final',
                    '${fmt(goal.finalGoal!.targetWeightKg, 1)} kg',
                    '${fmt(profile.goalFatPct, 1)} % de grasa · ${inTime(goal.finalGoal!.weeks)}',
                  ),
              ]),
              if (goal.finalGoal != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Primero el 10 % de tu peso: es la bajada que más mejora tu '
                  'salud y la más fácil de sostener. Después vamos por la '
                  'siguiente.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            const SizedBox(height: 12),
            Text(
              'Saludable para tu edad (OMS): ${fmt(omsRange.$1)}–${fmt(omsRange.$2)} % de grasa.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cifras en 2 columnas (3 o 4 en pantallas anchas).
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 640 ? 4 : c.maxWidth >= 480 ? 3 : 2;
      final w = (c.maxWidth - 8 * (cols - 1)) / cols;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.detail, [this.rating]);

  final String label;
  final String value;
  final String? detail;
  final Rating? rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (rating?.severity) {
      Severity.good => MagraColors.good,
      Severity.warning => MagraColors.warning,
      Severity.bad => MagraColors.bad,
      null => null,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          if (rating != null)
            Text('● ${rating!.label}',
                style: theme.textTheme.labelMedium?.copyWith(color: color)),
          if (detail != null)
            Text(detail!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.profile, required this.measurements});

  final UserProfile profile;
  final List<Measurement> measurements;

  Future<void> _delete(BuildContext context, WidgetRef ref, Measurement m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Borrar medición'),
        content: Text('¿Borrar la medición del ${fmtDate(m.date)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(measurementRepositoryProvider).delete(m.id!);
      ref.invalidate(measurementsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo borrar.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Historial',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final m in measurements.reversed)
              _HistoryTile(
                profile: profile,
                m: m,
                onDelete: m.id == null ? null : () => _delete(context, ref, m),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.profile, required this.m, this.onDelete});

  final UserProfile profile;
  final Measurement m;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = m.compositionFor(profile);
    final parts = <String>[
      if (m.waistCm != null) 'cintura ${fmt(m.waistCm, 1)}',
      if (c.fatPct != null) 'grasa ${fmt(c.fatPct, 1)} %',
      if (c.leanKg != null) 'magra ${fmt(c.leanKg, 1)} kg',
    ];
    final reported = m.reportedFatPct;
    if (reported != null && c.fatPct != null && (reported - c.fatPct!).abs() > 1) {
      parts.add('informado ${fmt(reported, 1)} %');
    }
    return ListTile(
      title: Text('${fmt(m.weightKg, 1)} kg · ${fmtDate(m.date)}'),
      subtitle: Text([
        if (m.source != 'app') m.source,
        if (parts.isNotEmpty) parts.join(' · '),
      ].join('\n')),
      isThreeLine: m.source != 'app' && parts.isNotEmpty,
      trailing: onDelete == null
          ? null
          : IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.children});

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

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

/// Invita a responder el cuestionario o muestra que está completo.
class QuestionnaireCard extends ConsumerWidget {
  const QuestionnaireCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(questionnaireProvider);
    final theme = Theme.of(context);
    void open() => Navigator.of(context).push(MaterialPageRoute<bool>(
          builder: (_) => QuestionnairePage(initial: q.value),
        ));
    return q.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, st) => _Retry(
        message: 'No se pudo cargar tu cuestionario.',
        onRetry: () => ref.invalidate(questionnaireProvider),
      ),
      data: (answers) => answers == null
          ? Card(
              color: theme.colorScheme.primaryContainer,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(Icons.assignment_outlined,
                    color: theme.colorScheme.onPrimaryContainer),
                title: const Text('Cuéntame de ti para armar tu plan'),
                subtitle: const Text(
                    'Rutina, entrenamiento, salud y alimentación: 4 pasos, '
                    'unos 3 minutos.'),
                trailing: FilledButton(
                    onPressed: open, child: const Text('Responder')),
              ),
            )
          : Card(
              child: ListTile(
                leading: Icon(
                  answers.needsProfessionalSupervision
                      ? Icons.health_and_safety_outlined
                      : Icons.assignment_turned_in_outlined,
                  color: answers.needsProfessionalSupervision
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                title: const Text('Cuestionario completo'),
                subtitle: Text(
                  answers.needsProfessionalSupervision
                      ? 'Tu plan debe guiarlo un profesional de salud.'
                      : '${answers.trainingDays} días de entrenamiento · '
                          '${answers.preferredMeals == null ? 'comidas: MAGRA decide' : '${answers.preferredMeals} comidas al día'}',
                ),
                trailing: TextButton(onPressed: open, child: const Text('Editar')),
              ),
            ),
    );
  }
}

String _evaluationSummary(UserProfile profile, List<Measurement> list) {
  final last = list.last;
  final fat = last.compositionFor(profile).fatPct;
  return '${fmt(last.weightKg, 1)} kg${fat == null ? '' : ' · ${fmt(fat, 1)} % grasa'} · ${fmtDate(last.date)}';
}
