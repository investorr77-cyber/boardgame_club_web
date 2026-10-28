import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/permissions.dart';
import '../state/auth_notifier.dart';
import '../state/reference_notifier.dart';
import '../state/storage_notifier.dart';
import '../widgets/app_drawer.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/user_menu.dart';

/// Главная. Набор разделов зависит от роли: у каждой роли свой экран,
/// недоступный остальным.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _reset(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Вернуть начальный набор?',
      message: 'Все созданные и изменённые записи будут стёрты на сервере, '
          'вернутся исходные данные. Это действие необратимо.',
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
    final auth = context.watch<AuthNotifier>();
    final refs = context.watch<ReferenceNotifier>();
    final user = auth.user;
    String count(List<Object?> items) => refs.loaded ? 'Записей: ${items.length}' : '…';
    final sections = [
      ('/games', 'Игры', Icons.casino_outlined, count(refs.games), Operation.viewCatalog),
      ('/designers', 'Авторы', Icons.person_outline, count(refs.designers), Operation.viewCatalog),
      ('/genres', 'Жанры', Icons.category_outlined, count(refs.genres), Operation.viewCatalog),
      ('/publishers', 'Издатели', Icons.business_outlined, count(refs.publishers), Operation.viewCatalog),
      ('/my-loans', 'Мои выдачи', Icons.bookmark_outline, 'Продление срока', Operation.viewOwnLoans),
      ('/members', 'Участники клуба', Icons.badge_outlined, count(refs.members), Operation.viewMembers),
      ('/loans', 'Выдачи', Icons.outbox_outlined, 'Оформление и закрытие', Operation.issueLoans),
      ('/admin/users', 'Пользователи и роли', Icons.manage_accounts_outlined, 'Назначение ролей', Operation.manageUsers),
      ('/admin/stats', 'Статистика', Icons.insights_outlined, 'Сводка по клубу', Operation.viewStats),
    ];
    final roleHint = switch (user?.role) {
      null => '',
      _ when auth.can(Operation.viewOwnLoans) =>
        'Каталог клуба и ваши выдачи: срок можно продлить.',
      _ when auth.can(Operation.issueLoans) =>
        'Управление каталогом и справочниками, выдачи, участники клуба.',
      _ => 'Пользователи и роли, восстановление и физическое удаление записей, статистика.',
    };
    return Scaffold(
      drawer: const AppDrawer(current: '/'),
      appBar: AppBar(title: const Text('Клуб настольных игр'), actions: const [UserMenu()]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.extension, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('Здравствуйте, ${user?.name ?? 'гость'}!',
                    textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('Роль: ${user?.role.title ?? '—'}',
                    textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(roleHint, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final (path, title, icon, subtitle, op) in sections)
                      if (auth.can(op))
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
                                    Text(title,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.titleMedium),
                                    Text(subtitle, style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
                if (auth.can(Operation.manageUsers)) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _reset(context),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Вернуть начальный набор данных'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
