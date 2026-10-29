import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../state/auth_notifier.dart';
import '../widgets/form/validators.dart';
import '../widgets/state_views.dart';

/// Каркас экранов входа и регистрации: карточка по центру, ширина ограничена.
class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.extension,
                        size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text('Клуб настольных игр',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 20),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Баннер с ошибкой входа или причиной завершения сессии.
class _Banner extends StatelessWidget {
  const _Banner(this.text, {this.error = true});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.info_outline,
              color: error
                  ? scheme.onErrorContainer
                  : scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Вход. [from] — адрес, с которого пользователя отправили на вход:
/// после входа он вернётся именно туда.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.from});

  final String? from;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthNotifier>().login(_username.text, _password.text);
      if (!mounted) return;
      // Маршрутизатор сам уведёт с экрана входа; возвращаем на исходный адрес.
      context.go(_safeTarget(widget.from));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = context.watch<AuthNotifier>().logoutReason;
    return _AuthFrame(
      title: 'Вход',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              _Banner(_error!)
            else if (reason != null)
              _Banner(reason, error: false),
            TextFormField(
              controller: _username,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Логин',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: notEmpty('Введите логин'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Пароль',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
                  icon:
                      Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: notEmpty('Введите пароль'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Войти'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(widget.from == null
                  ? '/register'
                  : '/register?from=${Uri.encodeComponent(widget.from!)}'),
              child: const Text('Нет аккаунта? Зарегистрироваться'),
            ),
            const SizedBox(height: 8),
            Text(
              'Учебные учётные записи: reader / Reader123! (участник), '
              'staff / Staff123! (сотрудник), admin / Admin123! (администратор).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Регистрация. Пароль проверяется по мере ввода, а не только по нажатию кнопки.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.from});

  final String? from;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, String> _serverErrors = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_username, _name, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  FormFieldValidator<String> _withServer(
          String field, FormFieldValidator<String> v) =>
      (value) => _serverErrors[field] ?? v(value);

  Future<void> _submit() async {
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthNotifier>().register(
            username: _username.text,
            name: _name.text,
            password: _password.text,
          );
      if (mounted) context.go(_safeTarget(widget.from));
    } on ValidationException catch (e) {
      // 422: например, логин уже занят — ошибка под своим полем.
      setState(() => _serverErrors = e.errors);
      _formKey.currentState!.validate();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final password = _password.text;
    final scheme = Theme.of(context).colorScheme;
    return _AuthFrame(
      title: 'Регистрация',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) _Banner(_error!),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'Логин',
                helperText: 'Латинские буквы, цифры и _',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _serverErrors.remove('username'),
              validator: _withServer('username', all([notEmpty(), username()])),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Имя и фамилия',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              validator: _withServer(
                  'name', all([notEmpty(), minLength(2), maxLength(60)])),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: true,
              onChanged: (_) =>
                  setState(() {}), // перерисовать список требований
              decoration: const InputDecoration(
                labelText: 'Пароль',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              validator: _withServer('password', strongPassword()),
            ),
            const SizedBox(height: 8),
            for (final (label, ok) in passwordRules)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      ok(password)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: ok(password) ? Colors.green : scheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Пароль ещё раз',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v != _password.text ? 'Пароли не совпадают' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Зарегистрироваться'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Уже есть аккаунт? Войти'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Адрес возврата после входа: только внутренний путь приложения.
String _safeTarget(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return '/';
  }
  if (from.startsWith('/login') || from.startsWith('/register')) return '/';
  return from;
}

/// Экран отказа: адрес есть, но текущей роли он недоступен.
class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key, this.from});

  final String? from;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthNotifier>().role;
    return Scaffold(
      appBar: AppBar(title: const Text('Доступ запрещён')),
      body: MessageView(
        icon: Icons.lock_person_outlined,
        color: Theme.of(context).colorScheme.error,
        title: 'Недостаточно прав',
        message: 'Раздел ${from == null ? '' : '«$from» '}недоступен для роли '
            '«${role?.title ?? 'гость'}».',
        action: FilledButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('На главную'),
        ),
      ),
    );
  }
}
