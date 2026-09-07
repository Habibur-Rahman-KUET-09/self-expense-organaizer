import 'package:drift/drift.dart';

import '../models/enums.dart';

/// Categories and sub-categories (self-referencing via [parentId]).
/// Matches RS doc Section 6 "Category" + FR-1.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Null for a top-level category; set for a sub-category.
  IntColumn get parentId =>
      integer().nullable().references(Categories, #id)();

  /// FR-1.4: archive instead of delete so historical data stays intact.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// ARGB color used for chips/progress bars/charts in the UI.
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF6750A4))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Per-category, per-month min/max budget with its own threshold settings.
/// Matches RS doc Section 6 "Budget" + FR-2, FR-4.
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().references(Categories, #id)();

  IntColumn get year => integer()();

  /// 1-12
  IntColumn get month => integer()();

  RealColumn get minCost => real().withDefault(const Constant(0))();
  RealColumn get maxCost => real()();

  /// Threshold percentage, e.g. 80 for 80%. See FR-4.1.
  RealColumn get thresholdPercent =>
      real().withDefault(const Constant(90))();

  /// Whether [thresholdPercent] is applied against minCost or maxCost.
  TextColumn get thresholdBase => textEnum<ThresholdBase>()
      .withDefault(Constant(ThresholdBase.max.name))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {categoryId, year, month},
      ];
}

/// A single logged expense. Matches RS doc Section 6 "Expense" + FR-5.
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().references(Categories, #id)();

  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Historical log of threshold alerts that have fired, so the dashboard can
/// show "already notified" state instead of re-alerting every time it's
/// opened. Matches RS doc Section 6 "Alert" + FR-4.3/FR-4.5.
class Alerts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().references(Categories, #id)();

  DateTimeColumn get dateTriggered => dateTime()();
  TextColumn get type => textEnum<AlertType>()();

  /// Cumulative actual spend at the moment this alert was triggered.
  RealColumn get valueAtTrigger => real()();
}
