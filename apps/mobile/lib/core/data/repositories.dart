import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/user_profile.dart';
import '../../features/menus/weekly_menu.dart';
import '../../features/progress/measurement.dart';
import '../../features/questionnaire/questionnaire.dart';
import '../../features/today/activity_log.dart';
import '../../features/today/barcode.dart';
import '../../features/today/food_catalog.dart';
import '../format.dart';
import '../recommendation/progression.dart';
import '../recommendation/weekly_adjustment.dart';

/// Sesión del usuario.
abstract interface class AuthRepository {
  /// Emite `true` al iniciar sesión y `false` al cerrarla.
  Stream<bool> signedInChanges();
  String? get email;
  Future<void> signIn(String email, String password);

  /// Devuelve `true` si la cuenta quedó pendiente de confirmar por correo.
  Future<bool> signUp(String email, String password);
  Future<void> signOut();
}

abstract interface class ProfileRepository {
  Future<UserProfile?> fetch();
  Future<void> save(UserProfile profile);
}

abstract interface class MeasurementRepository {
  /// Mediciones del usuario, de la más antigua a la más reciente.
  Future<List<Measurement>> list();

  /// Crea o reemplaza la medición de ese día.
  Future<void> save(Measurement measurement);
  Future<void> delete(String id);
}

abstract interface class QuestionnaireRepository {
  Future<Questionnaire?> fetch();
  Future<void> save(Questionnaire questionnaire);
}

abstract interface class FoodLogRepository {
  /// Lo registrado en un día, en el orden en que se anotó.
  Future<List<FoodEntry>> forDay(DateTime day);
  Future<void> add(FoodEntry entry);
  Future<void> delete(String id);

  /// Calorías registradas por día entre [from] y [to] (ambos incluidos).
  Future<Map<DateTime, double>> dailyKcal(DateTime from, DateTime to);
}

/// Productos que el usuario creó porque no estaban en Open Food Facts.
abstract interface class CustomProductRepository {
  Future<Product?> find(String code);

  /// Crea o reemplaza el producto de ese código.
  Future<void> save(Product product);
}

abstract interface class WorkoutRepository {
  /// Últimas sesiones, de la más antigua a la más reciente.
  Future<List<WorkoutSession>> recent({int limit = 60});
  Future<void> add(WorkoutSession session);
  Future<void> delete(String id);
}

abstract interface class MenuRepository {
  /// El menú de esa semana (lunes), o `null`.
  Future<WeeklyMenu?> forWeek(DateTime weekStart);

  /// Crea o reemplaza el menú de esa semana.
  Future<void> save(WeeklyMenu menu);
}

abstract interface class KcalAdjustmentRepository {
  /// Ajustes semanales, del más antiguo al más reciente.
  Future<List<KcalAdjustment>> list();

  /// Crea o reemplaza la decisión de esa semana.
  Future<void> save(KcalAdjustment adjustment);
}

abstract interface class ExerciseLogRepository {
  /// Actividades de un día, en el orden en que se anotaron.
  Future<List<ExerciseEntry>> forDay(DateTime day);
  Future<void> add(ExerciseEntry entry);
  Future<void> delete(String id);
}

abstract interface class FastRepository {
  /// El ayuno más reciente (en curso o terminado), o `null`.
  Future<Fast?> latest();
  Future<void> start(DateTime at, int targetHours);
  Future<void> end(String id, DateTime at);

  /// Borra un ayuno iniciado por error.
  Future<void> delete(String id);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<bool> signedInChanges() async* {
    yield _client.auth.currentSession != null;
    yield* _client.auth.onAuthStateChange.map((s) => s.session != null);
  }

  @override
  String? get email => _client.auth.currentUser?.email;

  @override
  Future<void> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  @override
  Future<bool> signUp(String email, String password) async {
    final res = await _client.auth.signUp(email: email, password: password);
    return res.session == null;
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<UserProfile?> fetch() async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', _uid)
        .maybeSingle();
    return row == null ? null : UserProfile.fromRow(row);
  }

  @override
  Future<void> save(UserProfile profile) =>
      _client.from('profiles').upsert({'id': _uid, ...profile.toRow()});
}

class SupabaseMeasurementRepository implements MeasurementRepository {
  SupabaseMeasurementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Measurement>> list() async {
    final rows = await _client
        .from('measurements')
        .select()
        .order('measured_on', ascending: true);
    return [for (final r in rows) Measurement.fromRow(r)];
  }

  @override
  Future<void> save(Measurement m) => _client
      .from('measurements')
      .upsert(m.toRow(), onConflict: 'user_id,measured_on');

  @override
  Future<void> delete(String id) =>
      _client.from('measurements').delete().eq('id', id);
}

class SupabaseQuestionnaireRepository implements QuestionnaireRepository {
  SupabaseQuestionnaireRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<Questionnaire?> fetch() async {
    final row = await _client
        .from('questionnaires')
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    return row == null ? null : Questionnaire.fromRow(row);
  }

