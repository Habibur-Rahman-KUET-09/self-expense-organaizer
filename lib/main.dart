import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/budget_setup_screen.dart';

void main() {
  runApp(const ProviderScope(child: ExpenseTrackerApp()));
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Temporary: Dashboard becomes the real home screen once built
      // (Step 4c) with proper navigation between screens.
      home: const BudgetSetupScreen(),
    );
  }
}
