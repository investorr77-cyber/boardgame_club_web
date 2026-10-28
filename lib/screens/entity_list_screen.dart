import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/list_query.dart';
import '../models/permissions.dart';
import '../state/auth_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../state/load_status.dart';
import '../state/reference_notifier.dart';
import '../widgets/app_drawer.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/entity_card_list.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_controls.dart';
import '../widgets/list_page_layout.dart';
import '../widgets/message_dialog.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/search_field.dart';
import '../widgets/selection_bar.dart';
import '../widgets/simulate_error_action.dart';
import '../widgets/state_views.dart';
import '../widgets/user_menu.dart';

/// Изменение условий отбора; null — «не менять» (page при этом сбросится в 1).
typedef QueryUpdate<Q> = Q Function(
  Q query, {
  String? search,
  String? sortField,
  bool? sortAscending,
  int? page,
  int? size,
  bool? includeDeleted,
});

/// Всё, чем списки пяти сущностей отличаются друг от друга.
class EntityListConfig<T, Q extends ListQuery> {
  const EntityListConfig({
    required this.title,
    required this.path,
    required this.searchHint,
    required this.columns,
    required this.idOf,
    required this.isDeleted,
    required this.nameOf,
    required this.subtitleOf,
    required this.update,
    required this.reset,
    required this.filters,
    required this.activeFilterCount,
  });

  final String title;

  /// Базовый путь: '/games'. Карточка — '$path/:id', форма — '$path/new', '$path/:id/edit'.
  final String path;
  final String searchHint;
  final List<TableColumnSpec<T>> Function(ReferenceNotifier refs) columns;
  final int Function(T item) idOf;
  final bool Function(T item) isDeleted;
  final String Function(T item) nameOf;
  final String Function(T item, ReferenceNotifier refs) subtitleOf;
  final QueryUpdate<Q> update;

  /// Условия «по умолчанию» с сохранением размера страницы и сортировки.
  final Q Function(Q query) reset;

  /// Фильтры сущности (переключатель удалённых и сброс добавляются сами).
  final List<Widget> Function(
          Q query, ReferenceNotifier refs, ValueChanged<Q> apply)
      filters;
  final int Function(Q query) activeFilterCount;
}

/// Экран списка для любой сущности: поиск с задержкой, фильтры, сортировка,
/// пагинация, логическое и физическое удаление, восстановление, множественное
/// удаление и состояние в адресной строке. [query] построен из адреса.
class EntityListScreen<T, Q extends ListQuery> extends StatefulWidget {
  const EntityListScreen({super.key, required this.config, required this.query});

  final EntityListConfig<T, Q> config;
  final Q query;

  @override
  State<EntityListScreen<T, Q>> createState() => _EntityListScreenState<T, Q>();
}

