import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/user_profile.dart';
import '../../features/progress/measurement.dart';

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
