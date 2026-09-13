import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_shell.dart';

void main() {
  runApp(const ProviderScope(child: PersonalOrganiserApp()));
}

/// The app covers two Phase 1 modules — expense tracking and habit
/// tracking — under one "personal organization" umbrella (see
/// HomeShell's own doc comment).
class PersonalOrganiserApp extends StatelessWidget {
  const PersonalOrganiserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Organiser',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}
