import 'package:flutter/material.dart';

import 'muted_badge.dart';

/// Описание одной колонки обобщённой таблицы.
class TableColumnSpec<T> {
  const TableColumnSpec({
    required this.label,
    this.sortField,
    this.numeric = false,
    required this.build,
  });

  final String label;

  /// Поле сортировки; null — колонка не сортируется.
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;
}

/// Обобщённая таблица для любой сущности. Внутри нет ничего про игры
/// или авторов: экран передаёт только колонки, действия и обработчики.
class EntityTable<T> extends StatelessWidget {
  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const <int>{},
    this.onToggleSelect,
    this.onSelectAll,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
    this.isMuted,
    this.mutedLabel = 'удалено',
  });

  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final int Function(T item) idOf;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;

  /// Флажок «выбрать все на странице» в заголовке.
  final ValueChanged<bool>? onSelectAll;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;

  /// Приглушённые строки (удалённые записи).
  final bool Function(T item)? isMuted;
  final String mutedLabel;

  @override
  Widget build(BuildContext context) {
    final sortIndex = columns
        .indexWhere((c) => c.sortField != null && c.sortField == sortField);
    final scheme = Theme.of(context).colorScheme;
    final table = DataTable(
      showCheckboxColumn: onToggleSelect != null,
      sortColumnIndex: sortIndex == -1 ? null : sortIndex,
      sortAscending: sortAscending,
      onSelectAll:
          onSelectAll == null ? null : (value) => onSelectAll!(value ?? false),
      columns: [
        for (final column in columns)
          DataColumn(
            label: Text(column.label),
            numeric: column.numeric,
            // Клик по заголовку: экран решает, сменить поле или направление.
            onSort: column.sortField == null || onSort == null
                ? null
                : (_, __) => onSort!(column.sortField!),
          ),
        if (actions != null) const DataColumn(label: Text('Действия')),
      ],
      rows: [for (final item in items) _buildRow(item, scheme)],
    );

    // Двумерная прокрутка: широкая таблица не уезжает за край экрана.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: table,
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(T item, ColorScheme scheme) {
    final id = idOf(item);
    final muted = isMuted?.call(item) ?? false;
    return DataRow(
      selected: selected.contains(id),
      onSelectChanged:
          onToggleSelect == null ? null : (_) => onToggleSelect!(id),
      color:
          muted ? WidgetStatePropertyAll(scheme.surfaceContainerHighest) : null,
      cells: [
        for (var i = 0; i < columns.length; i++)
          DataCell(_cell(columns[i].build(item),
              muted: muted, withBadge: muted && i == 0)),
        if (actions != null)
          DataCell(
              Row(mainAxisSize: MainAxisSize.min, children: actions!(item))),
      ],
    );
  }

  Widget _cell(Widget child, {required bool muted, required bool withBadge}) {
    if (!muted) return child;
    final dimmed = Opacity(opacity: 0.5, child: child);
    if (!withBadge) return dimmed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dimmed,
        const SizedBox(width: 8),
        MutedBadge(label: mutedLabel)
      ],
    );
  }
}
