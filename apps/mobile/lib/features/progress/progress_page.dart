import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import '../../core/theme.dart';
import '../profile/profile_form.dart';
import '../profile/user_profile.dart';
import 'measurement.dart';
import 'measurement_form.dart';

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

class _Progress extends ConsumerWidget {
  const _Progress({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurements = ref.watch(measurementsProvider);
    return measurements.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _Retry(
        message: 'No se pudieron cargar tus mediciones.',
        onRetry: () => ref.invalidate(measurementsProvider),
      ),
      data: (list) => _Page(children: [
        Row(
          children: [
            Expanded(
              child: Text(
                profile.name.isEmpty ? 'Tu progreso' : 'Hola, ${profile.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Editar perfil',
              icon: const Icon(Icons.tune),
              onPressed: () => _editProfile(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => showMeasurementForm(context, sex: profile.sex),
          icon: const Icon(Icons.add),
          label: const Text('Nueva medición'),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          const Text('Aún no tienes mediciones. Registra tu peso, cuello y '
              'cintura para ver tu evaluación.')
        else ...[
          EvaluationCard(profile: profile, measurements: list),
          const SizedBox(height: 16),
          _History(profile: profile, measurements: list),
        ],
      ]),
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
class EvaluationCard extends StatelessWidget {
  const EvaluationCard({
    super.key,
    required this.profile,
    required this.measurements,
    this.today,
  });

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
    tiles.addAll([
      _Stat('Metabolismo basal', '${fmt(energy.bmr)} kcal', 'Mifflin-St Jeor'),
      _Stat('Meta diaria', '${fmt(energy.kcal)} kcal',
          'déficit ${fmt(energy.deficit)} kcal'),
      _Stat('Proteína', '${fmt(energy.grams.protein)} g',
          'C ${fmt(energy.grams.carbs)} g · L ${fmt(energy.grams.lipids)} g'),
    ]);

    PhysicalGoal? goal;
    if (comp.leanKg != null) {
      goal = PhysicalGoal.from(
        weightKg: last.weightKg,
        leanKg: comp.leanKg!,
        goalFatPct: profile.goalFatPct,
        dailyDeficitKcal: energy.deficit,
      );
    }

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
            Wrap(spacing: 10, runSpacing: 10, children: tiles),
            if (goal != null) ...[
              const SizedBox(height: 16),
              Text('Meta física', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _Stat('Peso meta', '${fmt(goal.goalWeightKg, 1)} kg',
                    '${fmt(profile.goalFatPct, 1)} % de grasa'),
                _Stat('Grasa a eliminar', '${fmt(goal.fatToLoseKg, 1)} kg',
                    null),
                _Stat(
                    'Tiempo estimado',
                    goal.months == null ? '—' : '${fmt(goal.months, 1)} meses',
                    goal.weeks == null ? null : '${fmt(goal.weeks)} semanas'),
              ]),
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
      width: 160,
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
