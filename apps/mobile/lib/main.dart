import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/data/providers.dart';
import 'core/data/repositories.dart';
import 'features/menus/weekly_menu.dart';
import 'features/today/photo_analysis.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: MagraConfig.supabaseUrl,
    publishableKey: MagraConfig.supabasePublishableKey,
  );
  final client = Supabase.instance.client;
  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(SupabaseAuthRepository(client)),
        profileRepositoryProvider
            .overrideWithValue(SupabaseProfileRepository(client)),
        measurementRepositoryProvider
            .overrideWithValue(SupabaseMeasurementRepository(client)),
        questionnaireRepositoryProvider
            .overrideWithValue(SupabaseQuestionnaireRepository(client)),
        foodLogRepositoryProvider
            .overrideWithValue(SupabaseFoodLogRepository(client)),
        exerciseLogRepositoryProvider
            .overrideWithValue(SupabaseExerciseLogRepository(client)),
        fastRepositoryProvider.overrideWithValue(SupabaseFastRepository(client)),
        kcalAdjustmentRepositoryProvider
            .overrideWithValue(SupabaseKcalAdjustmentRepository(client)),
        customProductRepositoryProvider
            .overrideWithValue(SupabaseCustomProductRepository(client)),
        menuRepositoryProvider.overrideWithValue(SupabaseMenuRepository(client)),
        menuGeneratorProvider.overrideWithValue(SupabaseMenuGenerator(client)),
        photoAnalyzerProvider.overrideWithValue(SupabasePhotoAnalyzer(client)),
      ],
      child: const MagraApp(),
    ),
  );
}
