import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/habit_progress.dart';
import '../providers/database_providers.dart';

/// A single habit's row on the Today screen (Habit Tracker RS §4.2): one
/// tap logs a binary habit, or opens a numeric prompt for a quantifiable
/// one. Tapping the rest of the row opens [onTap] (the detail screen).
class HabitTile extends ConsumerWidget {
  const HabitTile({super.key, required this.progress, required this.onTap, this.date});

  final HabitProgress progress;
  final VoidCallback onTap;

  /// The calendar day this tile logs for — defaults to today. Set to a
  /// past date for backfilling from the detail screen's heatmap.
  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = progress.habit;
    final color = Color(habit.colorValue);
    final streakLabel = progress.currentStreak > 0 ? '🔥 ${progress.currentStreak}' : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(
            habit.icon?.isNotEmpty == true ? habit.icon! : habit.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(habit.name),
        subtitle: streakLabel != null ? Text(streakLabel) : null,
        trailing: habit.type == HabitType.binary
            ? IconButton(
                iconSize: 32,
                icon: Icon(
                  progress.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: progress.isCompleted ? color : null,
                ),
                onPressed: () => _toggleBinary(ref),
              )
            : OutlinedButton(
                onPressed: () => _promptQuantifiable(context, ref),
                child: Text(
                  progress.log?.value != null
                      ? _formatValue(progress.log!.value!, habit.unit)
                      : 'Log',
                ),
              ),
      ),
    );
  }

  DateTime get _day {
    final d = date ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  String _formatValue(double value, String? unit) {
    final text = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
    return unit != null && unit.isNotEmpty ? '$text $unit' : text;
  }

  Future<void> _toggleBinary(WidgetRef ref) async {
    final repo = ref.read(habitLogRepositoryProvider);
    if (progress.isCompleted) {
      await repo.deleteForDay(progress.habit.id, _day);
    } else {
      await repo.logDay(habitId: progress.habit.id, date: _day);
    }
  }

  Future<void> _promptQuantifiable(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => _QuantifiableInputDialog(
        habitName: progress.habit.name,
        unit: progress.habit.unit,
        initialValue: progress.log?.value,
      ),
    );
    if (value == null) return;
    await ref
        .read(habitLogRepositoryProvider)
        .logDay(habitId: progress.habit.id, date: _day, value: value);
  }
}

/// A numeric-input dialog with its own [TextEditingController], owned and
/// disposed via its own State lifecycle — a controller created in the
/// caller and disposed right after `showDialog` returns would still be
/// attached to this dialog's TextField during its closing animation,
/// throwing "used after being disposed".
class _QuantifiableInputDialog extends StatefulWidget {
  const _QuantifiableInputDialog({
    required this.habitName,
    required this.unit,
    required this.initialValue,
  });

  final String habitName;
  final String? unit;
  final double? initialValue;

  @override
  State<_QuantifiableInputDialog> createState() => _QuantifiableInputDialogState();
}

class _QuantifiableInputDialogState extends State<_QuantifiableInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue != null ? '${widget.initialValue}' : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    return AlertDialog(
      title: Text(widget.habitName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: unit != null && unit.isNotEmpty ? 'Amount ($unit)' : 'Amount',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(double.tryParse(_controller.text.trim())),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
