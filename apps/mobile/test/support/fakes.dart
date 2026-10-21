import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magra/app.dart';
import 'package:magra/core/data/providers.dart';
import 'package:magra/core/data/repositories.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/core/recommendation/motivation.dart';
import 'package:magra/core/recommendation/progression.dart';
import 'package:magra/core/recommendation/weekly_adjustment.dart';
import 'package:magra/features/coach/coach.dart';
import 'package:magra/features/menus/weekly_menu.dart';
import 'package:magra/features/profile/user_profile.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/progress/progress_photos.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/today/activity_log.dart';
import 'package:magra/features/training/mannequin.dart';
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

class FakeSwaps implements ExerciseSwapRepository {
  FakeSwaps([Map<String, String>? initial]) : items = {...?initial};
  final Map<String, String> items;

  @override
  Future<Map<String, String>> all() async => {...items};

  @override
  Future<void> set(String original, String chosen) async => items[original] = chosen;

  @override
  Future<void> clear(String original) async => items.remove(original);
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
  Future<List<FoodEntry>> recent({int limit = 400}) async => items.reversed.take(limit).toList();

  @override
  Future<void> update(FoodEntry e) async {
    final i = items.indexWhere((x) => x.id == e.id);
    if (i >= 0) items[i] = e;
  }

  @override
  Future<Map<DateTime, DayTotals>> dailyTotals(DateTime from, DateTime to) async {
    final out = <DateTime, DayTotals>{};
    for (final e in items) {
      final d = DateUtils.dateOnly(e.date);
      if (d.isBefore(DateUtils.dateOnly(from)) || d.isAfter(DateUtils.dateOnly(to))) {
        continue;
      }
      final prev = out[d];
      out[d] = DayTotals((prev?.kcal ?? 0) + e.kcal, (prev?.protein ?? 0) + e.protein);
    }
    return out;
  }

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

class FakeBank implements CalorieBankRepository {
  final Map<DateTime, int> items = {};

  @override
  Future<Map<DateTime, int>> uses(DateTime from, DateTime to) async => {
        for (final e in items.entries)
          if (!e.key.isBefore(from) && !e.key.isAfter(to)) e.key: e.value,
      };

  @override
  Future<void> use(DateTime day, int kcal) async =>
      kcal <= 0 ? items.remove(day) : items[day] = kcal;
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

class FakeCustomProducts implements CustomProductRepository {
  final Map<String, Product> items = {};

  @override
  Future<Product?> find(String code) async => items[code];

  @override
  Future<void> save(Product p) async => items[p.code] = p;
}

class FakeWorkouts implements WorkoutRepository {
  FakeWorkouts([List<WorkoutSession>? initial]) : items = [...?initial];

  final List<WorkoutSession> items;
  var _next = 0;

  @override
  Future<List<WorkoutSession>> recent({int limit = 60}) async => [...items];

  @override
  Future<void> add(WorkoutSession s) async => items.add(WorkoutSession(
      id: 'w${_next++}', date: s.date, title: s.title, minutes: s.minutes,
      exercises: s.exercises));

  @override
  Future<void> delete(String id) async => items.removeWhere((s) => s.id == id);
}

class FakePhotos implements ProgressPhotoRepository {
  FakePhotos([List<ProgressPhoto>? initial]) : items = [...?initial];

  final List<ProgressPhoto> items;
  final List<String> mediaTypes = [];
  var _next = 0;
  bool fail = false;

  @override
  Future<List<ProgressPhoto>> list() async =>
      [...items]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<void> upload({
    required DateTime date,
    required PhotoPose pose,
    required Uint8List bytes,
    required String mediaType,
  }) async {
    if (fail) throw Exception('sin red');
    mediaTypes.add(mediaType);
    items.add(ProgressPhoto(
        id: 'p$_next', date: date, pose: pose, path: 'u/${_next++}.jpg'));
  }

  @override
  Future<Uint8List> bytes(ProgressPhoto photo) async => tinyPng;

  @override
  Future<void> delete(ProgressPhoto photo) async =>
      items.removeWhere((p) => p.path == photo.path);
}

class FakeCoach implements CoachRepository, CoachClient {
  FakeCoach({this.consent = false});

  bool consent;
  final List<CoachMessage> items = [];
  CoachException? error;
  String reply = 'Cena pollo con verduras.';
  String? lastMode;
  List<CoachMessage>? lastHistory;
  Map<String, dynamic>? lastContext;
  int asks = 0;

  @override
  Future<List<CoachMessage>> messages() async => [...items];

  @override
  Future<void> add(CoachMessage m) async => items.add(CoachMessage(
      id: 'c${items.length}', role: m.role, kind: m.kind, content: m.content,
      createdAt: DateTime.now()));

  @override
  Future<void> clear() async => items.clear();

