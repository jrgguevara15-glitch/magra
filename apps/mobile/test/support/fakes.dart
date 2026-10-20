import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magra/app.dart';
import 'package:magra/core/data/providers.dart';
import 'package:magra/core/data/repositories.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/core/recommendation/weekly_adjustment.dart';
import 'package:magra/features/profile/user_profile.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/today/activity_log.dart';
import 'package:magra/features/today/barcode.dart';
import 'package:magra/features/today/food_catalog.dart';
import 'package:magra/features/today/photo_analysis.dart';

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

class FakeFoodLog implements FoodLogRepository {
  final List<FoodEntry> items = [];
  var _next = 0;

  @override
  Future<List<FoodEntry>> forDay(DateTime day) async =>
      [for (final e in items) if (DateUtils.isSameDay(e.date, day)) e];

  @override
  Future<void> add(FoodEntry e) async => items.add(FoodEntry(
        id: 'f${_next++}',
        date: e.date,
        mealIndex: e.mealIndex,
        name: e.name,
        quantity: e.quantity,
        unit: e.unit,
        kcal: e.kcal,
        protein: e.protein,
        carbs: e.carbs,
        fat: e.fat,
        source: e.source,
      ));

  @override
  Future<void> delete(String id) async => items.removeWhere((e) => e.id == id);

  @override
  Future<Map<DateTime, double>> dailyKcal(DateTime from, DateTime to) async {
    final out = <DateTime, double>{};
    for (final e in items) {
      final d = DateUtils.dateOnly(e.date);
      if (d.isBefore(DateUtils.dateOnly(from)) || d.isAfter(DateUtils.dateOnly(to))) {
        continue;
      }
      out[d] = (out[d] ?? 0) + e.kcal;
    }
    return out;
  }
}

class FakeKcalAdjustments implements KcalAdjustmentRepository {
  FakeKcalAdjustments([List<KcalAdjustment>? initial]) : items = [...?initial];

  final List<KcalAdjustment> items;

  @override
  Future<List<KcalAdjustment>> list() async =>
      [...items]..sort((a, b) => a.weekStart.compareTo(b.weekStart));

  @override
  Future<void> save(KcalAdjustment a) async {
    items.removeWhere((x) => x.weekStart == a.weekStart);
    items.add(a);
  }
}

class FakeExerciseLog implements ExerciseLogRepository {
  final List<ExerciseEntry> items = [];
  var _next = 0;

  @override
  Future<List<ExerciseEntry>> forDay(DateTime day) async =>
      [for (final e in items) if (DateUtils.isSameDay(e.date, day)) e];

  @override
  Future<void> add(ExerciseEntry e) async => items.add(ExerciseEntry(
        id: 'x${_next++}',
        date: e.date,
        activityId: e.activityId,
        name: e.name,
        met: e.met,
        minutes: e.minutes,
        kcalNet: e.kcalNet,
      ));

  @override
  Future<void> delete(String id) async => items.removeWhere((e) => e.id == id);
}

class FakeFasts implements FastRepository {
  final List<Fast> items = [];
  var _next = 0;

  @override
  Future<Fast?> latest() async => items.isEmpty
      ? null
      : (items.toList()..sort((a, b) => b.start.compareTo(a.start))).first;

  @override
  Future<void> start(DateTime at, int targetHours) async {
    if (items.any((f) => f.active)) throw StateError('ya hay un ayuno en curso');
    items.add(Fast(id: 'a${_next++}', start: at, targetHours: targetHours));
  }

  @override
  Future<void> end(String id, DateTime at) async {
    final i = items.indexWhere((f) => f.id == id);
    final f = items[i];
    items[i] = Fast(id: f.id, start: f.start, end: at, targetHours: f.targetHours);
  }

  @override
  Future<void> delete(String id) async => items.removeWhere((f) => f.id == id);
}

class FakePhotoAnalyzer implements PhotoAnalyzer {
  FakePhotoAnalyzer({this.result, this.error});

  PhotoAnalysis? result;
  PhotoException? error;
  PhotoMode? lastMode;
  String? lastNote;
  String? lastMediaType;
  double? lastRemaining;
  int calls = 0;

  @override
  Future<PhotoAnalysis> analyze({
    required Uint8List bytes,
    required String mediaType,
    required PhotoMode mode,
    String? note,
    double? remainingKcal,
  }) async {
    calls++;
    lastMode = mode;
    lastNote = note;
    lastMediaType = mediaType;
    lastRemaining = remainingKcal;
    if (error != null) throw error!;
    return result!;
  }

  String? lastText;

  @override
  Future<PhotoAnalysis> describe({required String text, double? remainingKcal}) async {
    calls++;
    lastText = text;
    lastRemaining = remainingKcal;
    if (error != null) throw error!;
    return result!;
  }
}

class FakeProductLookup implements ProductLookup {
  FakeProductLookup([this.products = const {}]);

  final Map<String, Product> products;
  ProductLookupException? error;
  final List<String> asked = [];

  @override
  Future<Product?> find(String code) async {
    asked.add(code);
    if (error != null) throw error!;
    return products[code];
  }
}

/// PNG de 1×1 px para simular una foto.
final tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<PickedImage?> fakePick({required bool camera}) async =>
    (bytes: tinyPng, name: camera ? 'camara.jpg' : 'plato.png', mimeType: null);

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
  FoodLogRepository? foodLog,
  PhotoAnalyzer? photoAnalyzer,
  ImagePickFn? pick,
  ExerciseLogRepository? exerciseLog,
  FastRepository? fasts,
  KcalAdjustmentRepository? adjustments,
  ProductLookup? products,
  BarcodeScanFn? scan,
  DateTime Function()? clock,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profiles ?? FakeProfiles()),
      measurementRepositoryProvider
          .overrideWithValue(measurements ?? FakeMeasurements()),
      questionnaireRepositoryProvider
          .overrideWithValue(questionnaires ?? FakeQuestionnaires()),
      foodLogRepositoryProvider.overrideWithValue(foodLog ?? FakeFoodLog()),
      photoAnalyzerProvider.overrideWithValue(photoAnalyzer ?? FakePhotoAnalyzer()),
      imagePickProvider.overrideWithValue(pick ?? fakePick),
      productLookupProvider.overrideWithValue(products ?? FakeProductLookup()),
      barcodeScanProvider.overrideWithValue(scan ?? (context) async => null),
      exerciseLogRepositoryProvider
          .overrideWithValue(exerciseLog ?? FakeExerciseLog()),
      fastRepositoryProvider.overrideWithValue(fasts ?? FakeFasts()),
      kcalAdjustmentRepositoryProvider
          .overrideWithValue(adjustments ?? FakeKcalAdjustments()),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
    child: const MagraApp(),
  );
}
