import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/designer_details_notifier.dart';
import '../state/load_status.dart';
import '../widgets/muted_badge.dart';
import '../widgets/state_views.dart';

/// Карточка автора со списком его игр.
class DesignerDetailsScreen extends StatefulWidget {
  const DesignerDetailsScreen({super.key, required this.idParam});

  final String idParam;

  @override
  State<DesignerDetailsScreen> createState() => _DesignerDetailsScreenState();
}

class _DesignerDetailsScreenState extends State<DesignerDetailsScreen> {
  int? get _id => int.tryParse(widget.idParam);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DesignerDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idParam != widget.idParam) _load();
  }

  void _load() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DesignerDetailsNotifier>().load(_id);
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/designers');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DesignerDetailsNotifier>();
    final stale = notifier.requestedId != _id;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: Text(!stale && notifier.designer != null
            ? notifier.designer!.fullName
            : 'Автор'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _buildBody(notifier, stale),
        ),
      ),
    );
  }

  Widget _buildBody(DesignerDetailsNotifier notifier, bool stale) {
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
    final designer = notifier.designer;
    if (notifier.status == DetailsStatus.notFound || designer == null) {
      return MessageView(
        icon: Icons.person_search,
        title: 'Автор не найден',
        message: _id == null
            ? 'Некорректный идентификатор «${widget.idParam}»: ожидается число.'
            : 'Автора с id $_id нет в каталоге.',
        action: FilledButton.icon(
          onPressed: () => context.go('/designers'),
          icon: const Icon(Icons.list),
          label: const Text('К списку авторов'),
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
            Text(designer.fullName, style: theme.textTheme.headlineSmall),
            if (designer.isDeleted) const MutedBadge(),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow('Фамилия', designer.lastName),
                _InfoRow('Имя', designer.firstName),
                _InfoRow('Страна', designer.country),
                _InfoRow('Год рождения', '${designer.birthYear}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Игры автора (${notifier.games.length})',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (notifier.games.isEmpty)
          const Text('В каталоге нет игр этого автора.')
        else
          Card(
            child: Column(
              children: [
                for (final game in notifier.games)
                  ListTile(
                    leading: const Icon(Icons.casino_outlined),
                    title: Text(game.title),
                    subtitle: Text('${game.year} · ${game.playTimeMin} мин'),
                    trailing: game.isDeleted
                        ? const MutedBadge(label: 'удалена')
                        : const Icon(Icons.chevron_right),
                    onTap: () => context.push('/games/${game.id}'),
                  ),
              ],
            ),
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
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
