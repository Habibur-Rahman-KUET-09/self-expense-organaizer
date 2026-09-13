import 'package:flutter/material.dart';

import '../constants.dart';
import '../db/database.dart';

typedef HabitCategoryFormResult = ({String name, int colorValue});

/// Add/edit dialog for a habit category — mirrors CategoryFormDialog, minus
/// the parent/sub-category concept (habit categories are a flat list).
class HabitCategoryFormDialog extends StatefulWidget {
  const HabitCategoryFormDialog({super.key, this.existing});

  /// Non-null when editing an existing category.
  final HabitCategory? existing;

  static Future<HabitCategoryFormResult?> show(
    BuildContext context, {
    HabitCategory? existing,
  }) {
    return showDialog<HabitCategoryFormResult>(
      context: context,
      builder: (_) => HabitCategoryFormDialog(existing: existing),
    );
  }

  @override
  State<HabitCategoryFormDialog> createState() => _HabitCategoryFormDialogState();
}

class _HabitCategoryFormDialogState extends State<HabitCategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _colorValue = widget.existing?.colorValue ?? categoryColorPalette.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit habit category' : 'New habit category'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in categoryColorPalette)
                  GestureDetector(
                    onTap: () => setState(() => _colorValue = color),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(color),
                      child: _colorValue == color
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(
                context,
              ).pop((name: _nameController.text.trim(), colorValue: _colorValue));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
