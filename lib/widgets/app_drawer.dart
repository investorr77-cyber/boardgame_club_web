import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/permissions.dart';
import '../state/auth_notifier.dart';

/// Боковое меню. Разделы, недоступные роли, не показываются —
/// а если открыть их адрес вручную, маршрутизатор отправит на экран отказа.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.current});

  /// Путь текущего раздела, например '/games'.
  final String current;

  static const _items = [
    ('/', 'Главная', Icons.home_outlined, Operation.viewCatalog),
    ('/games', 'Игры', Icons.casino_outlined, Operation.viewCatalog),
    ('/designers', 'Авторы', Icons.person_outline, Operation.viewCatalog),
    ('/genres', 'Жанры', Icons.category_outlined, Operation.viewCatalog),
    ('/publishers', 'Издатели', Icons.business_outlined, Operation.viewCatalog),
    ('/my-loans', 'Мои выдачи', Icons.bookmark_outline, Operation.viewOwnLoans),
    (
      '/members',
      'Участники клуба',
      Icons.badge_outlined,
      Operation.viewMembers
    ),
    ('/loans', 'Выдачи', Icons.outbox_outlined, Operation.issueLoans),
    (
      '/admin/users',
      'Пользователи и роли',
      Icons.manage_accounts_outlined,
      Operation.manageUsers
    ),
    (
      '/admin/stats',
      'Статистика',
      Icons.insights_outlined,
      Operation.viewStats
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final items = [
      for (final item in _items)
        if (auth.can(item.$4)) item
    ];
    final index = items.indexWhere((item) => item.$1 == current);
    final user = auth.user;
    return NavigationDrawer(
      selectedIndex: index == -1 ? null : index,
      onDestinationSelected: (i) {
        Scaffold.of(context).closeDrawer();
        context.go(items[i].$1);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Клуб настольных игр',
                  style: Theme.of(context).textTheme.titleMedium),
              if (user != null)
                Text('${user.name} · ${user.role.title}',
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        for (final item in items)
          NavigationDrawerDestination(
              icon: Icon(item.$3), label: Text(item.$2)),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextButton.icon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Выйти'),
          ),
        ),
      ],
    );
  }
}
