import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Главная: переход к играм и авторам.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Клуб настольных игр')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.extension, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Каталог клуба',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Игры и авторы: поиск, фильтры, сортировка и пагинация.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/games'),
                  icon: const Icon(Icons.casino_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Игры'),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => context.go('/designers'),
                  icon: const Icon(Icons.people_outline),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Авторы'),
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
