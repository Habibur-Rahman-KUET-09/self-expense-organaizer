import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/models/enums.dart';
import 'package:expense_tracker/repositories/habit_category_repository.dart';
import 'package:expense_tracker/repositories/habit_log_repository.dart';
import 'package:expense_tracker/repositories/habit_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late HabitCategoryRepository categoryRepo;
  late HabitRepository habitRepo;
  late HabitLogRepository logRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    categoryRepo = HabitCategoryRepository(db);
    habitRepo = HabitRepository(db);
    logRepo = HabitLogRepository(db);
  });

  tearDown(() => db.close());

  Future<int> addBinaryDailyHabit({String name = 'Read'}) {
    return habitRepo.add(
      HabitsCompanion.insert(
        name: name,
        type: HabitType.binary,
        frequencyType: HabitFrequencyType.daily,
        startDate: DateTime(2026, 9, 1),
      ),
    );
  }

  test('habit category CRUD (Habit Tracker RS §8 open question #1: kept separate)', () async {
    final id = await categoryRepo.add(name: 'Wellness', colorValue: 0xFF43A047);
    final all = await categoryRepo.watchAll().first;
    expect(all.map((c) => c.name), ['Wellness']);

    await categoryRepo.setActive(id, false);
    expect(await categoryRepo.watchAll().first, isEmpty);
    expect(await categoryRepo.watchAll(activeOnly: false).first, hasLength(1));
  });

  test('deleting a habit category with habits attached is rejected', () async {
    final categoryId = await categoryRepo.add(name: 'Wellness');
    await habitRepo.add(
      HabitsCompanion.insert(
        name: 'Meditate',
        categoryId: Value(categoryId),
        type: HabitType.binary,
        frequencyType: HabitFrequencyType.daily,
        startDate: DateTime(2026, 9, 1),
      ),
    );
    expect(() => categoryRepo.delete(categoryId), throwsStateError);
  });

  test('habit CRUD and archive (RS §4.1)', () async {
    final id = await addBinaryDailyHabit();
    final all = await habitRepo.watchAll().first;
    expect(all.map((h) => h.name), ['Read']);

    await habitRepo.setActive(id, false);
    expect(await habitRepo.watchAll().first, isEmpty);
    expect(await habitRepo.watchAll(activeOnly: false).first, hasLength(1));
  });

  test('deleting a habit with logged history is rejected; archiving is not', () async {
    final id = await addBinaryDailyHabit();
    await logRepo.logDay(habitId: id, date: DateTime(2026, 9, 1));
    expect(() => habitRepo.delete(id), throwsStateError);
    await habitRepo.setActive(id, false); // archiving still works
    expect((await habitRepo.getById(id))!.isActive, isFalse);
  });

  test('reorder persists sortOrder for exactly the given habits (RS §4.1 pinning)', () async {
    final aId = await addBinaryDailyHabit(name: 'A');
    final bId = await addBinaryDailyHabit(name: 'B');
    final cId = await addBinaryDailyHabit(name: 'C');

    await habitRepo.reorder([cId, aId, bId]);
    final ordered = await habitRepo.getAll();
    expect(ordered.map((h) => h.name), ['C', 'A', 'B']);
  });

  test('logDay upserts — logging twice for the same day replaces, not duplicates (RS §4.2)', () async {
    final id = await addBinaryDailyHabit();
    await logRepo.logDay(habitId: id, date: DateTime(2026, 9, 5), value: 3, note: 'first');
    await logRepo.logDay(habitId: id, date: DateTime(2026, 9, 5), value: 5, note: 'second');

    final logs = await logRepo.getForHabitInRange(
      id,
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 30),
    );
    expect(logs, hasLength(1));
    expect(logs.single.value, 5);
    expect(logs.single.note, 'second');
  });

  test('deleteForDay removes only that day\'s log', () async {
    final id = await addBinaryDailyHabit();
    await logRepo.logDay(habitId: id, date: DateTime(2026, 9, 1));
    await logRepo.logDay(habitId: id, date: DateTime(2026, 9, 2));

    await logRepo.deleteForDay(id, DateTime(2026, 9, 1));

    final logs = await logRepo.getForHabitInRange(
      id,
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 30),
    );
    expect(logs, hasLength(1));
    expect(logs.single.logDate, DateTime(2026, 9, 2));
  });

  test('watchAllForDate scopes to a single calendar day across habits', () async {
    final aId = await addBinaryDailyHabit(name: 'A');
    final bId = await addBinaryDailyHabit(name: 'B');
    await logRepo.logDay(habitId: aId, date: DateTime(2026, 9, 1));
    await logRepo.logDay(habitId: bId, date: DateTime(2026, 9, 1));
    await logRepo.logDay(habitId: aId, date: DateTime(2026, 9, 2)); // different day

    final todayLogs = await logRepo.watchAllForDate(DateTime(2026, 9, 1)).first;
    expect(todayLogs, hasLength(2));
  });
}
