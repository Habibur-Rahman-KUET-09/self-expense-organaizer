import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../db/database.dart';
import '../logic/frequency_schedule.dart';
import '../models/enums.dart';
import '../providers/database_providers.dart';
import '../providers/habit_category_providers.dart';
import 'habit_category_form_dialog.dart';

typedef HabitFormResult = ({
  String name,
  String? icon,
  int colorValue,
  int? categoryId,
  HabitType type,
  HabitFrequencyType frequencyType,
  String frequencyConfig,
  double? targetValue,
  String? unit,
  DateTime startDate,
  DateTime? endDate,
});

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Create/edit sheet for a habit (Habit Tracker RS §4.1): name, icon,
/// color, category, binary/quantifiable type, frequency (with its
/// type-specific config), optional target/unit, and start/end dates.
class HabitEditorSheet extends ConsumerStatefulWidget {
  const HabitEditorSheet({super.key, this.existing});

  final Habit? existing;

  static Future<HabitFormResult?> show(BuildContext context, {Habit? existing}) {
    return showModalBottomSheet<HabitFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: HabitEditorSheet(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends ConsumerState<HabitEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _iconController;
  late final TextEditingController _targetController;
  late final TextEditingController _unitController;
  late final TextEditingController _countController;
  late final TextEditingController _everyNDaysController;

  late int _colorValue;
  int? _categoryId;
  late HabitType _type;
  late HabitFrequencyType _frequencyType;
  late Set<int> _daysOfWeek;
  late DateTime _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _iconController = TextEditingController(text: existing?.icon ?? '');
    _targetController = TextEditingController(
      text: existing?.targetValue != null ? _trimTrailingZero(existing!.targetValue!) : '',
    );
    _unitController = TextEditingController(text: existing?.unit ?? '');
    _colorValue = existing?.colorValue ?? categoryColorPalette.first;
    _categoryId = existing?.categoryId;
    _type = existing?.type ?? HabitType.binary;
    _frequencyType = existing?.frequencyType ?? HabitFrequencyType.daily;
    _startDate = existing != null
        ? DateTime(existing.startDate.year, existing.startDate.month, existing.startDate.day)
        : DateTime.now();
    _endDate = existing?.endDate;

    final schedule = FrequencySchedule.parse(
      _frequencyType,
      existing?.frequencyConfig ?? '{}',
    );
    _daysOfWeek = schedule.daysOfWeek.toSet();
    _countController = TextEditingController(text: '${schedule.targetCount}');
    _everyNDaysController = TextEditingController(text: '${schedule.everyNDays}');
  }

  static String _trimTrailingZero(double value) {
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    _countController.dispose();
    _everyNDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(habitCategoriesProvider(true));

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
                widget.existing != null ? 'Edit habit' : 'New habit',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: TextFormField(
                      controller: _iconController,
                      maxLength: 2,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'Icon', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      autofocus: widget.existing == null,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Name is required' : null,
                    ),
                  ),
                ],
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
              const SizedBox(height: 16),
              Text('Category', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (categories) => Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _categoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('None')),
                          for (final category in categories)
                            DropdownMenuItem(value: category.id, child: Text(category.name)),
                        ],
                        onChanged: (value) => setState(() => _categoryId = value),
                      ),
                    ),
                    IconButton(
                      tooltip: 'New category',
                      icon: const Icon(Icons.add),
                      onPressed: _addCategory,
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Error: $error'),
              ),
              const SizedBox(height: 16),
              Text('Type', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<HabitType>(
                segments: const [
                  ButtonSegment(value: HabitType.binary, label: Text('Done / not done')),
                  ButtonSegment(value: HabitType.quantifiable, label: Text('Numeric target')),
                ],
                selected: {_type},
                onSelectionChanged: (selection) => setState(() => _type = selection.first),
              ),
              if (_type == HabitType.quantifiable) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _targetController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Target (optional)'),
                        validator: _validateOptionalPositiveNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(labelText: 'Unit (optional)'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text('Frequency', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<HabitFrequencyType>(
                initialValue: _frequencyType,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: HabitFrequencyType.daily, child: Text('Daily')),
                  DropdownMenuItem(
                    value: HabitFrequencyType.daysOfWeek,
                    child: Text('Specific days of the week'),
                  ),
                  DropdownMenuItem(
                    value: HabitFrequencyType.timesPerWeek,
                    child: Text('X times per week'),
                  ),
                  DropdownMenuItem(
                    value: HabitFrequencyType.timesPerMonth,
                    child: Text('X times per month'),
                  ),
                  DropdownMenuItem(
                    value: HabitFrequencyType.customInterval,
                    child: Text('Every N days'),
                  ),
                ],
                onChanged: (value) => setState(() => _frequencyType = value!),
              ),
              const SizedBox(height: 12),
              _buildFrequencyConfigInput(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start date'),
                      subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                      onTap: _pickStartDate,
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End date'),
                      subtitle: Text(
                        _endDate != null ? DateFormat.yMMMd().format(_endDate!) : 'None',
                      ),
                      onTap: _pickEndDate,
                      trailing: _endDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _endDate = null),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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

  Widget _buildFrequencyConfigInput() {
    switch (_frequencyType) {
      case HabitFrequencyType.daily:
        return const SizedBox.shrink();
      case HabitFrequencyType.daysOfWeek:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var weekday = 1; weekday <= 7; weekday++)
              FilterChip(
                label: Text(_weekdayLabels[weekday - 1]),
                selected: _daysOfWeek.contains(weekday),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _daysOfWeek.add(weekday);
                  } else {
                    _daysOfWeek.remove(weekday);
                  }
                }),
              ),
          ],
        );
      case HabitFrequencyType.timesPerWeek:
      case HabitFrequencyType.timesPerMonth:
        final periodLabel =
            _frequencyType == HabitFrequencyType.timesPerWeek ? 'week' : 'month';
        return TextFormField(
          controller: _countController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Times per $periodLabel'),
          validator: _validateRequiredPositiveInt,
        );
      case HabitFrequencyType.customInterval:
        return TextFormField(
          controller: _everyNDaysController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Every N days'),
          validator: _validateRequiredPositiveInt,
        );
    }
  }

  String? _validateOptionalPositiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return 'Enter a valid number';
    return null;
  }

  String? _validateRequiredPositiveInt(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed <= 0) return 'Enter a whole number, 1 or more';
    return null;
  }

  Future<void> _addCategory() async {
    final result = await HabitCategoryFormDialog.show(context);
    if (result == null || !mounted) return;
    final id = await ref
        .read(habitCategoryRepositoryProvider)
        .add(name: result.name, colorValue: result.colorValue);
    setState(() => _categoryId = id);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  void _submit() {
    if (_frequencyType == HabitFrequencyType.daysOfWeek && _daysOfWeek.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick at least one day of the week')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final String frequencyConfig;
    switch (_frequencyType) {
      case HabitFrequencyType.daily:
        frequencyConfig = '{}';
      case HabitFrequencyType.daysOfWeek:
        frequencyConfig = FrequencySchedule.encodeDaysOfWeek(_daysOfWeek.toList()..sort());
      case HabitFrequencyType.timesPerWeek:
      case HabitFrequencyType.timesPerMonth:
        frequencyConfig = FrequencySchedule.encodeCount(
          int.parse(_countController.text.trim()),
        );
      case HabitFrequencyType.customInterval:
        frequencyConfig = FrequencySchedule.encodeCustomInterval(
          everyNDays: int.parse(_everyNDaysController.text.trim()),
          anchorDate: _startDate,
        );
    }

    final targetText = _targetController.text.trim();
    final unitText = _unitController.text.trim();
    final iconText = _iconController.text.trim();

    Navigator.of(context).pop((
      name: _nameController.text.trim(),
      icon: iconText.isEmpty ? null : iconText,
      colorValue: _colorValue,
      categoryId: _categoryId,
      type: _type,
      frequencyType: _frequencyType,
      frequencyConfig: frequencyConfig,
      targetValue: _type == HabitType.quantifiable && targetText.isNotEmpty
          ? double.parse(targetText)
          : null,
      unit: _type == HabitType.quantifiable && unitText.isNotEmpty ? unitText : null,
      startDate: _startDate,
      endDate: _endDate,
    ));
  }
}
