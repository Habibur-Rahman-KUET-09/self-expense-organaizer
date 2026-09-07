/// Which side of the budget (min or max) a threshold percentage is measured
/// against. See RS doc FR-4.2.
enum ThresholdBase { min, max }

/// Severity of a threshold alert. See RS doc FR-4.5.
enum AlertType { approaching, reached, exceeded }

/// Comparison granularity for the Reports screen. See RS doc FR-6.1.
enum ReportPeriod { week, month, quarter, year }
