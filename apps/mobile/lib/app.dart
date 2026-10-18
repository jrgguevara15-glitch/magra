import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/providers.dart';
import 'core/theme.dart';
import 'features/auth/auth_page.dart';
import 'features/shell/home_shell.dart';

class MagraApp extends StatelessWidget {
  const MagraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAGRA',
      debugShowCheckedModeBanner: false,
      theme: MagraTheme.light(),
      darkTheme: MagraTheme.dark(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}

/// Muestra el inicio de sesión o la app según haya sesión.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider);
    return signedIn.when(
      data: (yes) => yes ? const HomeShell() : const AuthPage(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => const AuthPage(),
    );
  }
}
