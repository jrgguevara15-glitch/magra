import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import '../../core/recommendation/nutrition_plan.dart';
import '../../core/recommendation/weekly_adjustment.dart';
import '../profile/user_profile.dart';
import 'measurement.dart';

/// Peso de tendencia, gasto real y el ajuste de calorías de la semana.
class WeeklyCheckCard extends ConsumerStatefulWidget {
  const WeeklyCheckCard({
    super.key,
    required this.profile,
    required this.measurements,
  });

  final UserProfile profile;

  /// De la más antigua a la más reciente.
  final List<Measurement> measurements;

  @override
  ConsumerState<WeeklyCheckCard> createState() => _WeeklyCheckCardState();
}

class _WeeklyCheckCardState extends ConsumerState<WeeklyCheckCard> {
  bool _busy = false;

  Future<void> _decide(DateTime week, WeeklySuggestion s, bool applied) async {
    setState(() => _busy = true);
    try {
      await ref.read(kcalAdjustmentRepositoryProvider).save(KcalAdjustment(
            weekStart: week,
            deltaKcal: s.deltaKcal,
            applied: applied,
            reason: s.reason.name,
          ));
      ref.invalidate(kcalAdjustmentsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo guardar. Revisa tu conexión.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final week = weekStartOf(today);
    final weighIns = [
      for (final m in widget.measurements) WeighIn(m.date, m.weightKg),
    ];
    final pace = profile.paceKgPerWeek;
    final trend = weightTrend(weighIns, paceKgPerWeek: pace);
    final line = trendLine(weighIns);

    final q = ref.watch(questionnaireProvider).value;
    final adjustments = ref.watch(kcalAdjustmentsProvider).value ?? const [];
    final intake = ref.watch(recentIntakeProvider).value ?? const {};
    final total = totalAdjustment(adjustments);
    final floor = safeFloorKcal(profile.sex);
    final adaptive = adaptiveTdee(
      dailyKcal: intake,
      weighIns: weighIns,
      today: today,
      minDayKcal: floor * 0.6,
    );

    final decided = adjustments.where((a) => a.weekStart == week).firstOrNull;
    final plan = q == null
        ? null
        : recommendNutrition(
            profile: profile,
            weightKg: widget.measurements.last.weightKg,
            questionnaire: q,
            today: today,
            kcalAdjustment: total,
          );
    final suggestion = plan == null
        ? null
        : weeklySuggestion(
            trend: trend,
            previousTrend: weightTrend(
              [for (final w in weighIns) if (w.date.isBefore(week)) w],
              paceKgPerWeek: pace,
            ),
            adaptive: adaptive,
            currentKcal: plan.kcal,
            floorKcal: floor,
            paceKgPerWeek: pace,
            currentTotal: total,
            maintenance: plan.maintenanceOnly,
          );

    final logged = intake.entries
        .where((e) => e.key.isBefore(today) && e.value >= floor * 0.6)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tendencia y ajuste semanal', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (weighIns.length >= 2) ...[
              WeightChart(weighIns: weighIns, trend: line),
              const SizedBox(height: 4),
              Wrap(
                spacing: 16,
                children: [
                  _Legend(color: theme.colorScheme.outline, label: 'Pesajes', dot: true),
                  _Legend(color: theme.colorScheme.primary, label: 'Tendencia'),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (line.isNotEmpty)
              Text(
                'Peso de tendencia: ${fmt(line.last.weightKg, 1)} kg'
                '${trend.kgPerWeek == null ? '' : ' · ${trend.kgPerWeek! <= 0 ? 'bajas' : 'subes'} '
                    '${fmt(trend.kgPerWeek!.abs(), 2)} kg por semana (meta '
                    '${fmt(pace, 2)})'}',
                style: theme.textTheme.titleMedium,
              ),
            const SizedBox(height: 4),
            Text(
              adaptive != null
                  ? 'Gasto real estimado: ${fmt(adaptive.tdee)} kcal al día '
                      '(la fórmula dice ${fmt(plan?.tdee)}), con '
                      '${adaptive.loggedDays} días registrados.'
                  : 'Para estimar tu gasto real: anota todo lo que comes al '
                      'menos 10 de los últimos 21 días (llevas $logged) y '
                      'pésate 3 veces en ese tiempo.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (suggestion == null)
              const Text('Responde el cuestionario para recibir el ajuste '
                  'semanal de tus calorías.')
            else ...[
              Text(
                decided == null
                    ? 'Esta semana'
                    : decided.applied
                        ? 'Esta semana aplicaste ${_signed(decided.deltaKcal)} kcal'
                        : 'Esta semana decidiste mantener tus calorías',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(suggestion.message),
              if (decided == null && suggestion.deltaKcal != 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _decide(week, suggestion, true),
                      child: Text('Aplicar ${_signed(suggestion.deltaKcal)} kcal'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _decide(week, suggestion, false),
                      child: const Text('Ahora no'),
                    ),
                  ],
                ),
              ],
            ],
            if (total != 0 && plan != null) ...[
              const SizedBox(height: 8),
              Text(
                'Ajuste acumulado: ${_signed(total)} kcal · tu meta hoy: '
                '${fmt(plan.kcal)} kcal.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _signed(int v) => v > 0 ? '+$v' : '−${v.abs()}';

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.dot = false});

  final Color color;
  final String label;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dot ? 8 : 16,
          height: dot ? 8 : 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Pesajes (puntos) y peso de tendencia (línea) de los últimos 90 días.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.weighIns, required this.trend});

  final List<WeighIn> weighIns;
  final List<WeighIn> trend;

  static const days = 90;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = trend.isEmpty ? weighIns.last.date : trend.last.date;
    final from = last.subtract(const Duration(days: days));
    final points = [for (final w in weighIns) if (!w.date.isBefore(from)) w];
    final line = [for (final w in trend) if (!w.date.isBefore(from)) w];
    final all = [...points, ...line];
    if (all.isEmpty) return const SizedBox.shrink();
    final first = all.map((w) => w.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final ys = all.map((w) => w.weightKg);
    final lo = ys.reduce((a, b) => a < b ? a : b) - 0.5;
    final hi = ys.reduce((a, b) => a > b ? a : b) + 0.5;
    final style = theme.textTheme.labelSmall;
    return Semantics(
      label: 'Gráfico de peso: ${points.length} pesajes y línea de tendencia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmt(hi, 1), style: style),
                    Text(fmt(lo, 1), style: style),
                  ],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: CustomPaint(
                    painter: _ChartPainter(
                      points: points,
                      line: line,
                      first: first,
                      last: last,
                      lo: lo,
                      hi: hi,
                      dotColor: theme.colorScheme.outline,
                      lineColor: theme.colorScheme.primary,
                      gridColor: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fmtDate(first), style: style),
              Text(fmtDate(last), style: style),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.line,
    required this.first,
    required this.last,
    required this.lo,
    required this.hi,
    required this.dotColor,
    required this.lineColor,
    required this.gridColor,
  });

  final List<WeighIn> points;
  final List<WeighIn> line;
  final DateTime first;
  final DateTime last;
  final double lo;
  final double hi;
  final Color dotColor;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final span = last.difference(first).inHours.toDouble();
    Offset at(WeighIn w) => Offset(
          span == 0 ? size.width / 2 : w.date.difference(first).inHours / span * size.width,
          size.height - (w.weightKg - lo) / (hi - lo) * size.height,
        );
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (line.length >= 2) {
      final path = Path()..moveTo(at(line.first).dx, at(line.first).dy);
      for (final w in line.skip(1)) {
        path.lineTo(at(w).dx, at(w).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
    final dot = Paint()..color = dotColor;
    for (final w in points) {
      canvas.drawCircle(at(w), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points || old.line != line || old.lineColor != lineColor;
}
