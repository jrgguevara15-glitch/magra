import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magra/app.dart';
import 'package:magra/core/data/providers.dart';
import 'package:magra/core/data/repositories.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/features/profile/user_profile.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

class FakeAuth implements AuthRepository {
  FakeAuth({bool signedIn = false}) : _signedIn = signedIn;

  bool _signedIn;
  final _changes = StreamController<bool>.broadcast();
  String? lastPassword;

  @override
  Stream<bool> signedInChanges() async* {
    yield _signedIn;
    yield* _changes.stream;
  }

  @override
  String? get email => _signedIn ? 'usuario@example.com' : null;

  @override
  Future<void> signIn(String email, String password) async {
    lastPassword = password;
    _signedIn = true;
    _changes.add(true);
  }

  @override
  Future<bool> signUp(String email, String password) async => true;

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _changes.add(false);
  }
}

class FakeProfiles implements ProfileRepository {
  FakeProfiles([this.profile]);

  UserProfile? profile;

  @override
  Future<UserProfile?> fetch() async => profile;

  @override
  Future<void> save(UserProfile p) async => profile = p;
}

class FakeMeasurements implements MeasurementRepository {
  FakeMeasurements([List<Measurement>? initial]) : items = [...?initial];

  final List<Measurement> items;

  @override
  Future<List<Measurement>> list() async =>
      [...items]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> save(Measurement m) async {
    items.removeWhere((x) => x.date == m.date);
    items.add(Measurement(
      id: 'id-${m.date.millisecondsSinceEpoch}',
      date: m.date,
      weightKg: m.weightKg,
      neckCm: m.neckCm,
      waistCm: m.waistCm,
      hipCm: m.hipCm,
      reportedFatPct: m.reportedFatPct,
      source: m.source,
    ));
  }

  @override
  Future<void> delete(String id) async => items.removeWhere((x) => x.id == id);
}

class FakeQuestionnaires implements QuestionnaireRepository {
  FakeQuestionnaires([this.saved]);

  Questionnaire? saved;

  @override
  Future<Questionnaire?> fetch() async => saved;

  @override
  Future<void> save(Questionnaire q) async => saved = q;
}

/// Perfil de ejemplo: hombre, 180 cm, nacido en 1986.
final sampleProfile = UserProfile(
  name: 'Alex',
  sex: Sex.male,
  birthDate: DateTime(1986, 3, 1),
  heightCm: 180,
);

/// Mediciones de referencia (informes reales de un nutricionista, usados
/// para verificar que la app calcula igual).
final referenceMeasurements = [
  Measurement(id: 'a', date: DateTime(2021, 8, 2), weightKg: 116.4, neckCm: 46, waistCm: 112, reportedFatPct: 28.79, source: 'Nutri · Dieta 01'),
  Measurement(id: 'b', date: DateTime(2021, 9, 8), weightKg: 114.8, neckCm: 45, waistCm: 109, reportedFatPct: 27.61, source: 'Nutri · Dieta 02'),
  Measurement(id: 'c', date: DateTime(2021, 10, 6), weightKg: 114.6, neckCm: 45, waistCm: 107, reportedFatPct: 26.40, source: 'Nutri · Dieta 02'),
  Measurement(id: 'd', date: DateTime(2021, 12, 17), weightKg: 110.9, neckCm: 44, waistCm: 105, reportedFatPct: 25.78, source: 'Nutri · Dieta 03'),
  Measurement(id: 'e', date: DateTime(2022, 2, 23), weightKg: 110.9, neckCm: 44, waistCm: 102, reportedFatPct: 18.74, source: 'Nutri · Dieta 04'),
];

Widget testApp({
  required AuthRepository auth,
  ProfileRepository? profiles,
  MeasurementRepository? measurements,
  QuestionnaireRepository? questionnaires,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profiles ?? FakeProfiles()),
      measurementRepositoryProvider
          .overrideWithValue(measurements ?? FakeMeasurements()),
      questionnaireRepositoryProvider
          .overrideWithValue(questionnaires ?? FakeQuestionnaires()),
    ],
    child: const MagraApp(),
  );
}
