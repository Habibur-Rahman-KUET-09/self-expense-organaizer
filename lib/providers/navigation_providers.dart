import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which bottom-nav tab is selected in [HomeShell]. A shared provider
/// (rather than local widget state) so any screen's "quick link" buttons
/// (FR-8.2) can jump to another tab without needing a reference to the
/// shell's own State.
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);
