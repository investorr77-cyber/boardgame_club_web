import 'package:flutter/material.dart';

/// Пометка удалённой записи в таблице и карточках.
class MutedBadge extends StatelessWidget {
  const MutedBadge({super.key, this.label = 'удалено'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onErrorContainer),
      ),
    );
  }
}
