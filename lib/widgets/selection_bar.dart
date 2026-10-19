import 'package:flutter/material.dart';

/// Полоса множественного выделения: «Выбрано: N», удалить, снять выделение.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onDelete,
    required this.onClear,
  });

  final int count;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Выбрано: $count',
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            FilledButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить выбранные'),
            ),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.deselect),
              label: const Text('Снять выделение'),
            ),
          ],
        ),
      ),
    );
  }
}
