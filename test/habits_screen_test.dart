import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/screens/habits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'add a binary habit, then log it from the Today tab (Habit Tracker RS §4.1/§4.2)',
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

      // Starts on "Today", empty.
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

      // Back on Today, it shows up as due with an unchecked toggle.
      await tester.tap(find.text('Today'));
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

      await tester.tap(find.text('Today'));
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
}
