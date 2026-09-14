import 'package:flutter/material.dart';

/// A curated set of emoji relevant to common personal-organizer habits — a
/// short, deliberate list rather than a full system emoji keyboard, since a
/// habit icon just needs to be quickly recognizable at a glance, not
/// exhaustive.
const habitIconChoices = [
  '🏃', '🏋️', '🧘', '🚴', '🏊', '⚽', '🥗', '💧',
  '📖', '📚', '✍️', '🎨', '🎸', '🎹', '💻', '📝',
  '😴', '🌅', '🙏', '🕌', '⛪', '📿', '💊', '🪥',
  '🚿', '🧹', '🧺', '🌱', '☀️', '🌙', '🚭', '🚫',
  '💰', '⏰', '✅', '🔥', '💪', '❤️', '🚶', '🎯',
];

/// A tappable circular preview of [icon] that opens [showHabitIconPicker]
/// when tapped, and reports the new choice via [onChanged].
class HabitIconButton extends StatelessWidget {
  const HabitIconButton({super.key, required this.icon, required this.onChanged});

  final String? icon;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasIcon = icon != null && icon!.isNotEmpty;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () async {
        final result = await showHabitIconPicker(context, current: icon);
        if (result == null) return; // dismissed without choosing
        onChanged(result.isEmpty ? null : result);
      },
      child: CircleAvatar(
        radius: 28,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: hasIcon
            ? Text(icon!, style: const TextStyle(fontSize: 24))
            : Icon(
                Icons.add_reaction_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

/// Shows a picker grid over [habitIconChoices]. Resolves to: the chosen
/// emoji; `''` if the user explicitly picked "None" (clear the icon); or
/// `null` if the sheet was dismissed without a choice (leave as-is).
Future<String?> showHabitIconPicker(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose an icon', style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: current == null || current.isEmpty,
                  onSelected: (_) => Navigator.of(sheetContext).pop(''),
                ),
                for (final emoji in habitIconChoices)
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.of(sheetContext).pop(emoji),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: current == emoji
                          ? Theme.of(sheetContext).colorScheme.primaryContainer
                          : Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
