import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'database_providers.dart';

/// All habits (Habit Tracker RS §4.1), reactive to adds/edits/archives.
final habitsProvider = StreamProvider.autoDispose.family<List<Habit>, bool>((
  ref,
  activeOnly,
) {
  return ref.watch(habitRepositoryProvider).watchAll(activeOnly: activeOnly);
});
