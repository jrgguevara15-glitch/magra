import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/formulas/formulas.dart';
import '../../core/recommendation/motivation.dart';
import '../../core/recommendation/weekly_basis.dart';
import '../../core/recommendation/weekly_adjustment.dart';
import '../profile/user_profile.dart';
import 'measurement.dart';
import 'progress_photos.dart';

/// Logros por hitos reales: grasa y cintura perdidas, rachas, entrenos y
/// fotos.
class AchievementsCard extends ConsumerWidget {
  const AchievementsCard({
    super.key,
    required this.profile,
    required this.measurements,
  });

  final UserProfile profile;

  /// De la más antigua a la más reciente.
  final List<Measurement> measurements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final history = ref.watch(foodHistoryProvider).value ?? const {};
    final workouts = ref.watch(workoutsProvider).value ?? const [];
    final photos = ref.watch(progressPhotosProvider).value ?? const [];
    final q = ref.watch(questionnaireProvider).value;
    final adjustments = ref.watch(kcalAdjustmentsProvider).value ?? const [];
    final floor = safeFloorKcal(profile.sex);
    final proteinTarget = q == null || measurements.isEmpty
        ? 0.0
        : weeklyNutrition(
            profile: profile,
            measurements: measurements,
            questionnaire: q,
            today: today,
            kcalAdjustment: totalAdjustment(adjustments),
          ).protein;

    final list = achievements(
      body: [
        for (final m in measurements)
          BodyPoint(m.date, m.weightKg,
              fatKg: m.compositionFor(profile).fatKg, waistCm: m.waistCm),
      ],
      loggedDays: [for (final e in history.entries) if (loggedDay(e.value, floor)) e.key],
      proteinDays: [
        for (final e in history.entries) if (proteinDay(e.value, proteinTarget)) e.key,
      ],
      workouts: workouts.length,
      photoDates: photoDates(photos),
    );
    final done = list.where((a) => a.done).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logros ($done de ${list.length})', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth >= 560 ? 3 : 2;
                final width = (c.maxWidth - 8 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in [...list.where((a) => a.done), ...list.where((a) => !a.done)])
                      SizedBox(width: width, child: _Badge(a)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.a);

  final Achievement a;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: a.done ? theme.colorScheme.primaryContainer : null,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(a.done ? Icons.emoji_events : Icons.lock_outline,
                  size: 18,
                  color: a.done ? theme.colorScheme.primary : theme.colorScheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(a.title,
                    style: theme.textTheme.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(a.detail, style: theme.textTheme.bodySmall),
          if (!a.done) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: a.progress, minHeight: 4),
          ],
        ],
      ),
    );
  }
}
