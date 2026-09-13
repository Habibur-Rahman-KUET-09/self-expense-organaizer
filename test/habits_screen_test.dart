import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/models/enums.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/screens/habits_screen.dart';
import 'package:expense_tracker/widgets/habit_overview_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'add a binary habit, then log it from the Check-in tab (Habit Tracker RS §4.1/§4.2)',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      // Own the ProviderContainer ourselves so it can be disposed inside the
      // test body — see budget_setup_screen_test.dart's identical comment
      // for why (drift's stream-cancellation Timer vs flutter_test teardown).
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HabitsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Starts on Check-in, empty.
      expect(find.textContaining('No habits due today'), findsOneWidget);

      // Switch to Manage and add a habit via the FAB.
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      expect(find.text('No habits yet — tap + to add one.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      // Icon field is TextFormField #0, name is #1 — defaults (binary,
      // daily, starting today) are otherwise fine for this habit.
      await tester.enterText(find.byType(TextFormField).at(1), 'Meditate');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Meditate'), findsOneWidget);

      // Back on Check-in, it shows up as due with an unchecked toggle.
      await tester.tap(find.text('Check-in'));
      await tester.pumpAndSettle();
      expect(find.text('Meditate'), findsOneWidget);
      expect(find.textContaining('0 / 1 habits done today'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

      // Tap to log it done.
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.textContaining('1 / 1 habits done today'), findsOneWidget);
      expect(find.textContaining('🔥 1'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'a quantifiable habit is logged through a numeric prompt and shows its value+unit',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HabitsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(1), 'Water');
      await tester.tap(find.text('Numeric target'));
      await tester.pumpAndSettle();
      // With the type switched, TextFormFields are: icon(0), name(1),
      // target(2), unit(3).
      await tester.enterText(find.byType(TextFormField).at(2), '8');
      await tester.enterText(find.byType(TextFormField).at(3), 'glasses');
      // The extra target/unit fields push Save below the fold in the test
      // viewport — scroll it into view before tapping.
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check-in'));
      await tester.pumpAndSettle();
      expect(find.text('Log'), findsOneWidget);

      await tester.tap(find.text('Log'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '8');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('8 glasses'), findsOneWidget);
      expect(find.textContaining('1 / 1 habits done today'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'the day selector backfills a past day independently of today, and the '
    'weekly overview chart renders (Habit Tracker RS §4.2/§4.3)',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);

      await container.read(habitRepositoryProvider).add(
        HabitsCompanion.insert(
          name: 'Read',
          type: HabitType.binary,
          frequencyType: HabitFrequencyType.daily,
          startDate: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HabitsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // The day selector shows "Today" (the tab itself is labeled
      // "Check-in", so there's no longer a duplicate "Today" on screen).
      expect(find.text('Today'), findsOneWidget);
      expect(find.byType(HabitOverviewChart), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

      // Go back one day and log it there (backfill) — a real date, not "Today".
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsNothing);
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Back to today: today's own log is untouched by the backfill.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
