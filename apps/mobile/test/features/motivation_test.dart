import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/recommendation/motivation.dart';
import 'package:magra/core/recommendation/progression.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/progress/progress_photos.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/today/food_catalog.dart';
import 'package:magra/features/today/motivation_cards.dart';

import '../support/fakes.dart';
import '../support/sections.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);
DateTime ago(int d) => DateTime(today.year, today.month, today.day - d);

void main() {
  group('Rachas', () {
    test('días seguidos; hoy sin registrar no corta la racha', () {
      final ok = {ago(1), ago(2), ago(3), ago(5)};
      expect(currentStreak((d) => ok.contains(d), today), 3);
      expect(currentStreak((d) => {...ok, today}.contains(d), today), 4);
      expect(currentStreak((d) => false, today), 0);
      expect(bestStreak([ago(10), ago(9), ago(8), ago(1), ago(2)]), 3);
      expect(bestStreak(const []), 0);
    });

    test('día registrado y día con proteína', () {
      expect(loggedDay(const DayTotals(899, 50), 1500), isFalse);
      expect(loggedDay(const DayTotals(900, 50), 1500), isTrue);
      expect(loggedDay(null, 1500), isFalse);
      expect(proteinDay(const DayTotals(1800, 117), 130), isTrue);
      expect(proteinDay(const DayTotals(1800, 116), 130), isFalse);
    });

    test('semanas entrenando lo planificado', () {
      final monday = DateTime(2026, 10, 19);
      final wed = DateTime(2026, 10, 21);
      final sessions = [
        DateTime(2026, 10, 5), DateTime(2026, 10, 7), DateTime(2026, 10, 9),
        DateTime(2026, 10, 12), DateTime(2026, 10, 14), DateTime(2026, 10, 16),
        monday,
      ];
      expect(trainingWeekStreak(sessions, 3, wed), 2); // semana actual en curso
      expect(trainingWeekStreak([...sessions, wed, wed], 3, wed), 3);
      expect(trainingWeekStreak(sessions, 0, wed), 0);
    });
  });

  test('semáforo por densidad y proteína', () {
    FoodLight? l(double kcal, double p, double q, [String u = 'g']) =>
        foodLight(kcal: kcal, protein: p, quantity: q, unit: u);
    expect(l(25, 1, 100), FoodLight.green); // verduras
    expect(l(130, 3, 100), FoodLight.green); // arroz cocido: 1,3 kcal/g
    expect(l(250, 9, 100), FoodLight.yellow); // pan
    expect(l(165, 31, 100), FoodLight.green); // pollo: amarillo + proteína
    expect(l(540, 6, 100), FoodLight.red); // papas fritas
    expect(l(380, 32, 100), FoodLight.yellow); // queso: rojo + proteína
    expect(l(42, 0, 100, 'ml'), FoodLight.red); // bebida azucarada
    expect(l(33, 3.4, 100, 'ml'), FoodLight.green); // leche descremada: amarilla + proteína
    expect(l(64, 3.2, 100, 'ml'), FoodLight.red); // leche entera
    expect(l(1, 0, 350, 'ml'), FoodLight.green); // bebida zero
    expect(l(560, 18, 1, 'unidad'), isNull);
    expect(l(100, 0, 0), isNull);
  });

  test('banco: guarda bajo la meta, sin bajar del mínimo, menos lo usado', () {
    final wed = DateTime(2026, 10, 21);
    final history = {
      DateTime(2026, 10, 19): const DayTotals(1700, 120), // 200 bajo → 150
      DateTime(2026, 10, 20): const DayTotals(1850, 120), // 50
      DateTime(2026, 10, 21): const DayTotals(1000, 50), // hoy no cuenta
      DateTime(2026, 10, 18): const DayTotals(1000, 50), // semana pasada
    };
    expect(
        bankAvailable(history: history, targetKcal: 1900, floorKcal: 1500, uses: const {}, today: wed),
        200);
    final under = {DateTime(2026, 10, 19): const DayTotals(1300, 80)}; // bajo el mínimo
    expect(bankAvailable(history: under, targetKcal: 1900, floorKcal: 1500, uses: const {}, today: wed), 0);
    expect(
        bankAvailable(
            history: history,
            targetKcal: 1900,
            floorKcal: 1500,
            uses: {DateTime(2026, 10, 20): 120, DateTime(2026, 10, 21): 300},
            today: wed),
        80);
  });

  test('logros con datos reales', () {
    final list = achievements(
      body: [
        BodyPoint(ago(90), 110, fatKg: 33, waistCm: 112),
        BodyPoint(ago(1), 98.5, fatKg: 26, waistCm: 104),
      ],
      loggedDays: [for (var i = 1; i <= 8; i++) ago(i)],
      proteinDays: [ago(1), ago(2)],
      workouts: 12,
      photoDates: [ago(70), ago(5)],
    );
    Achievement a(String id) => list.firstWhere((x) => x.id == id);
    expect(a('log_7').done, isTrue);
    expect(a('log_30').detail, 'Te faltan 22 días');
    expect(a('protein_7').progress, closeTo(2 / 7, 1e-9));
    expect(a('fat_5').done, isTrue);
    expect(a('weight_5').done, isTrue);
    expect(a('waist_5').done, isTrue);
    expect(a('stage_1').done, isTrue); // 11,5 ≥ 11
    expect(a('workouts_10').done, isTrue);
    expect(a('workouts_50').done, isFalse);
    expect(a('photos_2m').done, isTrue);
    final empty = achievements(body: const [], loggedDays: const [], proteinDays: const [], workouts: 0, photoDates: const []);
    expect(empty.where((x) => x.done), isEmpty);
    expect(empty.any((x) => x.id == 'stage_1'), isFalse);
  });

  Widget app({FakeFoodLog? log, FakeBank? bank, FakeWorkouts? workouts, FakePhotos? photos, List<Measurement>? ms}) =>
      testApp(
        auth: FakeAuth(signedIn: true),
        profiles: FakeProfiles(sampleProfile),
        measurements: FakeMeasurements(ms ??
            [Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100)]),
        questionnaires: FakeQuestionnaires(Questionnaire.initial),
        foodLog: log,
        bank: bank,
        workouts: workouts,
        photos: photos,
      );

  testWidgets('Hoy: rachas, semáforo y usar el banco', (tester) async {
    setSize(tester, const Size(700, 4000));
    final log = FakeFoodLog();
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    // Días anteriores de esta semana con 1.200 kcal bajo una meta mayor.
    for (var d = monday; d.isBefore(today); d = DateTime(d.year, d.month, d.day + 1)) {
      await log.add(FoodEntry(date: d, mealIndex: 0, name: 'Día', kcal: 1600, protein: 200));
    }
    for (var i = 1; i <= 3; i++) {
      final d = ago(i);
      if (d.isBefore(monday)) {
        await log.add(FoodEntry(date: d, mealIndex: 0, name: 'Día', kcal: 1600, protein: 200));
      }
    }
    await log.add(FoodEntry(date: today, mealIndex: 0, name: 'Papas fritas', quantity: 100, kcal: 540, protein: 6));
    final bank = FakeBank();
    await tester.pumpWidget(app(log: log, bank: bank));
    await tester.pumpAndSettle();

    await openSection(tester, 'Rachas');
    await openSection(tester, 'Banco de calorías');
    expect(find.text('4 días registrando'), findsNothing); // hoy lleva 540: no cuenta aún
    expect(find.descendant(of: find.byType(StreaksCard), matching: find.textContaining('días registrando')),
        findsOneWidget);
    expect(find.textContaining('días con tu proteína'), findsOneWidget);
    final red = tester.widget<FoodLightDot>(find.byType(FoodLightDot).first);
    expect(red.light, FoodLight.red);

    final banked = today.weekday == DateTime.monday;
    if (!banked) {
      expect(find.textContaining('Banco de la semana:'), findsOneWidget);
      await tester.tap(find.text('Usar hoy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar'));
      await tester.pumpAndSettle();
      expect(bank.items[today], greaterThanOrEqualTo(50));
      expect(find.textContaining('del banco'), findsWidgets);
      await tester.tap(find.text('Dejar de usar'));
      await tester.pumpAndSettle();
      expect(bank.items, isEmpty);
    }
  });

  testWidgets('Progreso: logros', (tester) async {
    setSize(tester, const Size(700, 6000));
    final workouts = FakeWorkouts([
      for (var i = 0; i < 10; i++)
        WorkoutSession(id: 'w$i', date: ago(i * 2), title: 'Cuerpo completo A', minutes: 40,
            exercises: const [ExerciseLog(name: 'X', sets: [SetLog(10, 20)])]),
    ]);
    final photos = FakePhotos([
      ProgressPhoto(id: 'p', date: ago(3), pose: PhotoPose.front, path: 'u/p.jpg'),
    ]);
    await tester.pumpWidget(app(workouts: workouts, photos: photos, ms: [
      Measurement(id: 'a', date: ago(60), weightKg: 101, neckCm: 40, waistCm: 106),
      Measurement(id: 'b', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
    await tester.pumpAndSettle();
    await openSection(tester, 'Logros');
    expect(find.textContaining('Logros ('), findsOneWidget);
    expect(find.text('10 entrenos'), findsOneWidget);
    expect(find.text('−5 kg en la balanza'), findsOneWidget);
    expect(find.text('Primeras fotos de progreso'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsWidgets);
  });

  testWidgets('teléfono de 360 px sin desbordes', (tester) async {
    setSize(tester, const Size(360, 6000));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openSection(tester, 'Rachas');
    expect(find.byType(StreaksCard), findsOneWidget);
    await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
    await tester.pumpAndSettle();
    await openSection(tester, 'Logros');
    expect(find.textContaining('Logros ('), findsOneWidget);
  });
}