  @override
  Future<bool> hasConsent() async => consent;

  @override
  Future<void> setConsent(bool accepted) async => consent = accepted;

  @override
  Future<String> ask({
    required String mode,
    required List<CoachMessage> history,
    required Map<String, dynamic> context,
  }) async {
    asks++;
    lastMode = mode;
    lastHistory = history;
    lastContext = context;
    if (error != null) throw error!;
    return reply;
  }
}

class FakeMenus implements MenuRepository {
  final Map<DateTime, WeeklyMenu> items = {};
  int saves = 0;
  Object? saveError;

  @override
  Future<WeeklyMenu?> forWeek(DateTime weekStart) async => items[weekStart];

  @override
  Future<void> save(WeeklyMenu menu) async {
    saves++;
    if (saveError != null) throw saveError!;
    items[menu.weekStart] = menu;
  }
}

/// Arma platos simples que suman lo que pide cada slot.
class FakeMenuGenerator implements MenuGenerator {
  MenuException? error;
  List<MenuSlot>? lastSlots;
  Map<String, dynamic>? lastPrefs;
  List<String>? lastAvoid;
  int weeks = 0;
  int swaps = 0;

  static MenuMeal mealFor(MenuSlot s, String name) => MenuMeal(
        name: name,
        prep: 'Preparación simple.',
        items: [
          MenuItem(food: 'Pechuga de pollo', quantity: 120, unit: 'g', kcal: s.kcal * 0.5,
              protein: s.protein, category: 'Carnes, pollo y pescados'),
          MenuItem(food: 'Arroz', quantity: 60, unit: 'g', kcal: s.kcal * 0.4,
              carbs: s.carbs, category: 'Abarrotes', brand: 'Tucapel'),
          MenuItem(food: 'Palta', quantity: 0.5, unit: 'unidad', kcal: s.kcal * 0.1,
              fat: s.fat, category: 'Verduras y frutas'),
        ],
        seasoning: const [
          Seasoning(item: 'Aceite de oliva extra virgen', amount: '1 cdta (5 ml)', tip: 'En crudo'),
          Seasoning(item: 'Merkén', amount: 'a gusto'),
        ],
      );

  @override
  Future<List<List<MenuMeal>>> week({
    required List<MenuSlot> slots,
    required Map<String, dynamic> prefs,
  }) async {
    weeks++;
    lastSlots = slots;
    lastPrefs = prefs;
    if (error != null) throw error!;
    return [
      for (var d = 0; d < 7; d++)
        [for (var i = 0; i < slots.length; i++) mealFor(slots[i], 'Plato $d-$i')],
    ];
  }

  @override
  Future<MenuMeal> meal({
    required List<MenuSlot> slots,
    required Map<String, dynamic> prefs,
    required int day,
    required int meal,
    required List<String> avoid,
  }) async {
    swaps++;
    lastAvoid = avoid;
    if (error != null) throw error!;
    return mealFor(slots[meal], 'Nuevo plato $day-$meal');
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
  CustomProductRepository? customProducts,
  BarcodeScanFn? scan,
  MenuRepository? menus,
  MenuGenerator? menuGenerator,
  WorkoutRepository? workouts,
  ProgressPhotoRepository? photos,
  FakeCoach? coach,
  FakeBank? bank,
  FakeSwaps? swaps,
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
      menuRepositoryProvider.overrideWithValue(menus ?? FakeMenus()),
      workoutRepositoryProvider.overrideWithValue(workouts ?? FakeWorkouts()),
      progressPhotoRepositoryProvider.overrideWithValue(photos ?? FakePhotos()),
      coachRepositoryProvider.overrideWithValue(coach ?? FakeCoach()),
      calorieBankRepositoryProvider.overrideWithValue(bank ?? FakeBank()),
      exerciseSwapRepositoryProvider.overrideWithValue(swaps ?? FakeSwaps()),
      coachClientProvider.overrideWithValue(coach ?? FakeCoach()),
      menuGeneratorProvider.overrideWithValue(menuGenerator ?? FakeMenuGenerator()),
      productLookupProvider.overrideWithValue(products ?? FakeProductLookup()),
      customProductRepositoryProvider
          .overrideWithValue(customProducts ?? FakeCustomProducts()),
      barcodeScanProvider.overrideWithValue(scan ?? (context) async => null),
      exerciseLogRepositoryProvider
          .overrideWithValue(exerciseLog ?? FakeExerciseLog()),
      fastRepositoryProvider.overrideWithValue(fasts ?? FakeFasts()),
      kcalAdjustmentRepositoryProvider
          .overrideWithValue(adjustments ?? FakeKcalAdjustments()),
      if (clock != null) clockProvider.overrideWithValue(clock),
      figureAnimationProvider.overrideWithValue(false),
    ],
    child: const MagraApp(),
  );
}
