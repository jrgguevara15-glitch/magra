import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/data/providers.dart';
import 'core/data/repositories.dart';

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
      ],
      child: const MagraApp(),
    ),
  );
}
