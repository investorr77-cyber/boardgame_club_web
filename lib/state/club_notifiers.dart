import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/loan.dart';
import '../repositories/api/club_api.dart';
import 'data_changes.dart';
import 'load_status.dart';

/// Общая часть простых экранов ПР5: загрузка, статус, ошибка.
abstract class LoadingNotifier<T> extends ChangeNotifier {
  LoadStatus _status = LoadStatus.idle;
  T? _data;
  String? _error;
  bool _busy = false;

  LoadStatus get status => _status;
  T? get data => _data;
  String? get error => _error;

  /// Идёт операция: кнопки заблокированы от повторного нажатия.
  bool get busy => _busy;

  @protected
  Future<T> fetch();

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _data = await fetch();
      _status = LoadStatus.success;
    } catch (e) {
      _error = e.toString();
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Выполняет операцию и перезагружает данные. Возвращает текст для
  /// пользователя: ошибку сервера (403, 409 …) или [success].
  @protected
  Future<String> run(Future<void> Function() action, String success) async {
    if (_busy) return '';
    _busy = true;
    notifyListeners();
    try {
      await action();
      await load();
      return success;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

/// «Мои выдачи» участника.
class MyLoansNotifier extends LoadingNotifier<List<Loan>> {
  MyLoansNotifier(this._api);

  final LoanApi _api;

  @override
  Future<List<Loan>> fetch() => _api.mine();

  Future<String> extend(Loan loan) => run(
      () => _api.extend(loan.id), 'Срок «${loan.gameTitle}» продлён на неделю');
}

/// Выдачи клуба: оформление и закрытие (сотрудник).
class LoansNotifier extends LoadingNotifier<List<Loan>> {
  LoansNotifier(this._api, {DataChanges? changes}) : _changes = changes;

  final LoanApi _api;
  final DataChanges? _changes;
  bool activeOnly = true;

  @override
  Future<List<Loan>> fetch() => _api.all(activeOnly: activeOnly);

  void setActiveOnly(bool value) {
    activeOnly = value;
    load();
  }

  Future<String> close(Loan loan) => run(() async {
        await _api.close(loan.id);
        _changes?.bump(this); // число свободных коробок изменилось
      }, 'Выдача «${loan.gameTitle}» закрыта');

  Future<List<AppUser>> readers() => _api.readers();

  Future<String> issue(
          {required int gameId, required int userId, required String title}) =>
      run(() async {
        await _api.issue(gameId: gameId, userId: userId);
        _changes?.bump(this);
      }, 'Игра «$title» выдана');
}

/// Пользователи и роли (администратор).
class UsersNotifier extends LoadingNotifier<List<AppUser>> {
  UsersNotifier(this._api);

  final AdminApi _api;

  @override
  Future<List<AppUser>> fetch() => _api.users();

  Future<String> setRole(AppUser user, Role role) => run(
      () => _api.setRole(user.id, role), '${user.name}: роль «${role.title}»');
}

/// Статистика клуба (администратор).
class StatsNotifier extends LoadingNotifier<Map<String, Object?>> {
  StatsNotifier(this._api);

  final AdminApi _api;

  @override
  Future<Map<String, Object?>> fetch() => _api.stats();
}
