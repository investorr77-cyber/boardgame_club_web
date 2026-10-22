import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Боковое меню: переходы между разделами.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.current});

  /// Путь текущего раздела, например '/games'.
  final String current;

  static const _items = [
    ('/', 'Главная', Icons.home_outlined),
    ('/games', 'Игры', Icons.casino_outlined),
    ('/designers', 'Авторы', Icons.person_outline),
    ('/genres', 'Жанры', Icons.category_outlined),
    ('/publishers', 'Издатели', Icons.business_outlined),
    ('/members', 'Участники клуба', Icons.badge_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _items.indexWhere((item) => item.$1 == current);
    return NavigationDrawer(
      selectedIndex: index == -1 ? null : index,
      onDestinationSelected: (i) {
        Scaffold.of(context).closeDrawer();
        context.go(_items[i].$1);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 12),
          child: Text('Клуб настольных игр',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final item in _items)
          NavigationDrawerDestination(
            icon: Icon(item.$3),
            label: Text(item.$2),
          ),
      ],
    );
  }
}