  @override
  Future<void> save(Questionnaire q) => _client
      .from('questionnaires')
      .upsert({'user_id': _uid, ...q.toRow()});
}

class SupabaseFoodLogRepository implements FoodLogRepository {
  SupabaseFoodLogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<FoodEntry>> forDay(DateTime day) async {
    final rows = await _client
        .from('food_entries')
        .select()
        .eq('eaten_on', isoDate(day))
        .order('created_at', ascending: true);
    return [for (final r in rows) FoodEntry.fromRow(r)];
  }

  @override
  Future<void> add(FoodEntry entry) =>
      _client.from('food_entries').insert(entry.toRow());

  @override
  Future<void> delete(String id) =>
      _client.from('food_entries').delete().eq('id', id);

  @override
  Future<Map<DateTime, double>> dailyKcal(DateTime from, DateTime to) async {
    final rows = await _client
        .from('food_entries')
        .select('eaten_on, kcal')
        .gte('eaten_on', isoDate(from))
        .lte('eaten_on', isoDate(to));
    final out = <DateTime, double>{};
    for (final r in rows) {
      final day = DateTime.parse(r['eaten_on'] as String);
      out[day] = (out[day] ?? 0) + (r['kcal'] as num).toDouble();
    }
    return out;
  }
}

class SupabaseKcalAdjustmentRepository implements KcalAdjustmentRepository {
  SupabaseKcalAdjustmentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<KcalAdjustment>> list() async {
    final rows = await _client
        .from('kcal_adjustments')
        .select()
        .order('week_start', ascending: true);
    return [for (final r in rows) KcalAdjustment.fromRow(r)];
  }

  @override
  Future<void> save(KcalAdjustment a) => _client
      .from('kcal_adjustments')
      .upsert(a.toRow(), onConflict: 'user_id,week_start');
}

class SupabaseExerciseLogRepository implements ExerciseLogRepository {
  SupabaseExerciseLogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ExerciseEntry>> forDay(DateTime day) async {
    final rows = await _client
        .from('exercise_entries')
        .select()
        .eq('done_on', isoDate(day))
        .order('created_at', ascending: true);
    return [for (final r in rows) ExerciseEntry.fromRow(r)];
  }

  @override
  Future<void> add(ExerciseEntry entry) =>
      _client.from('exercise_entries').insert(entry.toRow());

  @override
  Future<void> delete(String id) =>
      _client.from('exercise_entries').delete().eq('id', id);
}

class SupabaseFastRepository implements FastRepository {
  SupabaseFastRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Fast?> latest() async {
    final row = await _client
        .from('fasts')
        .select()
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : Fast.fromRow(row);
  }

  @override
  Future<void> start(DateTime at, int targetHours) => _client.from('fasts').insert({
        'started_at': at.toUtc().toIso8601String(),
        'target_hours': targetHours,
      });

  @override
  Future<void> end(String id, DateTime at) => _client
      .from('fasts')
      .update({'ended_at': at.toUtc().toIso8601String()}).eq('id', id);

  @override
  Future<void> delete(String id) => _client.from('fasts').delete().eq('id', id);
}

class SupabaseCustomProductRepository implements CustomProductRepository {
  SupabaseCustomProductRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Product?> find(String code) async {
    final row = await _client
        .from('custom_products')
        .select()
        .eq('code', code)
        .maybeSingle();
    return row == null ? null : Product.fromRow(row);
  }

  @override
  Future<void> save(Product p) => _client.from('custom_products').upsert(
      {...p.toRow(), 'updated_at': DateTime.now().toUtc().toIso8601String()},
      onConflict: 'user_id,code');
}

class SupabaseMenuRepository implements MenuRepository {
  SupabaseMenuRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<WeeklyMenu?> forWeek(DateTime weekStart) async {
    final row = await _client
        .from('menus')
        .select()
        .eq('week_start', isoDate(weekStart))
        .maybeSingle();
    return row == null ? null : WeeklyMenu.fromRow(row);
  }

  @override
  Future<void> save(WeeklyMenu menu) => _client.from('menus').upsert(
      {...menu.toRow(), 'updated_at': DateTime.now().toUtc().toIso8601String()},
      onConflict: 'user_id,week_start');
}

class SupabaseWorkoutRepository implements WorkoutRepository {
  SupabaseWorkoutRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<WorkoutSession>> recent({int limit = 60}) async {
    final rows = await _client
        .from('workout_sessions')
        .select()
        .order('done_on', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final r in rows.reversed) WorkoutSession.fromRow(r)];
  }

  @override
  Future<void> add(WorkoutSession session) =>
      _client.from('workout_sessions').insert(session.toRow());

  @override
  Future<void> delete(String id) =>
      _client.from('workout_sessions').delete().eq('id', id);
}
