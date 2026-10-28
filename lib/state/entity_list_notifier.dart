import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../repositories/repository_exception.dart';
import 'data_changes.dart';
import 'load_status.dart';

/// Общая логика списка для всех пяти сущностей: query, result, status, error,
/// выделение и операции удаления. Наследники только связывают её с репозиторием.
abstract class EntityListNotifier<T, Q> extends ChangeNotifier {
  EntityListNotifier(this._query, {DataChanges? changes}) : _changes = changes {
    _changes?.addListener(_onDataChanged);
  }

  final DataChanges? _changes;
  Q _query;
  PageResult<T> _result = PageResult<T>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = <int>{};
  int _loadToken = 0;

  Q get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);

  bool get isAllOnPageSelected =>
      _result.items.isNotEmpty &&
      _result.items.every((item) => _selected.contains(idOf(item)));

  @protected
  Future<PageResult<T>> fetch(Q query);
  @protected
  int idOf(T item);
  @protected
  int pageOf(Q query);
  @protected
  Q withPage(Q query, int page);
  @protected
  Future<int> deleteManyInRepository(List<int> ids);
  @protected
  Future<void> softDeleteInRepository(int id);
  @protected
  Future<void> hardDeleteInRepository(int id);
  @protected
  Future<void> restoreInRepository(int id);

  /// Проверка перед удалением. Бросает [OperationRefused], если удалять нельзя
  /// (например, на издателя ссылаются игры).
  @protected
  Future<void> checkCanDelete(List<int> ids) async {}

  void _onDataChanged() {
    if (_changes!.source != this && _status != LoadStatus.idle) load();
  }

  @override
  void dispose() {
    _changes?.removeListener(_onDataChanged);
    super.dispose();
  }

  /// notifyListeners() до и после запроса: иначе индикатор загрузки не исчезнет.
  Future<void> load() async {
    final token = ++_loadToken;
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final result = await fetch(_query);
      if (token != _loadToken) return; // ответ на устаревший запрос
      _result = result;
      _status = LoadStatus.success;
    } catch (e) {
      if (token != _loadToken) return;
      _error = e.toString();
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Пропускает одинаковый query, очищает выделение и перезагружает список.
  Future<void> applyQuery(Q next) async {
    if (next == _query && _status != LoadStatus.idle) return;
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(int id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void toggleSelectAllOnPage() {
    final ids = _result.items.map(idOf);
    if (isAllOnPageSelected) {
      _selected.removeAll(ids);
    } else {
      _selected.addAll(ids);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  /// Логическое удаление выбранных. [refusal] — причина отказа, если удалять нельзя.
  Future<({int count, String? refusal})> deleteSelected() async {
    if (_selected.isEmpty) return (count: 0, refusal: null);
    final ids = _selected.toList();
    final outcome = await _mutate(() async {
      await checkCanDelete(ids);
      return deleteManyInRepository(ids);
    }, ids);
    return (count: outcome.value ?? 0, refusal: outcome.refusal);
  }

  /// Возвращает причину отказа или null при успехе.
  Future<String?> softDelete(int id) async => (await _mutate(() async {
        await checkCanDelete([id]);
        await softDeleteInRepository(id);
        return true;
      }, [id]))
          .refusal;

  Future<String?> hardDelete(int id) async => (await _mutate(() async {
        await checkCanDelete([id]);
        await hardDeleteInRepository(id);
        return true;
      }, [id]))
          .refusal;

  Future<String?> restore(int id) async => (await _mutate(() async {
        await restoreInRepository(id);
        return true;
      }, [id]))
          .refusal;

  Future<({R? value, String? refusal})> _mutate<R>(
      Future<R> Function() action, List<int> ids) async {
    try {
      final value = await action();
      _selected.removeAll(ids);
      await _reloadAfterMutation();
      _changes?.bump(this);
      return (value: value, refusal: null);
    } on OperationRefused catch (e) {
      return (value: null, refusal: e.message);
    } on ConflictException catch (e) {
      // 409 от сервера: на запись ссылаются другие — показываем как отказ.
      return (value: null, refusal: e.message);
    } on ForbiddenException catch (e) {
      // 403: роль не позволяет — сообщение, а не сломанный список.
      return (value: null, refusal: e.message);
    } catch (e) {
      _error = e.toString();
      _status = LoadStatus.error;
      notifyListeners();
      return (value: null, refusal: null);
    }
  }

  /// После удаления список перезапрашивается. Если текущая страница опустела
  /// и она не первая — переходим на предыдущую.
  Future<void> _reloadAfterMutation() async {
    await load();
    final page = pageOf(_query);
    if (_status == LoadStatus.success && _result.items.isEmpty && page > 1) {
      final last = _result.totalPages;
      _query = withPage(_query, page - 1 < last ? page - 1 : last);
      await load();
    }
  }
}
