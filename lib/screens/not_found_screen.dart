import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/state_views.dart';

/// Экран 404 для несуществующего адреса (например, /qwerty).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('404')),
      body: MessageView(
        icon: Icons.explore_off,
        title: 'Страница не найдена',
        message: 'Адреса «$location» в приложении нет.',
        action: FilledButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('На главную'),
        ),
      ),
    );
  }
}
