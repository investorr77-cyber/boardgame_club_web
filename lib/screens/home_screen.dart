import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/reference_notifier.dart';
import '../state/storage_notifier.dart';
import '../widgets/app_drawer.dart';
import '../widgets/confirm_dialog.dart';

/// Главная: пять разделов каталога, сообщения о хранилище и сброс данных.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _reset(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Вернуть начальный набор?',
      message: 'Все созданные и изменённые записи будут стёрты из хранилища '
          'браузера, вернутся исходные 30 игр, 12 авторов, 7 жанров, '
          '6 издателей и 12 участников. Это действие необратимо.',
      confirmLabel: 'Сбросить',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await context.read<StorageNotifier>().resetAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные возвращены к начальному набору')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final refs = context.watch<ReferenceNotifier>();
    final storage = context.watch<StorageNotifier>();
    final sections = [
      ('/games', 'Игры', Icons.casino_outlined, refs.games),
      ('/designers', 'Авторы', Icons.person_outline, refs.designers),
      ('/genres', 'Жанры', Icons.category_outlined, refs.genres),
      ('/publishers', 'Издатели', Icons.business_outlined, refs.publishers),
      ('/members', 'Участники клуба', Icons.badge_outlined, refs.members),
    ];
    return Scaffold(
      drawer: const AppDrawer(current: '/'),
      appBar: AppBar(title: const Text('Клуб настольных игр')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final notice in storage.notices)
                  Card(
                    color: theme.colorScheme.tertiaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(notice),
                      trailing: IconButton(
                        tooltip: 'Скрыть',
                        icon: const Icon(Icons.close),
                        onPressed: storage.dismissNotices,
                      ),
                    ),
                  ),
                Icon(Icons.extension, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('Каталог клуба',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                  'Пять разделов со связями. Изменения сохраняются в браузере '
                  'и переживают перезагрузку страницы.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final (path, title, icon, items) in sections)
                      SizedBox(
                        width: 220,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => context.go(path),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(icon, size: 36, color: theme.colorScheme.primary),
                                  const SizedBox(height: 8),
                                  Text(title, style: theme.textTheme.titleMedium),
                                  Text(refs.loaded ? 'Записей: ${items.length}' : '…',
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _reset(context),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Вернуть начальный набор данных'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
