import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/coach/coach.dart';
import '../../features/menus/weekly_menu.dart';
import '../../features/profile/user_profile.dart';
import '../../features/progress/measurement.dart';
import '../../features/progress/progress_photos.dart';
import '../../features/questionnaire/questionnaire.dart';
import '../../features/today/activity_log.dart';
import '../../features/today/barcode.dart';
import '../../features/today/food_catalog.dart';
import '../../features/today/photo_analysis.dart';
import '../recommendation/progression.dart';
import '../recommendation/weekly_adjustment.dart';
import 'repositories.dart';

/// Se reemplazan en `main` con las implementaciones de Supabase y en las
/// pruebas con implementaciones en memoria.
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => throw UnimplementedError());
final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => throw UnimplementedError());
final measurementRepositoryProvider =
    Provider<MeasurementRepository>((ref) => throw UnimplementedError());
final questionnaireRepositoryProvider =
    Provider<QuestionnaireRepository>((ref) => throw UnimplementedError());
final foodLogRepositoryProvider =
    Provider<FoodLogRepository>((ref) => throw UnimplementedError());
final exerciseLogRepositoryProvider =
    Provider<ExerciseLogRepository>((ref) => throw UnimplementedError());
final fastRepositoryProvider =
    Provider<FastRepository>((ref) => throw UnimplementedError());
final kcalAdjustmentRepositoryProvider =
    Provider<KcalAdjustmentRepository>((ref) => throw UnimplementedError());
final workoutRepositoryProvider =
    Provider<WorkoutRepository>((ref) => throw UnimplementedError());
final progressPhotoRepositoryProvider =
    Provider<ProgressPhotoRepository>((ref) => throw UnimplementedError());
final coachRepositoryProvider =
    Provider<CoachRepository>((ref) => throw UnimplementedError());
final coachClientProvider =
    Provider<CoachClient>((ref) => throw UnimplementedError());
final menuRepositoryProvider =
    Provider<MenuRepository>((ref) => throw UnimplementedError());
final menuGeneratorProvider =
    Provider<MenuGenerator>((ref) => throw UnimplementedError());
final photoAnalyzerProvider =
    Provider<PhotoAnalyzer>((ref) => throw UnimplementedError());
final productLookupProvider =
    Provider<ProductLookup>((ref) => OpenFoodFactsLookup());
final customProductRepositoryProvider =
    Provider<CustomProductRepository>((ref) => throw UnimplementedError());
final barcodeScanProvider = Provider<BarcodeScanFn>((ref) => scanWithCamera);
final imagePickProvider =
    Provider<ImagePickFn>((ref) => pickWithImagePicker);

/// Hora actual (las pruebas la fijan).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final signedInProvider = StreamProvider<bool>(
  (ref) => ref.watch(authRepositoryProvider).signedInChanges(),
);

final profileProvider = FutureProvider<UserProfile?>((ref) async {
  if (ref.watch(signedInProvider).value != true) return null;
  return ref.watch(profileRepositoryProvider).fetch();
});

final measurementsProvider = FutureProvider<List<Measurement>>((ref) async {
  if (ref.watch(signedInProvider).value != true) return const [];
  return ref.watch(measurementRepositoryProvider).list();
});

final questionnaireProvider = FutureProvider<Questionnaire?>((ref) async {
  if (ref.watch(signedInProvider).value != true) return null;
  return ref.watch(questionnaireRepositoryProvider).fetch();
});

/// Lo registrado en un día (la clave es la fecha sin hora).
final foodLogProvider =
    FutureProvider.family<List<FoodEntry>, DateTime>((ref, day) async {
  if (ref.watch(signedInProvider).value != true) return const [];
  return ref.watch(foodLogRepositoryProvider).forDay(day);
});

/// Ejercicio anotado en un día (la clave es la fecha sin hora).
final exerciseLogProvider =
    FutureProvider.family<List<ExerciseEntry>, DateTime>((ref, day) async {
  if (ref.watch(signedInProvider).value != true) return const [];
  return ref.watch(exerciseLogRepositoryProvider).forDay(day);
});

/// El ayuno más reciente del usuario.
final latestFastProvider = FutureProvider<Fast?>((ref) async {
  if (ref.watch(signedInProvider).value != true) return null;
  return ref.watch(fastRepositoryProvider).latest();
});

/// Ajustes semanales de calorías.
final kcalAdjustmentsProvider = FutureProvider<List<KcalAdjustment>>((ref) async {
  if (ref.watch(signedInProvider).value != true) return const [];
  return ref.watch(kcalAdjustmentRepositoryProvider).list();
});

/// Calorías registradas por día en las últimas 3 semanas (para el gasto
/// real).
final recentIntakeProvider = FutureProvider<Map<DateTime, double>>((ref) async {
  if (ref.watch(signedInProvider).value != true) return const {};
  final now = ref.watch(clockProvider)();
  final today = DateTime(now.year, now.month, now.day);
  return ref
      .watch(foodLogRepositoryProvider)
      .dailyKcal(today.subtract(const Duration(days: 21)), today);
});

/// Menú de una semana (la clave es el lunes).
final menuProvider =
    FutureProvider.family<WeeklyMenu?, DateTime>((ref, weekStart) async {
  if (ref.watch(signedInProvider).value != true) return null;
  return ref.watch(menuRepositoryProvider).forWeek(weekStart);
});

/// Últimas sesiones de fuerza (de la más antigua a la más reciente).
final workoutsProvider = FutureProvider<List<WorkoutSession>>((ref) async {
  if (ref.watch(signedInProvider).value != true) return const [];
  return ref.watch(workoutRepositoryProvider).recent();
});

/// Fotos de progreso (de la más reciente a la más antigua).
final progressPhotosProvider = FutureProvider<List<ProgressPhoto>>((ref) async {
  if (ref.watch(signedInProvider).value != true) return const [];
  return ref.watch(progressPhotoRepositoryProvider).list();
});

/// Imagen de una foto (la clave es su ruta en el bucket privado).
final photoBytesProvider =
    FutureProvider.family<Uint8List, ProgressPhoto>((ref, photo) async {
  return ref.watch(progressPhotoRepositoryProvider).bytes(photo);
});

/// Conversación con el coach.
final coachMessagesProvider = FutureProvider<List<CoachMessage>>((ref) async {
  if (ref.watch(signedInProvider).value != true) return const [];
  return ref.watch(coachRepositoryProvider).messages();
});

/// Si aceptó compartir sus datos con el coach.
final coachConsentProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(signedInProvider).value != true) return false;
  return ref.watch(coachRepositoryProvider).hasConsent();
});
