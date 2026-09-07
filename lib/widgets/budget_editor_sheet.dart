import 'package:flutter/material.dart';

import '../db/database.dart';
import '../models/enums.dart';

typedef BudgetFormResult = ({
  double minCost,
  double maxCost,
  double thresholdPercent,
  ThresholdBase thresholdBase,
});

/// Bottom sheet to set/edit a category's min/max budget and threshold for
/// one month (FR-2.1, FR-4.1/FR-4.2).
class BudgetEditorSheet extends StatefulWidget {
  const BudgetEditorSheet({super.key, this.existing, required this.categoryName});

  final Budget? existing;
  final String categoryName;

  static Future<BudgetFormResult?> show(
    BuildContext context, {
    Budget? existing,
    required String categoryName,
  }) {
    return showModalBottomSheet<BudgetFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: BudgetEditorSheet(existing: existing, categoryName: categoryName),
      ),
    );
  }

  @override
  State<BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<BudgetEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late double _thresholdPercent;
  late ThresholdBase _thresholdBase;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
      text: widget.existing != null
          ? _trimTrailingZero(widget.existing!.minCost)
          : '',
    );
    _maxController = TextEditingController(
      text: widget.existing != null
          ? _trimTrailingZero(widget.existing!.maxCost)
          : '',
    );
    _thresholdPercent = widget.existing?.thresholdPercent ?? 90;
    _thresholdBase = widget.existing?.thresholdBase ?? ThresholdBase.max;
  }

  static String _trimTrailingZero(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget · ${widget.categoryName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Minimum probable cost'),
                validator: _validateNonNegativeNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Maximum probable cost'),
                validator: (value) {
                  final basic = _validateNonNegativeNumber(value);
                  if (basic != null) return basic;
                  final min = double.tryParse(_minController.text.trim());
                  final max = double.tryParse(value!.trim());
                  if (min != null && max != null && max < min) {
                    return 'Max must be at least min';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text('Alert threshold: ${_thresholdPercent.round()}%'),
              Slider(
                value: _thresholdPercent,
                min: 50,
                max: 150,
                divisions: 100,
                label: '${_thresholdPercent.round()}%',
                onChanged: (value) => setState(() => _thresholdPercent = value),
              ),
              const SizedBox(height: 8),
              Text('Threshold based on', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<ThresholdBase>(
                segments: const [
                  ButtonSegment(value: ThresholdBase.min, label: Text('Min')),
                  ButtonSegment(value: ThresholdBase.max, label: Text('Max')),
                ],
                selected: {_thresholdBase},
                onSelectionChanged: (selection) =>
                    setState(() => _thresholdBase = selection.first),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(onPressed: _submit, child: const Text('Save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateNonNegativeNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return 'Must be 0 or more';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      minCost: double.parse(_minController.text.trim()),
      maxCost: double.parse(_maxController.text.trim()),
      thresholdPercent: _thresholdPercent,
      thresholdBase: _thresholdBase,
    ));
  }
}
