import 'package:flutter/material.dart';

import 'muted_badge.dart';

/// Список карточек для узкого экрана (< 600 px): те же флажки и действия,
/// что и в EntityTable.
class EntityCardList<T> extends StatelessWidget {
  const EntityCardList({
    super.key,
    required this.items,
    required this.idOf,
    required this.title,
    this.subtitle,
    this.selected = const <int>{},
    this.onToggleSelect,
    this.onSelectAll,
    this.onTap,
    this.actions,
    this.isMuted,
    this.mutedLabel = 'удалено',
  });

  final List<T> items;
  final int Function(T item) idOf;
  final String Function(T item) title;
  final String Function(T item)? subtitle;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final ValueChanged<bool>? onSelectAll;
  final void Function(T item)? onTap;
  final List<Widget> Function(T item)? actions;
  final bool Function(T item)? isMuted;
  final String mutedLabel;

  bool get _allSelected =>
      items.isNotEmpty && items.every((i) => selected.contains(idOf(i)));

  @override
  Widget build(BuildContext context) {
    final hasHeader = onSelectAll != null;
    return ListView.builder(
      itemCount: items.length + (hasHeader ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasHeader && index == 0) {
          return CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: _allSelected,
            onChanged: (value) => onSelectAll!(value ?? false),
            title: const Text('Выбрать все на странице'),
          );
        }
        return _buildCard(context, items[index - (hasHeader ? 1 : 0)]);
      },
    );
  }

  Widget _buildCard(BuildContext context, T item) {
    final theme = Theme.of(context);
    final id = idOf(item);
    final muted = isMuted?.call(item) ?? false;
    final text = subtitle?.call(item);
    return Card(
      color: muted ? theme.colorScheme.surfaceContainerHighest : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onToggleSelect != null)
                  Checkbox(
                    value: selected.contains(id),
                    onChanged: (_) => onToggleSelect!(id),
                  ),
                Expanded(
                  child: InkWell(
                    onTap: onTap == null ? null : () => onTap!(item),
                    child: Opacity(
                      opacity: muted ? 0.55 : 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title(item), style: theme.textTheme.titleMedium),
                            if (text != null)
                              Text(text, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (muted)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, right: 8),
                    child: MutedBadge(label: mutedLabel),
                  ),
              ],
            ),
            if (actions != null)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(children: actions!(item)),
              ),
          ],
        ),
      ),
    );
  }
}