class _EntityListScreenState<T, Q extends ListQuery>
    extends State<EntityListScreen<T, Q>> {
  EntityListConfig<T, Q> get _config => widget.config;

  EntityListNotifier<T, Q> _notifier() =>
      context.read<EntityListNotifier<T, Q>>();

  // Скрытие недоступного — удобство интерфейса, а не защита:
  // сервер всё равно проверит роль по токену и ответит 403.
  bool get _canEdit => context.read<AuthNotifier>().can(
      _config.path == '/members' ? Operation.manageMembers : Operation.editCatalog);

  bool get _canAdmin => context.read<AuthNotifier>().can(Operation.hardDelete);

  @override
  void initState() {
    super.initState();
    _applyUrlQuery();
  }

  @override
  void didUpdateWidget(EntityListScreen<T, Q> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _applyUrlQuery();
  }

  /// Адрес — источник правды. Условия передаются в notifier после кадра
  /// и только если они отличаются от текущих (иначе цикл перестроений).
  void _applyUrlQuery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = _notifier();
      if (notifier.query != widget.query) {
        notifier.applyQuery(widget.query);
      } else {
        notifier.load(); // вернулись на экран — показываем свежие данные
      }
    });
  }

  /// Любое изменение условий отбора — переход по новому адресу.
  void _go(Q query) {
    final params = query.toQueryParameters();
    context.go(Uri(path: _config.path, queryParameters: params.isEmpty ? null : params)
        .toString());
  }

  /// После удаления notifier мог перейти на предыдущую страницу — переносим это в адрес.
  void _syncUrl() {
    final query = _notifier().query;
    if (query != widget.query) _go(query);
  }

  void _resetFilters() => _go(_config.reset(widget.query));

  void _sort(String field) {
    final q = widget.query;
    _go(field == q.sortField
        ? _config.update(q, sortAscending: !q.sortAscending)
        : _config.update(q, sortField: field, sortAscending: true));
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Итог операции: отказ по бизнес-правилу — диалог, иначе сообщение внизу.
  Future<void> _report(String? refusal, String success) async {
    if (!mounted) return;
    if (refusal != null) {
      await showMessageDialog(context,
          title: 'Удаление невозможно', message: refusal);
      return;
    }
    _showMessage(success);
    _syncUrl();
  }

  Future<void> _softDelete(T item) async {
    final name = _config.nameOf(item);
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить запись?',
      message: '«$name» пропадёт из списка. Запись можно вернуть: '
          'включите «Показывать удалённые» и нажмите «Восстановить».',
    );
    if (!ok || !mounted) return;
    final refusal = await _notifier().softDelete(_config.idOf(item));
    await _report(refusal, '«$name» удалено');
  }

  Future<void> _hardDelete(T item) async {
    final name = _config.nameOf(item);
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить навсегда?',
      message: '«$name» будет стёрто без возможности восстановления. '
          'Это действие необратимо.',
      confirmLabel: 'Удалить навсегда',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final refusal = await _notifier().hardDelete(_config.idOf(item));
    await _report(refusal, '«$name» удалено навсегда');
  }

  Future<void> _restore(T item) async {
    final refusal = await _notifier().restore(_config.idOf(item));
    await _report(refusal, '«${_config.nameOf(item)}» восстановлено');
  }

  Future<void> _deleteSelected() async {
    final notifier = _notifier();
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить выбранные записи?',
      message: 'Выбрано записей: ${notifier.selected.length}. '
          'Их можно будет восстановить.',
      confirmLabel: 'Удалить выбранные',
    );
    if (!ok || !mounted) return;
    final outcome = await notifier.deleteSelected();
    await _report(outcome.refusal, 'Удалено записей: ${outcome.count}');
  }

  List<Widget> _actions(T item) {
    final id = _config.idOf(item);
    return [
      IconButton(
        tooltip: 'Открыть',
        icon: const Icon(Icons.open_in_new),
        onPressed: () => context.push('${_config.path}/$id'),
      ),
      if (!_config.isDeleted(item) && _canEdit) ...[
        IconButton(
          tooltip: 'Изменить',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.push('${_config.path}/$id/edit'),
        ),
        IconButton(
          tooltip: 'Удалить',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _softDelete(item),
        ),
      ] else if (_config.isDeleted(item) && _canAdmin) ...[
        IconButton(
          tooltip: 'Восстановить',
          icon: const Icon(Icons.restore),
          onPressed: () => _restore(item),
        ),
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: Icon(Icons.delete_forever,
              color: Theme.of(context).colorScheme.error),
          onPressed: () => _hardDelete(item),
        ),
      ],
    ];
  }

  Widget _buildContent(EntityListNotifier<T, Q> notifier, ReferenceNotifier refs) {
    final items = notifier.result.items;
    final status = notifier.status;
    if (status == LoadStatus.error) {
      return ErrorView(
          message: notifier.error ?? 'Неизвестная ошибка', onRetry: notifier.load);
    }
    if (status == LoadStatus.idle ||
        (status == LoadStatus.loading && items.isEmpty)) {
      return const LoadingView();
    }
    // success с пустым списком — это не загрузка, а отдельное состояние.
    if (items.isEmpty) return EmptyView(onReset: _resetFilters);

    final view = LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        return EntityCardList<T>(
          items: items,
          idOf: _config.idOf,
          title: _config.nameOf,
          subtitle: (item) => _config.subtitleOf(item, refs),
          selected: notifier.selected,
          onToggleSelect: _canEdit ? notifier.toggleSelection : null,
          onSelectAll: _canEdit ? (_) => notifier.toggleSelectAllOnPage() : null,
          onTap: (item) => context.push('${_config.path}/${_config.idOf(item)}'),
          actions: _actions,
          isMuted: _config.isDeleted,
        );
      }
      return EntityTable<T>(
        columns: _config.columns(refs),
        items: items,
        idOf: _config.idOf,
        selected: notifier.selected,
        onToggleSelect: _canEdit ? notifier.toggleSelection : null,
        onSelectAll: _canEdit ? (_) => notifier.toggleSelectAllOnPage() : null,
        sortField: widget.query.sortField,
        sortAscending: widget.query.sortAscending,
        onSort: _sort,
        actions: _actions,
        isMuted: _config.isDeleted,
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
    final notifier = context.watch<EntityListNotifier<T, Q>>();
    final refs = context.watch<ReferenceNotifier>();
    final query = widget.query;
    final result = notifier.result;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    context.watch<AuthNotifier>(); // перестроить при смене пользователя или роли
    final canEdit = _canEdit;
    return Scaffold(
      drawer: AppDrawer(current: _config.path),
      appBar: AppBar(
        title: Text(_config.title),
        actions: [
          SimulateErrorAction(onToggled: notifier.load),
          if (!canEdit)
            const SizedBox.shrink()
          else if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: () => context.push('${_config.path}/new'),
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
              ),
            )
          else
            IconButton(
              tooltip: 'Добавить',
              icon: const Icon(Icons.add),
              onPressed: () => context.push('${_config.path}/new'),
            ),
          const UserMenu(),
        ],
      ),
      body: ListPageLayout(
        search: SearchField(
          value: query.search,
          hint: _config.searchHint,
          onChanged: (value) => _go(_config.update(query, search: value)),
        ),
        filters: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ..._config.filters(query, refs, _go),
            if (_canAdmin)
              ShowDeletedSwitch(
              value: query.includeDeleted,
              onChanged: (v) => _go(_config.update(query, includeDeleted: v)),
            ),
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Сбросить фильтры'),
            ),
          ],
        ),
        activeFilterCount:
            _config.activeFilterCount(query) + (query.includeDeleted ? 1 : 0),
        selectionBar: notifier.selected.isEmpty
            ? null
            : SelectionBar(
                count: notifier.selected.length,
                onDelete: _deleteSelected,
                onClear: notifier.clearSelection,
              ),
        content: _buildContent(notifier, refs),
        pagination: PaginationBar(
          page: query.page,
          totalPages: result.totalPages,
          total: result.total,
          size: query.size,
          onPageChanged: (p) => _go(_config.update(query, page: p)),
          onSizeChanged: (s) => _go(_config.update(query, size: s)),
        ),
      ),
    );
  }
}
