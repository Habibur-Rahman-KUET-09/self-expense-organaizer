import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'database_providers.dart';

final habitCategoriesProvider = StreamProvider.autoDispose
    .family<List<HabitCategory>, bool>((ref, activeOnly) {
      return ref.watch(habitCategoryRepositoryProvider).watchAll(activeOnly: activeOnly);
    });
