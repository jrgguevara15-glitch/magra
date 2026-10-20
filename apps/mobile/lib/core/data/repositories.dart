import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/user_profile.dart';
import '../../features/progress/measurement.dart';
import '../../features/questionnaire/questionnaire.dart';
import '../../features/today/activity_log.dart';
import '../../features/today/food_catalog.dart';
import '../format.dart';

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
