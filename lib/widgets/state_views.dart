import 'package:flutter/material.dart';

/// Состояние «загрузка».
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Загрузка…'),
        ],
      ),
    );
  }
}

/// Сообщение с иконкой и кнопкой; основа для пустого результата, ошибки и 404.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.color,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color? color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.outline;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: tint),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: color ?? theme.colorScheme.onSurface),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, textAlign: TextAlign.center),
              ],
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Состояние «пустой результат»: серая иконка и сброс фильтров.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return MessageView(
      icon: Icons.search_off,
      title: 'Ничего не найдено',
      message: 'Измените условия поиска или сбросьте фильтры.',
      action: FilledButton.tonalIcon(
        onPressed: onReset,
        icon: const Icon(Icons.filter_alt_off),
        label: const Text('Сбросить фильтры'),
      ),
    );
  }
}

/// Состояние «ошибка»: красная иконка, текст ошибки и повтор.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MessageView(
      icon: Icons.error_outline,
      color: Theme.of(context).colorScheme.error,
      title: 'Не удалось загрузить данные',
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Повторить'),
      ),
    );
  }
}
