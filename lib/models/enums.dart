/// Which side of the budget (min or max) a threshold percentage is measured
/// against. See RS doc FR-4.2.
enum ThresholdBase { min, max }

/// Severity of a threshold alert. See RS doc FR-4.5.
enum AlertType { approaching, reached, exceeded }

/// Comparison granularity for the Reports screen. See RS doc FR-6.1.
enum ReportPeriod { week, month, quarter, year }

/// Whether a habit is a one-tap done/not-done check, or tracks a numeric
/// amount (e.g. glasses of water, minutes exercised). Habit Tracker RS §3/§4.1.
enum HabitType { binary, quantifiable }

/// How often a habit is expected. Habit Tracker RS §3/§4.1. The matching
/// `frequencyConfig` JSON shape for each value is documented on
/// `FrequencySchedule` (lib/logic/frequency_schedule.dart).
enum HabitFrequencyType { daily, daysOfWeek, timesPerWeek, timesPerMonth, customInterval }
