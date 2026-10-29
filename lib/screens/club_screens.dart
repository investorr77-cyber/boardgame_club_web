import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/loan.dart';
import '../state/auth_notifier.dart';
import '../state/club_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/app_drawer.dart';
import '../widgets/state_views.dart';
import '../widgets/user_menu.dart';

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

void _say(BuildContext context, String message) {
  if (message.isEmpty || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Каркас экранов ПР5: меню, шапка с пользователем, ограничение ширины.
class _Page extends StatelessWidget {
  const _Page(
      {required this.path,
      required this.title,
      required this.body,
      this.actions = const []});

  final String path;
  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(current: path),
      appBar:
          AppBar(title: Text(title), actions: [...actions, const UserMenu()]),
      body: Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960), child: body),
      ),
    );
  }
}

/// Загрузка / ошибка / пусто / данные — для простых экранов.
Widget _states<T>(LoadingNotifier<T> n,
    {required bool isEmpty, required Widget Function(T data) data}) {
  if (n.status == LoadStatus.error) {
    return ErrorView(message: n.error ?? 'Неизвестная ошибка', onRetry: n.load);
  }
  final value = n.data;
  if (value == null) return const LoadingView();
  if (isEmpty) {
    return const MessageView(
        icon: Icons.inbox_outlined, title: 'Пока ничего нет');
  }
  return data(value);
}

class _LoanTile extends StatelessWidget {
  const _LoanTile({required this.loan, this.showUser = false, this.action});

  final Loan loan;
  final bool showUser;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = !loan.isActive
        ? 'возвращена ${_date(loan.returnedAt!)}'
        : loan.overdue
            ? 'просрочена с ${_date(loan.dueDate)}'
            : 'вернуть до ${_date(loan.dueDate)}';
    return Card(
      child: ListTile(
        leading: Icon(
          loan.isActive ? Icons.outbox_outlined : Icons.task_alt,
          color: loan.overdue ? scheme.error : null,
        ),
        title: Text(loan.gameTitle),
        subtitle: Text([
          if (showUser) loan.userName,
          'выдана ${_date(loan.issuedAt)}',
          status,
          if (loan.extensions > 0) 'продлений: ${loan.extensions}',
        ].join(' · ')),
        trailing: action,
        onTap: () => context.push('/games/${loan.gameId}'),
      ),
    );
  }
}

/// «Мои выдачи» — только для участника клуба.
class MyLoansScreen extends StatefulWidget {
  const MyLoansScreen({super.key});

  @override
  State<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends State<MyLoansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MyLoansNotifier>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<MyLoansNotifier>();
    return _Page(
      path: '/my-loans',
      title: 'Мои выдачи',
      body: _states<List<Loan>>(n,
          isEmpty: n.data?.isEmpty ?? false,
          data: (loans) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final loan in loans)
                    _LoanTile(
                      loan: loan,
                      action: loan.isActive
                          ? OutlinedButton(
                              onPressed: n.busy
                                  ? null
                                  : () async {
                                      final m = await n.extend(loan);
                                      if (context.mounted) _say(context, m);
                                    },
                              child: const Text('Продлить'),
                            )
                          : null,
                    ),
                ],
              )),
    );
  }
}

/// Выдачи клуба — оформление и закрытие, только для сотрудника.
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LoansNotifier>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<LoansNotifier>();
    return _Page(
      path: '/loans',
      title: 'Выдачи',
      actions: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Только активные'),
          Switch(value: n.activeOnly, onChanged: n.setActiveOnly),
        ]),
      ],
      body: _states<List<Loan>>(n,
          isEmpty: n.data?.isEmpty ?? false,
          data: (loans) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final loan in loans)
                    _LoanTile(
                      loan: loan,
                      showUser: true,
                      action: loan.isActive
                          ? FilledButton.tonal(
                              onPressed: n.busy
                                  ? null
                                  : () async {
                                      final m = await n.close(loan);
                                      if (context.mounted) _say(context, m);
                                    },
                              child: const Text('Закрыть'),
                            )
                          : null,
                    ),
                ],
              )),
    );
  }
}

/// Оформление выдачи с карточки игры (сотрудник): выбор участника.
Future<void> showIssueLoanDialog(BuildContext context,
    {required int gameId, required String title}) async {
  final notifier = context.read<LoansNotifier>();
  List<AppUser> readers;
  try {
    readers = await notifier.readers();
  } catch (e) {
    if (context.mounted) _say(context, '$e');
    return;
  }
  if (!context.mounted) return;
  final reader = await showDialog<AppUser>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('Выдать «$title»'),
      children: [
        for (final r in readers)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(r),
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(r.name),
              subtitle: Text(r.username),
            ),
          ),
      ],
    ),
  );
  if (reader == null || !context.mounted) return;
  final message =
      await notifier.issue(gameId: gameId, userId: reader.id, title: title);
  if (context.mounted) _say(context, message);
}

/// Пользователи и роли — только для администратора.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UsersNotifier>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<UsersNotifier>();
    final me = context.watch<AuthNotifier>().user;
    return _Page(
      path: '/admin/users',
      title: 'Пользователи и роли',
      body: _states<List<AppUser>>(n,
          isEmpty: n.data?.isEmpty ?? false,
          data: (users) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final u in users)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Text(u.name.isEmpty ? '?' : u.name[0])),
                        title: Text(u.name),
                        subtitle: Text(u.username),
                        trailing: DropdownButton<Role>(
                          value: u.role,
                          items: [
                            for (final r in Role.values)
                              DropdownMenuItem(value: r, child: Text(r.title)),
                          ],
                          onChanged: n.busy || u.id == me?.id
                              ? null // роль самому себе не меняют
                              : (r) async {
                                  if (r != null && r != u.role) {
                                    final m = await n.setRole(u, r);
                                    if (context.mounted) _say(context, m);
                                  }
                                },
                        ),
                      ),
                    ),
                ],
              )),
    );
  }
}

/// Статистика клуба — только для администратора.
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StatsNotifier>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<StatsNotifier>();
    return _Page(
      path: '/admin/stats',
      title: 'Статистика клуба',
      actions: [
        IconButton(
            tooltip: 'Обновить',
            onPressed: n.load,
            icon: const Icon(Icons.refresh))
      ],
      body: _states<Map<String, Object?>>(n, isEmpty: false, data: (s) {
        final byRole =
            s['usersByRole'] is Map ? s['usersByRole'] as Map : const {};
        final tiles = [
          ('Игр в каталоге', s['games']),
          (
            'Коробок всего / свободно',
            '${s['copiesTotal']} / ${s['copiesAvailable']}'
          ),
          ('Активных выдач', s['activeLoans']),
          ('Просроченных выдач', s['overdueLoans']),
          ('Авторов', s['designers']),
          ('Жанров', s['genres']),
          ('Издателей', s['publishers']),
          ('Участников клуба', s['members']),
          ('Удалённых записей', s['deletedRecords']),
          ('Пользователей', s['users']),
          for (final r in Role.values)
            ('Роль «${r.title}»', byRole[r.name] ?? 0),
        ];
        return GridView.extent(
          padding: const EdgeInsets.all(16),
          maxCrossAxisExtent: 240,
          childAspectRatio: 1.8,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final (label, value) in tiles)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$value',
                          style: Theme.of(context).textTheme.headlineMedium),
                      Text(label),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
