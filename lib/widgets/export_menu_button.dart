import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';

/// Export action shared by the Budget Setup and Reports app bars (NFR-6).
class ExportMenuButton extends ConsumerWidget {
  const ExportMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.ios_share),
      tooltip: 'Export',
      onSelected: (choice) => _handle(context, ref, choice),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'backup', child: Text('Export full backup (JSON)')),
        PopupMenuItem(value: 'csv', child: Text('Export expenses (CSV)')),
      ],
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String choice) async {
    final messenger = ScaffoldMessenger.of(context);
    final export = ref.read(exportServiceProvider);
    try {
      if (choice == 'backup') {
        await export.shareJsonBackup();
      } else {
        await export.shareExpensesCsv();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}
