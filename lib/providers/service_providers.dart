import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/alert_service.dart';
import '../services/backup_service.dart';
import '../services/budget_rollup_service.dart';
import 'database_providers.dart';

final alertServiceProvider = Provider<AlertService>((ref) {
  return AlertService(
    ref.watch(budgetRepositoryProvider),
    ref.watch(expenseRepositoryProvider),
    ref.watch(alertRepositoryProvider),
  );
});

final budgetRollupServiceProvider = Provider<BudgetRollupService>((ref) {
  return BudgetRollupService(
    ref.watch(categoryRepositoryProvider),
    ref.watch(budgetRepositoryProvider),
    ref.watch(expenseRepositoryProvider),
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(appDatabaseProvider));
});
