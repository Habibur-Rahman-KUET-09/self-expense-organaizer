import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/alert_service.dart';
import 'database_providers.dart';

final alertServiceProvider = Provider<AlertService>((ref) {
  return AlertService(
    ref.watch(budgetRepositoryProvider),
    ref.watch(expenseRepositoryProvider),
    ref.watch(alertRepositoryProvider),
  );
});
