import 'package:flutter/material.dart';

import '../constants.dart';
import '../db/database.dart';

typedef CategoryFormResult = ({String name, int colorValue});

/// Add/edit dialog for a category or sub-category (FR-1.1/FR-1.2).
class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({super.key, this.existing, this.isSubCategory = false});

  /// Non-null when editing an existing category.
  final Category? existing;

  /// Whether this dialog is creating/editing a sub-category (label only —
  /// the caller supplies the parentId separately when saving).
  final bool isSubCategory;

  static Future<CategoryFormResult?> show(
    BuildContext context, {
    Category? existing,
    bool isSubCategory = false,
  }) {
    return showDialog<CategoryFormResult>(
      context: context,
      builder: (_) =>
          CategoryFormDialog(existing: existing, isSubCategory: isSubCategory),
    );
  }

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
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
    final kind = widget.isSubCategory ? 'sub-category' : 'category';
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit $kind' : 'New $kind'),
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
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Name is required'
                  : null,
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
