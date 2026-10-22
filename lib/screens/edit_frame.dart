import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/edit_notifiers.dart';
import '../state/load_status.dart';
import '../state/reference_notifier.dart';
import '../widgets/state_views.dart';

/// Обёртка экрана формы: один экран на создание (`/games/new`)
/// и изменение (`/games/5/edit`). При изменении форма строится только
/// после загрузки записи, иначе поля остались бы пустыми.
class EditFrame<T> extends StatefulWidget {
  const EditFrame({
    super.key,
    required this.idParam,
    required this.title,
    required this.listPath,
    required this.builder,
  });

  /// null — создание; строка из адреса — изменение.
  final String? idParam;
  final String title;
  final String listPath;
  final Widget Function(BuildContext context, T? item) builder;

  @override
  State<EditFrame<T>> createState() => _EditFrameState<T>();
}

class _EditFrameState<T> extends State<EditFrame<T>> {
  bool _started = false;

  bool get _isEditing => widget.idParam != null;

  int? get _id => widget.idParam == null ? null : int.tryParse(widget.idParam!);

  @override
  void initState() {
    super.initState();
    final id = _id;
    if (_isEditing && id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _started = true;
        context.read<EntityEditNotifier<T>>().load(id);
      });
    }
  }

  Widget _frame(Widget body) => Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(widget.listPath),
          ),
          title: Text(widget.title),
        ),
        body: body,
      );

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceNotifier>();
    // Выпадающие списки заполняются из репозиториев — ждём их загрузки.
    if (!refs.loaded) return _frame(const LoadingView());
    if (!_isEditing) return widget.builder(context, null);

    final id = _id;
    if (id == null) {
      return _frame(MessageView(
        icon: Icons.search_off,
        title: 'Запись не найдена',
        message: 'Некорректный идентификатор «${widget.idParam}»: ожидается число.',
      ));
    }
    final notifier = context.watch<EntityEditNotifier<T>>();
    if (!_started ||
        notifier.requestedId != id ||
        notifier.status == DetailsStatus.idle ||
        notifier.status == DetailsStatus.loading) {
      return _frame(const LoadingView());
    }
    if (notifier.status == DetailsStatus.error) {
      return _frame(ErrorView(
        message: notifier.error ?? 'Неизвестная ошибка',
        onRetry: () => notifier.load(id),
      ));
    }
    final item = notifier.item;
    if (item == null) {
      return _frame(MessageView(
        icon: Icons.search_off,
        title: 'Запись не найдена',
        message: 'Записи с id $id нет.',
        action: FilledButton(
          onPressed: () => context.go(widget.listPath),
          child: const Text('К списку'),
        ),
      ));
    }
    return widget.builder(context, item);
  }
}

/// Уход с формы: после создания — в карточку новой записи, иначе назад.
void closeForm(
  BuildContext context, {
  required bool saved,
  required String listPath,
  int? savedId,
  required bool created,
}) {
  if (saved) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(created ? 'Запись создана' : 'Изменения сохранены')),
    );
  }
  if (saved && created && savedId != null) {
    context.go('$listPath/$savedId');
  } else if (context.canPop()) {
    context.pop();
  } else {
    context.go(saved && savedId != null ? '$listPath/$savedId' : listPath);
  }
}
