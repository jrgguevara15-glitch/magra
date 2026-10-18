import 'package:flutter/material.dart';

import 'core/theme.dart';
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
      home: const HomeShell(),
    );
  }
}
