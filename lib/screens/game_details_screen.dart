import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/game_details_notifier.dart';
import '../state/load_status.dart';
import '../state/reference_notifier.dart';
import '../widgets/muted_badge.dart';
import '../widgets/state_views.dart';

/// Карточка игры. [idParam] — строка из адреса, может быть нечисловой.
class GameDetailsScreen extends StatefulWidget {
  const GameDetailsScreen({super.key, required this.idParam});

  final String idParam;

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  int? get _id => int.tryParse(widget.idParam);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GameDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idParam != widget.idParam) _load();
  }

  void _load() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GameDetailsNotifier>().load(_id);
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/games');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<GameDetailsNotifier>();
    final refs = context.watch<ReferenceNotifier>();
    final stale = notifier.requestedId != _id;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: Text(
            !stale && notifier.game != null ? notifier.game!.title : 'Игра'),
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
      GameDetailsNotifier notifier, ReferenceNotifier refs, bool stale) {
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
    final game = notifier.game;
    if (notifier.status == DetailsStatus.notFound || game == null) {
      return MessageView(
        icon: Icons.search_off,
        title: 'Игра не найдена',
        message: _id == null
            ? 'Некорректный идентификатор «${widget.idParam}»: ожидается число.'
            : 'Игры с id $_id нет в каталоге.',
        action: FilledButton.icon(
          onPressed: () => context.go('/games'),
          icon: const Icon(Icons.list),
          label: const Text('К списку игр'),
        ),
      );
    }

    final theme = Theme.of(context);
    final players = game.minPlayers == game.maxPlayers
        ? '${game.minPlayers}'
        : '${game.minPlayers}–${game.maxPlayers}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(game.title, style: theme.textTheme.headlineSmall),
            if (game.isDeleted) const MutedBadge(label: 'удалена'),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow('Штрихкод (EAN-13)', game.barcode),
                _InfoRow('Год издания', '${game.year}'),
                _InfoRow('Время партии', '${game.playTimeMin} мин'),
                _InfoRow('Игроков', players),
                _InfoRow('Издатель', refs.publisherName(game.publisherId)),
                _InfoRow('Коробок в клубе', '${game.copiesTotal}'),
                _InfoRow('Свободно', '${game.copiesAvailable}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Жанры', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in game.genreIds) Chip(label: Text(refs.genreName(id))),
          ],
        ),
        const SizedBox(height: 16),
        Text('Авторы', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in notifier.designers)
              ActionChip(
                avatar: const Icon(Icons.person_outline, size: 18),
                label: Text(d.fullName),
                onPressed: () => context.push('/designers/${d.id}'),
              ),
          ],
        ),
      ],
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
            width: 160,
            child: Text(label,
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
