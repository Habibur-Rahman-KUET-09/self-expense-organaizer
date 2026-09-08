import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../services/backup_service.dart';

/// Export/import actions shared by the Budget Setup and Reports app bars
/// (NFR-6).
class BackupMenuButton extends ConsumerWidget {
  const BackupMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.ios_share),
      tooltip: 'Backup',
      onSelected: (choice) => _handle(context, ref, choice),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'backup', child: Text('Export full backup (JSON)')),
        PopupMenuItem(value: 'csv', child: Text('Export expenses (CSV)')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'restore', child: Text('Import backup (JSON)')),
      ],
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String choice) async {
    final messenger = ScaffoldMessenger.of(context);
    final backup = ref.read(backupServiceProvider);
    try {
      switch (choice) {
        case 'backup':
          await backup.shareJsonBackup();
        case 'csv':
          await backup.shareExpensesCsv();
        case 'restore':
          await _restore(context, ref);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return; // user cancelled the picker

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
          'Restoring this backup will permanently replace all current '
          'categories, budgets, expenses, and alerts with what\'s in the '
          'file. This can\'t be undone.',
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
    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final content = await File(path).readAsString();
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
}
