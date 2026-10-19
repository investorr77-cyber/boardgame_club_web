import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/board_game.dart';
import '../models/game_query.dart';
import '../state/game_list_notifier.dart';
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

/// Список игр. [query] построен из адресной строки — она источник правды.
class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key, required this.query});

  final GameQuery query;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  @override
  void initState() {
    super.initState();
    _applyUrlQuery();
  }

  @override
  void didUpdateWidget(GamesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _applyUrlQuery();
  }

  /// Условия из адреса передаются в notifier после кадра и только если они
  /// отличаются от текущих — так нет бесконечного цикла перестроений.
  void _applyUrlQuery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = context.read<GameListNotifier>();
      if (notifier.query != widget.query ||
          notifier.status == LoadStatus.idle) {
        notifier.applyQuery(widget.query);
      }
    });
  }

  /// Любое изменение условий отбора — переход по новому адресу.
  void _go(GameQuery query) {
    final params = query.toQueryParameters();
    context.go(
      Uri(path: '/games', queryParameters: params.isEmpty ? null : params)
          .toString(),
    );
  }

  /// После удаления notifier мог перейти на предыдущую страницу — переносим это в адрес.
  void _syncUrl() {
    final query = context.read<GameListNotifier>().query;
    if (query != widget.query) _go(query);
  }

  void _resetFilters() => _go(GameQuery(
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

  Future<void> _softDelete(BoardGame game) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить игру?',
      message: '«${game.title}» пропадёт из каталога. Её можно вернуть: '
          'включите «Показывать удалённые» и нажмите «Восстановить».',
    );
    if (!ok || !mounted) return;
    await context.read<GameListNotifier>().softDelete(game.id);
    if (!mounted) return;
    _showMessage('«${game.title}» удалена');
    _syncUrl();
  }

  Future<void> _hardDelete(BoardGame game) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить навсегда?',
      message: '«${game.title}» будет стёрта без возможности восстановления. '
          'Это действие необратимо.',
      confirmLabel: 'Удалить навсегда',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<GameListNotifier>().hardDelete(game.id);
    if (!mounted) return;
    _showMessage('«${game.title}» удалена навсегда');
    _syncUrl();
  }

  Future<void> _restore(BoardGame game) async {
    await context.read<GameListNotifier>().restore(game.id);
    if (!mounted) return;
    _showMessage('«${game.title}» восстановлена');
    _syncUrl();
  }

  Future<void> _deleteSelected() async {
    final notifier = context.read<GameListNotifier>();
    final ok = await showConfirmDialog(
      context,
      title: 'Удалить выбранные игры?',
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

  static String _players(BoardGame g) => g.minPlayers == g.maxPlayers
      ? '${g.minPlayers} игр.'
      : '${g.minPlayers}–${g.maxPlayers} игр.';

  static int _activeFilters(GameQuery q) =>
      [q.genreId, q.publisherId, q.yearFrom, q.yearTo]
          .where((v) => v != null)
          .length +
      (q.includeDeleted ? 1 : 0);

  List<TableColumnSpec<BoardGame>> _columns(ReferenceNotifier refs) => [
        TableColumnSpec(
            label: 'Название', sortField: 'title', build: (g) => Text(g.title)),
        TableColumnSpec(
            label: 'Год',
            sortField: 'year',
            numeric: true,
            build: (g) => Text('${g.year}')),
        TableColumnSpec(
            label: 'Время партии',
            sortField: 'playTimeMin',
            numeric: true,
            build: (g) => Text('${g.playTimeMin} мин')),
        TableColumnSpec(label: 'Игроки', build: (g) => Text(_players(g))),
        TableColumnSpec(
            label: 'Издатель',
            build: (g) => Text(refs.publisherName(g.publisherId))),
        TableColumnSpec(
            label: 'Свободно',
            numeric: true,
            build: (g) => Text('${g.copiesAvailable} из ${g.copiesTotal}')),
        TableColumnSpec(label: 'Штрихкод', build: (g) => Text(g.barcode)),
      ];

  List<Widget> _actions(BoardGame game) => [
        IconButton(
          tooltip: 'Открыть',
          icon: const Icon(Icons.open_in_new),
          onPressed: () => context.push('/games/${game.id}'),
        ),
        if (!game.isDeleted)
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _softDelete(game),
          )
        else ...[
          IconButton(
            tooltip: 'Восстановить',
            icon: const Icon(Icons.restore),
            onPressed: () => _restore(game),
          ),
          IconButton(
            tooltip: 'Удалить навсегда',
            icon: Icon(Icons.delete_forever,
                color: Theme.of(context).colorScheme.error),
            onPressed: () => _hardDelete(game),
          ),
        ],
      ];

  Widget _buildContent(GameListNotifier notifier, ReferenceNotifier refs) {
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
    // success с пустым списком — это не загрузка, а отдельное состояние.
    if (items.isEmpty) return EmptyView(onReset: _resetFilters);

    final view = LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        return EntityCardList<BoardGame>(
          items: items,
          idOf: (g) => g.id,
          title: (g) => g.title,
          subtitle: (g) => '${g.year} · ${g.playTimeMin} мин · ${_players(g)} · '
              '${refs.publisherName(g.publisherId)}',
          selected: notifier.selected,
          onToggleSelect: notifier.toggleSelection,
          onSelectAll: (_) => notifier.toggleSelectAllOnPage(),
          onTap: (g) => context.push('/games/${g.id}'),
          actions: _actions,
          isMuted: (g) => g.isDeleted,
        );
      }
      return EntityTable<BoardGame>(
        columns: _columns(refs),
        items: items,
        idOf: (g) => g.id,
        selected: notifier.selected,
        onToggleSelect: notifier.toggleSelection,
        onSelectAll: (_) => notifier.toggleSelectAllOnPage(),
        sortField: widget.query.sortField,
        sortAscending: widget.query.sortAscending,
        onSort: _sort,
        actions: _actions,
        isMuted: (g) => g.isDeleted,
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
    final notifier = context.watch<GameListNotifier>();
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
        title: const Text('Игры'),
        actions: [
          SimulateErrorAction(onToggled: notifier.load),
          IconButton(
            tooltip: 'Авторы',
            icon: const Icon(Icons.people_outline),
            onPressed: () => context.go('/designers'),
          ),
        ],
      ),
      body: ListPageLayout(
        search: SearchField(
          value: query.search,
          hint: 'Поиск по названию или штрихкоду',
          onChanged: (value) => _go(query.copyWith(search: value)),
        ),
        filters: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterDropdown<int>(
              label: 'Жанр',
              value: query.genreId,
              options: {for (final g in refs.genres) g.id: g.name},
              onChanged: (v) => _go(query.copyWith(genreId: v)),
            ),
            FilterDropdown<int>(
              label: 'Издатель',
              value: query.publisherId,
              options: {for (final p in refs.publishers) p.id: p.name},
              onChanged: (v) => _go(query.copyWith(publisherId: v)),
            ),
            YearRangeFields(
              from: query.yearFrom,
              to: query.yearTo,
              onChanged: (from, to) =>
                  _go(query.copyWith(yearFrom: from, yearTo: to)),
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
        activeFilterCount: _activeFilters(query),
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
          onPageChanged: (p) => _go(query.copyWith(page: p)),
          onSizeChanged: (s) => _go(query.copyWith(size: s)),
        ),
      ),
    );
  }
}
