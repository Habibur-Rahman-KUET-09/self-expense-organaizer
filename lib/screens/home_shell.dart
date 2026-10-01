import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_providers.dart';
import '../providers/navigation_providers.dart';
import 'add_expense_screen.dart';
import 'budget_setup_screen.dart';
import 'dashboard_screen.dart';
import 'habits_screen.dart';
import 'reports_screen.dart';

/// App-wide bottom navigation between the expense tracker's four Phase 1
/// screens (FR-8.2's "quick links" jump tabs via [bottomNavIndexProvider])
/// plus the Habit Tracker module's own tab (Habit Tracker RS §5 "modular
/// UI" — it's a sibling screen, not entangled with the expense code).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {

  static const _screens = <Widget>[
    DashboardScreen(),
    AddExpenseScreen(),
    BudgetSetupScreen(),
    ReportsScreen(),
    HabitsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startMonthBudgets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The app may stay open across the turn of a month.
    if (state == AppLifecycleState.resumed) _startMonthBudgets();
  }

  /// When a new month begins with no budgets, it starts from last month's.
  Future<void> _startMonthBudgets() async {
    final now = DateTime.now();
    try {
      await ref.read(budgetRepositoryProvider).copyFromPreviousIfEmpty(now.year, now.month);
    } catch (e) {
      debugPrint('Could not copy last month\'s budgets: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(bottomNavIndexProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Habits',
          ),
        ],
      ),
    );
  }
}
