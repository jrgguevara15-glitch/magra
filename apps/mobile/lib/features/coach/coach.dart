import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import '../../core/recommendation/nutrition_plan.dart';
import '../../core/recommendation/progression.dart';
import '../plan/plan_inputs.dart';
import '../progress/measurement.dart';
import '../today/activity_log.dart';
import '../today/food_catalog.dart';

/// Un mensaje de la conversación con el coach.
class CoachMessage {
  const CoachMessage({
    this.id,
    required this.role,
    required this.content,
    this.kind = 'chat',
    this.createdAt,
  });

  factory CoachMessage.fromRow(Map<String, dynamic> row) => CoachMessage(
        id: row['id'] as String?,
        role: row['role'] as String,
        kind: row['kind'] as String? ?? 'chat',
        content: row['content'] as String,
        createdAt: row['created_at'] == null
            ? null
            : DateTime.parse(row['created_at'] as String).toLocal(),
      );

  final String? id;

  /// 'user' o 'assistant'.
  final String role;

  /// 'chat' o 'review' (revisión semanal).
  final String kind;
  final String content;
  final DateTime? createdAt;

  bool get fromUser => role == 'user';

  Map<String, dynamic> toRow() => {'role': role, 'kind': kind, 'content': content};

  Map<String, dynamic> toApi() => {'role': role, 'content': content};
}

/// Mensajes que se mandan como historial (los últimos).
const coachHistoryLimit = 20;

double _r(double v, [int d = 1]) {
  final f = d == 0 ? 1 : (d == 1 ? 10 : 100);
  return (v * f).round() / f;
}

/// Lo que el coach sabe de la persona: un resumen con números redondeados
/// (sin nombre ni correo). Son los mismos datos que ya ve en la app.
Map<String, dynamic> coachContext({
  required PlanInputs inputs,
  required NutritionPlan plan,
  required List<Measurement> measurements,
  required List<FoodEntry> todayFood,
  required List<ExerciseEntry> todayExercise,
  required Map<DateTime, double> recentIntake,
  required List<WorkoutSession> workouts,
  required String nextWorkout,
}) {
  final q = inputs.questionnaire;
  final c = inputs.composition;
  final today = DateTime(inputs.today.year, inputs.today.month, inputs.today.day);
  final weighIns = [for (final m in measurements) WeighIn(m.date, m.weightKg)];
  final trend = weightTrend(weighIns, paceKgPerWeek: inputs.profile.paceKgPerWeek);
  final line = trendLine(weighIns);
  final eaten = todayFood.fold<double>(0, (a, e) => a + e.kcal);
  final protein = todayFood.fold<double>(0, (a, e) => a + e.protein);
  final days = recentIntake.keys.where((d) => d.isBefore(today)).toList()..sort();
  final week = days.length > 7 ? days.sublist(days.length - 7) : days;

  return {
    'hoy': isoDate(today),
    'perfil': {
      'sexo': inputs.profile.sex == Sex.male ? 'hombre' : 'mujer',
      'edad': inputs.age,
      'estatura_cm': _r(inputs.profile.heightCm, 0),
      'ritmo_meta_kg_semana': inputs.profile.paceKgPerWeek,
    },
    'medidas': {
      'peso_kg': _r(inputs.weightKg),
      if (line.isNotEmpty) 'peso_tendencia_kg': _r(line.last.weightKg),
      if (trend.kgPerWeek != null) 'cambio_kg_semana': _r(trend.kgPerWeek!, 2),
      'imc': _r(c.bmi),
      if (c.fatPct != null) 'grasa_pct': _r(c.fatPct!),
      if (c.leanKg != null) 'masa_magra_kg': _r(c.leanKg!),
      if (c.waistCm != null) 'cintura_cm': _r(c.waistCm!),
      'pesajes_registrados': measurements.length,
    },
    'plan': {
      'kcal': _r(plan.kcal, 0),
      'proteina_g': _r(plan.protein, 0),
      'carbohidratos_g': _r(plan.carbs, 0),
      'grasas_g': _r(plan.fat, 0),
      'gasto_formula_kcal': _r(plan.tdee, 0),
      if (plan.adjustmentKcal != 0) 'ajuste_semanal_kcal': _r(plan.adjustmentKcal, 0),
      'solo_mantencion': plan.maintenanceOnly,
      if (plan.fastingHours != null) 'ayuno_horas': plan.fastingHours,
      'comidas': [
        for (final m in plan.meals)
          '${m.time.hour.toString().padLeft(2, '0')}:${m.time.minute.toString().padLeft(2, '0')} '
              '${_r(m.kcal, 0).round()} kcal',
      ],
    },
    'cuestionario': {
      'dieta': q.dietPattern.label,
      if (q.allergies.isNotEmpty) 'alergias': [for (final a in q.allergies) a.label],
      if (q.dislikedFoods.trim().isNotEmpty) 'no_le_gusta': q.dislikedFoods.trim(),
      if (q.healthConditions.isNotEmpty)
        'salud': [for (final h in q.healthConditions) h.label],
      if (q.injuries.isNotEmpty) 'lesiones': [for (final i in q.injuries) i.label],
      'entrena_dias_semana': q.trainingDays,
      'minutos_sesion': q.sessionMinutes,
      'horario_entreno': q.trainingTime.label,
      'experiencia': q.experience.label,
      'equipo': q.equipment.label,
      'presupuesto': q.budget.label,
      'cocina': q.cooking.label,
      'ayuno': q.fasting.label,
    },
    'registro_hoy': {
      'kcal': _r(eaten, 0),
      'proteina_g': _r(protein, 0),
      'alimentos': [for (final e in todayFood.take(20)) e.name],
      'ejercicio_kcal': _r(todayExercise.fold<double>(0, (a, e) => a + e.kcalNet), 0),
    },
    'ultimos_dias_kcal': {
      for (final d in week) isoDate(d): _r(recentIntake[d]!, 0),
    },
    'entrenos_recientes': [
      for (final s in workouts.reversed.take(5))
        {
          'fecha': isoDate(s.date),
          'sesion': s.title,
          'series': s.exercises.fold<int>(0, (a, e) => a + e.sets.length),
          'kg_movidos': _r(s.volume, 0),
        },
    ],
    'proxima_sesion': nextWorkout,
  };
}

