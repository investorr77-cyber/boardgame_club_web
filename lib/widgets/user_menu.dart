import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';

/// Имя и роль пользователя в шапке, меню с выходом.
class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return PopupMenuButton<String>(
      tooltip: '${user.name} — ${user.role.title}',
      onSelected: (value) {
        if (value == 'logout') auth.logout();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(user.name),
            subtitle: Text('${user.username} · ${user.role.title}'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Выйти'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              child: Text(user.name.isEmpty ? '?' : user.name[0]),
            ),
            if (wide) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: Theme.of(context).textTheme.labelLarge),
                  Text(user.role.title, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
