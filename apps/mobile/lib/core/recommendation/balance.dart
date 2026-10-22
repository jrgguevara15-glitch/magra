/// Proyección del coach: cómo cerrarías hoy si comes lo que queda del plan
/// y adónde te lleva tu promedio de los últimos días (bajar, mantener o
/// subir), comparado con tu meta y tu gasto.
library;

import '../format.dart';
import '../formulas/trend.dart' show kcalPerKgFat;
import 'motivation.dart';

enum BalanceTone { good, warn, bad }

class BalanceForecast {
  const BalanceForecast({
    required this.tone,
    required this.title,
    required this.lines,
    required this.projectedToday,
    required this.overToday,
    this.days = 0,
    this.avgIntake,
    this.avgOverMeta,
    this.kgPerWeek,
  });

  final BalanceTone tone;
  final String title;
  final List<String> lines;

  /// Lo que comerías hoy si completas las comidas pendientes del plan.
  final double projectedToday;

  /// [projectedToday] menos lo disponible hoy (positivo = te pasarías).
  final double overToday;

  /// Días usados en el promedio (incluye hoy proyectado).
  final int days;
  final double? avgIntake;
  final double? avgOverMeta;

  /// Cambio de peso esperado a este ritmo (negativo = baja).
  final double? kgPerWeek;
}

String _kg(double v) => fmt(v.abs(), 1);

/// [history]: días anteriores (sin hoy). [pendingMealKcal]: kcal del plan de
/// las comidas que aún no se anotan. [available]: meta de hoy más extras
/// (ejercicio, banco). [tdee]: gasto diario (real si se conoce).
BalanceForecast balanceForecast({
  required DateTime today,
  required Map<DateTime, DayTotals> history,
  required double eatenToday,
  required List<double> pendingMealKcal,
  required double metaKcal,
  required double available,
  required double tdee,
  required bool tdeeIsReal,
  required double plannedKgPerWeek,
  required double floorKcal,
}) {
  final pending = pendingMealKcal.fold<double>(0, (a, b) => a + b);
  final projected = eatenToday + pending;
  final over = projected - available;
  final left = available - eatenToday;
  final lines = <String>[];

  // Hoy.
  if (eatenToday > 0) {
    if (left < 0) {
      lines.add('Hoy ya vas ${fmt(-left)} kcal sobre tu meta. Sin drama: un día no define '
          'tu progreso; lo que importa es el promedio de la semana.');
    } else if (pendingMealKcal.isNotEmpty && over > 50) {
      final n = pendingMealKcal.length;
      lines.add('Si comes ${n == 1 ? 'tu última comida' : 'tus $n comidas restantes'} como dice el plan '
          '(~${fmt(pending)} kcal), cerrarías en ${fmt(projected)} kcal: ${fmt(over)} sobre tu meta. '
          'Para quedar en tu meta te quedan ${fmt(left)} kcal: prioriza proteína magra y verduras.');
    } else if (pendingMealKcal.isNotEmpty) {
      lines.add('Vas bien: con lo que queda del plan cerrarías en ${fmt(projected)} kcal, dentro de tu meta.');
    }
  }

  // Promedio: hasta 7 días registrados antes de hoy, más hoy proyectado.
  final start = DateTime(today.year, today.month, today.day - 7);
  final todayKey = DateTime(today.year, today.month, today.day);
  final past = [
    for (final e in history.entries)
      if (!e.key.isBefore(start) && e.key.isBefore(todayKey) && loggedDay(e.value, floorKcal)) e.value.kcal,
  ];
  final days = [...past, if (eatenToday > 0) projected];
  double? avg, avgOver, kgWeek;
  var tone = over > 50 || left < 0 ? BalanceTone.warn : BalanceTone.good;
  if (days.length >= 2) {
    avg = days.reduce((a, b) => a + b) / days.length;
    avgOver = avg - metaKcal;
    kgWeek = (avg - tdee) * 7 / kcalPerKgFat;
    lines.add('Últimos ${days.length} días${eatenToday > 0 ? ' (con hoy proyectado)' : ''}: '
        'promedio de ${fmt(avg)} kcal al día, '
        '${avgOver.abs() < 25 ? 'justo en tu meta' : avgOver > 0 ? '${fmt(avgOver)} sobre tu meta' : '${fmt(-avgOver)} bajo tu meta'}.');
    final gasto = tdeeIsReal ? 'tu gasto real' : 'tu gasto estimado';
    if (kgWeek >= 0.05) {
      tone = BalanceTone.bad;
      lines.add('A este ritmo comes sobre $gasto (${fmt(tdee)} kcal): subirías ~${_kg(kgWeek)} kg por '
          'semana, casi todo grasa. Volver a tu meta lo corrige en pocos días.');
    } else if (kgWeek > -0.1) {
      tone = BalanceTone.bad;
      lines.add('A este ritmo quedas cerca de $gasto (${fmt(tdee)} kcal): te mantendrías, sin bajar peso '
          'ni grasa. Con ${fmt(avgOver.clamp(0, double.infinity) + 100)} kcal menos al día vuelves a bajar.');
    } else {
      final ok = -kgWeek >= plannedKgPerWeek * 0.75;
      if (!ok && tone == BalanceTone.good) tone = BalanceTone.warn;
      lines.add(ok
          ? 'A este ritmo bajarías ~${_kg(kgWeek)} kg por semana: vas según tu plan '
              '(${fmt(plannedKgPerWeek, 2)} kg). ¡Sigue así!'
          : 'A este ritmo bajarías ~${_kg(kgWeek)} kg por semana, menos que tu plan '
              '(${fmt(plannedKgPerWeek, 2)} kg): ajustar el promedio a tu meta te devuelve al ritmo.');
    }
  }
  final title = switch (tone) {
    BalanceTone.good => 'Vas en línea con tu meta',
    BalanceTone.warn => 'Ojo con el cierre del día',
    BalanceTone.bad => kgWeek != null && kgWeek >= 0.05 ? 'A este ritmo subirías de peso' : 'A este ritmo no bajarías',
  };
  return BalanceForecast(
    tone: tone,
    title: title,
    lines: lines,
    projectedToday: projected,
    overToday: over,
    days: days.length,
    avgIntake: avg,
    avgOverMeta: avgOver,
    kgPerWeek: kgWeek,
  );
}
