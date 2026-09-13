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

  /// Required — the committed budget floor for this category/month.
  RealColumn get minCost => real().withDefault(const Constant(0))();

  /// Optional soft ceiling. When unset, [minCost] doubles as the ceiling
  /// everywhere a single "budget" figure is needed (see
  /// `effectiveCeiling` in lib/logic/threshold_checker.dart).
  RealColumn get maxCost => real().nullable()();

  /// Threshold percentage, e.g. 80 for 80%. See FR-4.1.
  RealColumn get thresholdPercent =>
      real().withDefault(const Constant(90))();

  /// Whether [thresholdPercent] is applied against minCost or maxCost
  /// (falls back to minCost if maxCost isn't set).
  TextColumn get thresholdBase => textEnum<ThresholdBase>()
      .withDefault(Constant(ThresholdBase.max.name))();

  /// When true, this category is excluded from the Active Alerts banner
  /// and the Alert log, but its spend is still tracked/calculated
  /// normally everywhere else (dashboard totals, progress, strikethrough).
  BoolColumn get noAlert => boolean().withDefault(const Constant(false))();

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

/// Habit categories — kept as their own table rather than reusing the
/// expense tracker's [Categories] (product decision: the two are tracked
/// independently). Habit Tracker RS §2 "Reusability"/§8 open question #1.
class HabitCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF6750A4))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// A user-defined recurring activity to track. Habit Tracker RS §3/§4.1/§6.
class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// A single emoji/short glyph shown as the habit's icon, or null.
  TextColumn get icon => text().nullable()();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF6750A4))();
  IntColumn get categoryId =>
      integer().nullable().references(HabitCategories, #id)();

  TextColumn get type => textEnum<HabitType>()();

  TextColumn get frequencyType => textEnum<HabitFrequencyType>()();

  /// JSON-encoded config whose shape depends on [frequencyType] — see
  /// FrequencySchedule (lib/logic/frequency_schedule.dart) for the shapes
  /// and how each is interpreted. Kept as JSON rather than rigid columns so
  /// new frequency patterns can be added later without a schema change
  /// (Habit Tracker RS §5 "dynamicity").
  TextColumn get frequencyConfig =>
      text().withDefault(const Constant('{}'))();

  /// Quantifiable habits' daily target (e.g. 8 glasses, 30 minutes). Null
  /// for binary habits, or a quantifiable habit tracked without a fixed goal.
  RealColumn get targetValue => real().nullable()();
  TextColumn get unit => text().nullable()();

  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();

  /// Archive instead of delete, so historical logs stay intact — same
  /// pattern as Categories.isActive.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// User-controlled ordering/pinning on the Today view (Habit Tracker RS
  /// §4.1).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// A single day's record that a habit was done (binary) or its measured
/// value (quantifiable). Habit Tracker RS §3/§4.2/§6.
class HabitLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId => integer().references(Habits, #id)();

  /// Calendar day this log is for, normalized to midnight — a habit has at
  /// most one log per day (see [uniqueKeys]); logging again for the same
  /// day replaces it rather than adding a second entry.
  DateTimeColumn get logDate => dateTime()();

  /// Null for binary habits (the row's mere presence means "done"). For
  /// quantifiable habits, the measured amount logged for that day.
  RealColumn get value => real().nullable()();
  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, logDate},
      ];
}
