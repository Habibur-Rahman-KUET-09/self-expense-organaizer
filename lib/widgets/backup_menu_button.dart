import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../services/backup_service.dart';
import '../services/habit_backup_service.dart';

/// The single export/import entry point, on the Dashboard's app bar —
/// grouped into an "Expense Tracker" section and a "Habit" section so the
/// two modules' independent backups (BackupService vs HabitBackupService)
/// read as clearly separate, not one generic/merged menu.
class BackupMenuButton extends ConsumerWidget {
  const BackupMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.ios_share),
      tooltip: 'Backup',
      onSelected: (choice) => _handle(context, ref, choice),
      itemBuilder: (context) => [
        _sectionHeader(context, 'Expense Tracker'),
        const PopupMenuItem(value: 'expense_backup', child: Text('Export full backup (JSON)')),
        const PopupMenuItem(value: 'expense_csv', child: Text('Export expenses (CSV)')),
        const PopupMenuItem(value: 'expense_restore', child: Text('Import backup (JSON)')),
        const PopupMenuDivider(),
        _sectionHeader(context, 'Habit'),
        const PopupMenuItem(value: 'habit_backup', child: Text('Export habit backup (JSON)')),
        const PopupMenuItem(value: 'habit_restore', child: Text('Import habit backup (JSON)')),
      ],
    );
  }

  PopupMenuEntry<String> _sectionHeader(BuildContext context, String label) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 28,
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String choice) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (choice) {
        case 'expense_backup':
          await ref.read(backupServiceProvider).shareJsonBackup();
        case 'expense_csv':
          await ref.read(backupServiceProvider).shareExpensesCsv();
        case 'expense_restore':
          await _restoreExpense(context, ref);
        case 'habit_backup':
          await ref.read(habitBackupServiceProvider).shareJsonBackup();
        case 'habit_restore':
          await _restoreHabit(context, ref);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  /// Prompts for a JSON file via the file picker; returns its contents, or
  /// null if the user cancelled.
  Future<String?> _pickJsonFile() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.path;
    if (path == null) return null;
    return File(path).readAsString();
  }

  Future<bool> _confirmReplace(BuildContext context, String dataDescription) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace all data?'),
        content: Text(
          'Restoring this backup will permanently replace all current '
          '$dataDescription with what\'s in the file. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _restoreExpense(BuildContext context, WidgetRef ref) async {
    final content = await _pickJsonFile();
    if (content == null) return; // user cancelled the picker

    if (!context.mounted) return;
    if (!await _confirmReplace(context, 'categories, budgets, expenses, and alerts')) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    RestoreSummary summary;
    try {
      summary = await ref.read(backupServiceProvider).restoreFromJson(content);
    } on InvalidBackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Restored ${summary.categories} categories, ${summary.budgets} '
          'budgets, ${summary.expenses} expenses.',
        ),
      ),
    );
  }

  Future<void> _restoreHabit(BuildContext context, WidgetRef ref) async {
    final content = await _pickJsonFile();
    if (content == null) return; // user cancelled the picker

    if (!context.mounted) return;
    if (!await _confirmReplace(context, 'habit categories, habits, and habit logs')) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    HabitRestoreSummary summary;
    try {
      summary = await ref.read(habitBackupServiceProvider).restoreFromJson(content);
    } on InvalidBackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Restored ${summary.habitCategories} habit categories, '
          '${summary.habits} habits, ${summary.habitLogs} logs.',
        ),
      ),
    );
  }
}