/// Sugerencias para empezar la conversación.
const coachSuggestions = [
  '¿Qué ceno hoy con lo que me queda?',
  '¿Por qué no estoy bajando de peso?',
  '¿Cómo llego a mi proteína del día?',
  'Me duele la rodilla, ¿qué cambio del entreno?',
];

/// Revisión semanal sugerida: domingo o lunes sin una en los últimos 6 días.
bool reviewDue(List<CoachMessage> messages, DateTime now) {
  if (now.weekday != DateTime.sunday && now.weekday != DateTime.monday) return false;
  for (final m in messages) {
    if (m.kind == 'review' && m.createdAt != null &&
        now.difference(m.createdAt!).inDays < 6) {
      return false;
    }
  }
  return true;
}

/// Error con un mensaje listo para mostrar.
class CoachException implements Exception {
  const CoachException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class CoachClient {
  /// Respuesta del coach. [mode] es 'chat' o 'review'.
  Future<String> ask({
    required String mode,
    required List<CoachMessage> history,
    required Map<String, dynamic> context,
  });
}

String coachErrorMessage(int status, Object? details) {
  if (details is Map && details['error'] is String) {
    final text = details['error'] as String;
    return status >= 500 ? '$text (error $status)' : text;
  }
  return switch (status) {
    401 => 'El servidor rechazó tu sesión. Vuelve a entrar.',
    403 => 'Primero acepta compartir tus datos con el coach.',
    404 => 'La función del coach (ai-coach) aún no está instalada en el servidor.',
    429 => 'Llegaste al límite de mensajes al coach por hoy.',
    _ => 'El coach no pudo responder (error $status). Intenta de nuevo.',
  };
}

class SupabaseCoachClient implements CoachClient {
  SupabaseCoachClient(this._client);

  final SupabaseClient _client;

  @override
  Future<String> ask({
    required String mode,
    required List<CoachMessage> history,
    required Map<String, dynamic> context,
  }) async {
    final Object? data;
    try {
      final res = await _client.functions.invoke('ai-coach', body: {
        'mode': mode,
        'messages': [
          for (final m in history.length > coachHistoryLimit
              ? history.sublist(history.length - coachHistoryLimit)
              : history)
            m.toApi(),
        ],
        'context': context,
      });
      data = res.data;
    } on FunctionException catch (e) {
      throw CoachException(coachErrorMessage(e.status, e.details));
    } catch (_) {
      throw const CoachException('No hay conexión con el servidor. Revisa tu internet.');
    }
    final reply = data is Map ? data['reply'] : null;
    if (reply is! String || reply.trim().isEmpty) {
      throw const CoachException('El servidor respondió algo inesperado. Revisa que la '
          'función ai-coach tenga el código de MAGRA.');
    }
    return reply;
  }
}

abstract interface class CoachRepository {
  /// La conversación, de la más antigua a la más reciente.
  Future<List<CoachMessage>> messages();
  Future<void> add(CoachMessage message);
  Future<void> clear();
  Future<bool> hasConsent();
  Future<void> setConsent(bool accepted);
}

class SupabaseCoachRepository implements CoachRepository {
  SupabaseCoachRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CoachMessage>> messages() async {
    final rows = await _client
        .from('coach_messages')
        .select()
        .order('created_at', ascending: false)
        .limit(200);
    return [for (final r in rows.reversed) CoachMessage.fromRow(r)];
  }

  @override
  Future<void> add(CoachMessage message) =>
      _client.from('coach_messages').insert(message.toRow());

  @override
  Future<void> clear() => _client
      .from('coach_messages')
      .delete()
      .eq('user_id', _client.auth.currentUser!.id);

  @override
  Future<bool> hasConsent() async {
    final row = await _client
        .from('ai_consents')
        .select('feature')
        .eq('feature', 'coach')
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> setConsent(bool accepted) => accepted
      ? _client.from('ai_consents').upsert({'feature': 'coach'},
          onConflict: 'user_id,feature', ignoreDuplicates: true)
      : _client.from('ai_consents').delete().eq('feature', 'coach');
}
