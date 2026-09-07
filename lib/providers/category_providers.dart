import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'database_providers.dart';

/// Top-level categories (FR-1.1), reactive to adds/edits/archives.
/// [activeOnly] = false also includes archived ones (FR-1.4), so the UI can
/// offer a way back to un-archive them.
final topLevelCategoriesProvider = StreamProvider.autoDispose
    .family<List<Category>, bool>((ref, activeOnly) {
      return ref
          .watch(categoryRepositoryProvider)
          .watchTopLevel(activeOnly: activeOnly);
    });

typedef SubCategoryKey = ({int parentId, bool activeOnly});

/// Sub-categories under a given parent (FR-1.2).
final subCategoriesProvider = StreamProvider.autoDispose
    .family<List<Category>, SubCategoryKey>((ref, key) {
      return ref
          .watch(categoryRepositoryProvider)
          .watchSubCategories(key.parentId, activeOnly: key.activeOnly);
    });

/// All categories regardless of level/status, for lookups like "resolve a
/// category name from an expense's categoryId" without re-querying.
final allCategoriesProvider = StreamProvider.autoDispose<List<Category>>((
  ref,
) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});
