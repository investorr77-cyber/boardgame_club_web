import 'package:flutter/material.dart';

/// Сообщение с одной кнопкой: например, отказ в удалении связанной записи.
Future<void> showMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.block, color: Theme.of(context).colorScheme.error),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(message),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );
}
