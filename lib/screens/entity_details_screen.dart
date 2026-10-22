import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/board_game.dart';
import '../state/details_notifiers.dart';
import '../state/load_status.dart';
import '../state/reference_notifier.dart';
import '../widgets/muted_badge.dart';
import '../widgets/state_views.dart';

/// Блок строк «название — значение» в карточке.
class DetailsSection {
  const DetailsSection({this.title, required this.rows});

  final String? title;
  final List<(String, String)> rows;
}

/// Всё, чем карточки пяти сущностей отличаются друг от друга.
class EntityDetailsConfig<T> {
  const EntityDetailsConfig({
    required this.path,
    required this.entityTitle,
    required this.titleOf,
    required this.isDeleted,
    required this.sections,
    this.relatedTitle,
    this.extra,
  });

  final String path;

  /// «Игра», «Автор» — заголовок, пока запись не загружена, и текст «не найдено».
  final String entityTitle;
  final String Function(T item) titleOf;
  final bool Function(T item) isDeleted;
  final List<DetailsSection> Function(T item, ReferenceNotifier refs) sections;

  /// Заголовок списка связанных игр; null — список не показывается.
  final String? relatedTitle;

  /// Дополнительные блоки (жанры и авторы игры).
  final List<Widget> Function(BuildContext context, T item,
      EntityDetailsNotifier<T> notifier, ReferenceNotifier refs)? extra;
}

/// Карточка любой сущности. [idParam] — строка из адреса, может быть нечисловой.
class EntityDetailsScreen<T> extends StatefulWidget {
  const EntityDetailsScreen({super.key, required this.config, required this.idParam});

  final EntityDetailsConfig<T> config;
  final String idParam;

  @override
  State<EntityDetailsScreen<T>> createState() => _EntityDetailsScreenState<T>();
}

class _EntityDetailsScreenState<T> extends State<EntityDetailsScreen<T>> {
  int? get _id => int.tryParse(widget.idParam);

  EntityDetailsConfig<T> get _config => widget.config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EntityDetailsScreen<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idParam != widget.idParam) _load();
  }

  void _load() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EntityDetailsNotifier<T>>().load(_id);
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(_config.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<EntityDetailsNotifier<T>>();
    final refs = context.watch<ReferenceNotifier>();
    final stale = notifier.requestedId != _id;
    final item = stale ? null : notifier.item;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: Text(item != null ? _config.titleOf(item) : _config.entityTitle),
        actions: [
          if (item != null && !_config.isDeleted(item))
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('${_config.path}/$_id/edit'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _buildBody(notifier, refs, stale),
        ),
      ),
    );
  }

  Widget _buildBody(
      EntityDetailsNotifier<T> notifier, ReferenceNotifier refs, bool stale) {
    if (stale ||
        notifier.status == DetailsStatus.idle ||
        notifier.status == DetailsStatus.loading) {
      return const LoadingView();
    }
    if (notifier.status == DetailsStatus.error) {
      return ErrorView(
        message: notifier.error ?? 'Неизвестная ошибка',
        onRetry: () => notifier.load(_id),
      );
    }
    final item = notifier.item;
    if (notifier.status == DetailsStatus.notFound || item == null) {
      return MessageView(
        icon: Icons.search_off,
        title: '${_config.entityTitle}: запись не найдена',
        message: _id == null
            ? 'Некорректный идентификатор «${widget.idParam}»: ожидается число.'
            : 'Записи с id $_id нет.',
        action: FilledButton.icon(
          onPressed: () => context.go(_config.path),
          icon: const Icon(Icons.list),
          label: const Text('К списку'),
        ),
      );
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_config.titleOf(item), style: theme.textTheme.headlineSmall),
            if (_config.isDeleted(item)) const MutedBadge(),
          ],
        ),
        const SizedBox(height: 16),
        for (final section in _config.sections(item, refs))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (section.title != null) ...[
                    Text(section.title!, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                  ],
                  for (final (label, value) in section.rows) _InfoRow(label, value),
                ],
              ),
            ),
          ),
        if (_config.extra != null) ..._config.extra!(context, item, notifier, refs),
        if (_config.relatedTitle != null) ...[
          const SizedBox(height: 16),
          Text('${_config.relatedTitle} (${notifier.games.length})',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (notifier.games.isEmpty)
            const Text('Связанных игр нет.')
          else
            Card(
              child: Column(
                children: [
                  for (final game in notifier.games) _GameTile(game),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile(this.game);

  final BoardGame game;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.casino_outlined),
      title: Text(game.title),
      subtitle: Text('${game.year} · ${game.playTimeMin} мин'),
      trailing: game.isDeleted
          ? const MutedBadge(label: 'удалена')
          : const Icon(Icons.chevron_right),
      onTap: () => context.push('/games/${game.id}'),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label,
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ),
          Expanded(child: SelectableText(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}
