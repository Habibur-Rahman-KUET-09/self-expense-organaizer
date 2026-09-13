import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'database_providers.dart';

/// Every habit log — a pure reactive trigger (see
/// HabitLogRepository.watchAll's doc comment) for the streak/completion
/// providers in habit_progress_providers.dart.
final allHabitLogsProvider = StreamProvider.autoDispose<List<HabitLog>>((ref) {
  return ref.watch(habitLogRepositoryProvider).watchAll();
});
