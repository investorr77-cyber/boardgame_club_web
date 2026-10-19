import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/designer.dart';
import '../models/designer_query.dart';
import '../state/designer_list_notifier.dart';
import '../state/load_status.dart';
import '../state/reference_notifier.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/entity_card_list.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_controls.dart';
import '../widgets/list_page_layout.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/search_field.dart';
import '../widgets/selection_bar.dart';
import '../widgets/simulate_error_action.dart';
import '../widgets/state_views.dart';

/// Список авторов. Те же возможности, что у списка игр; таблица — тот же EntityTable.
class DesignersScreen extends StatefulWidget {
  const DesignersScreen({super.key, required this.query});

  final DesignerQuery query;

  @override
  State<DesignersScreen> createState() => _DesignersScreenState();
}

class _DesignersScreenState extends State<DesignersScreen> {
  @override
  void initState() {
    super.initState();
    _applyUrlQuery();
  }

  @override
  void didUpdateWidget(DesignersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _applyUrlQuery();
  }

  void _applyUrlQuery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = context.read<DesignerListNotifier>();
      if (notifier.query != widget.query ||
          notifier.status == LoadStatus.idle) {
        notifier.applyQuery(widget.query);
      }
    });
  }

  void _go(DesignerQuery query) {
    final params = query.toQueryParameters();
    context.go(
      Uri(path: '/designers', queryParameters: params.isEmpty ? null : params)
          .toString(),
    );
  }

  void _syncUrl() {
    final query = context.read<DesignerListNotifier>().query;
    if (query != widget.query) _go(query);
  }

  void _resetFilters() => _go(DesignerQuery(
        size: widget.query.size,
        sortField: widget.query.sortField,
        sortAscending: widget.query.sortAscending,
      ));

  void _sort(String field) {
    final q = widget.query;
    _go(field == q.sortField
        ? q.copyWith(sortAscending: !q.sortAscending)
        : q.copyWith(sortField: field, sortAscending: true));
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _softDelete(Designer d) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить автора?',
      message: '${d.fullName} пропадёт из списка. Запись можно вернуть: '
          'включите «Показывать удалённые» и нажмите «Восстановить».',
    );
    if (!ok || !mounted) return;
    await context.read<DesignerListNotifier>().softDelete(d.id);
    if (!mounted) return;
    _showMessage('${d.fullName}: запись удалена');
    _syncUrl();
  }

  Future<void> _hardDelete(Designer d) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить навсегда?',
      message: 'Запись «${d.fullName}» будет стёрта без возможности '
          'восстановления. Это действие необратимо.',
      confirmLabel: 'Удалить навсегда',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<DesignerListNotifier>().hardDelete(d.id);
    if (!mounted) return;
    _showMessage('${d.fullName}: запись удалена навсегда');
    _syncUrl();
  }

  Future<void> _restore(Designer d) async {
    await context.read<DesignerListNotifier>().restore(d.id);
    if (!mounted) return;
    _showMessage('${d.fullName}: запись восстановлена');
    _syncUrl();
  }

  Future<void> _deleteSelected() async {
    final notifier = context.read<DesignerListNotifier>();
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить выбранных авторов?',
      message: 'Выбрано записей: ${notifier.selected.length}. '
          'Их можно будет восстановить.',
      confirmLabel: 'Удалить выбранные',
    );
    if (!ok || !mounted) return;
    final deleted = await notifier.deleteSelected();
    if (!mounted) return;
    _showMessage('Удалено записей: $deleted');
    _syncUrl();
  }

  static final _columns = <TableColumnSpec<Designer>>[
    TableColumnSpec(
        label: 'Фамилия', sortField: 'lastName', build: (d) => Text(d.lastName)),
    TableColumnSpec(label: 'Имя', build: (d) => Text(d.firstName)),
    TableColumnSpec(
        label: 'Страна', sortField: 'country', build: (d) => Text(d.country)),
    TableColumnSpec(
        label: 'Год рождения',
        sortField: 'birthYear',
        numeric: true,
        build: (d) => Text('${d.birthYear}')),
  ];

  List<Widget> _actions(Designer d) => [
        IconButton(
          tooltip: 'Открыть',
          icon: const Icon(Icons.open_in_new),
          onPressed: () => context.push('/designers/${d.id}'),
        ),
        if (!d.isDeleted)
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _softDelete(d),
          )
        else ...[
          IconButton(
            tooltip: 'Восстановить',
            icon: const Icon(Icons.restore),
            onPressed: () => _restore(d),
          ),
          IconButton(
            tooltip: 'Удалить навсегда',
            icon: Icon(Icons.delete_forever,
                color: Theme.of(context).colorScheme.error),
            onPressed: () => _hardDelete(d),
          ),
        ],
      ];

  Widget _buildContent(DesignerListNotifier notifier) {
    final items = notifier.result.items;
    final status = notifier.status;
    if (status == LoadStatus.error) {
      return ErrorView(
          message: notifier.error ?? 'Неизвестная ошибка',
          onRetry: notifier.load);
    }
    if (status == LoadStatus.idle ||
        (status == LoadStatus.loading && items.isEmpty)) {
      return const LoadingView();
    }
    if (items.isEmpty) return EmptyView(onReset: _resetFilters);

    final view = LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        return EntityCardList<Designer>(
          items: items,
          idOf: (d) => d.id,
          title: (d) => d.fullName,
          subtitle: (d) => '${d.country} · ${d.birthYear} г. р.',
          selected: notifier.selected,
          onToggleSelect: notifier.toggleSelection,
          onSelectAll: (_) => notifier.toggleSelectAllOnPage(),
          onTap: (d) => context.push('/designers/${d.id}'),
          actions: _actions,
          isMuted: (d) => d.isDeleted,
        );
      }
      return EntityTable<Designer>(
        columns: _columns,
        items: items,
        idOf: (d) => d.id,
        selected: notifier.selected,
        onToggleSelect: notifier.toggleSelection,
        onSelectAll: (_) => notifier.toggleSelectAllOnPage(),
        sortField: widget.query.sortField,
        sortAscending: widget.query.sortAscending,
        onSort: _sort,
        actions: _actions,
        isMuted: (d) => d.isDeleted,
      );
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 4,
          child: status == LoadStatus.loading
              ? const LinearProgressIndicator()
              : null,
        ),
        Expanded(child: view),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DesignerListNotifier>();
    final refs = context.watch<ReferenceNotifier>();
    final query = widget.query;
    final result = notifier.result;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'На главную',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Авторы'),
        actions: [
          SimulateErrorAction(onToggled: notifier.load),
          IconButton(
            tooltip: 'Игры',
            icon: const Icon(Icons.casino_outlined),
            onPressed: () => context.go('/games'),
          ),
        ],
      ),
      body: ListPageLayout(
        search: SearchField(
          value: query.search,
          hint: 'Поиск по фамилии или стране',
          onChanged: (value) => _go(query.copyWith(search: value)),
        ),
        filters: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterDropdown<String>(
              label: 'Страна',
              value: query.country,
              options: {for (final c in refs.countries) c: c},
              onChanged: (v) => _go(query.copyWith(country: v)),
            ),
            ShowDeletedSwitch(
              value: query.includeDeleted,
              onChanged: (v) => _go(query.copyWith(includeDeleted: v)),
            ),
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Сбросить фильтры'),
            ),
          ],
        ),
        activeFilterCount:
            (query.country != null ? 1 : 0) + (query.includeDeleted ? 1 : 0),
        selectionBar: notifier.selected.isEmpty
            ? null
            : SelectionBar(
                count: notifier.selected.length,
                onDelete: _deleteSelected,
                onClear: notifier.clearSelection,
              ),
        content: _buildContent(notifier),
        pagination: PaginationBar(
          page: query.page,
          totalPages: result.totalPages,
          total: result.total,
          size: query.size,
          onPageChanged: (p) => _go(query.copyWith(page: p)),
          onSizeChanged: (s) => _go(query.copyWith(size: s)),
        ),
      ),
    );
  }
}
