import 'package:flutter/foundation.dart';

import '../models/page_result.dart';
import 'load_status.dart';

/// Общая логика списка для игр и авторов: query, result, status, error,
/// выделение и операции удаления. Наследники только связывают её с репозиторием.
abstract class EntityListNotifier<T, Q> extends ChangeNotifier {
  EntityListNotifier(this._query);

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

  /// Логическое удаление выбранных. Возвращает число реально удалённых.
  Future<int> deleteSelected() async {
    if (_selected.isEmpty) return 0;
    final ids = _selected.toList();
    final count = await _mutate(() => deleteManyInRepository(ids), ids);
    return count ?? 0;
  }

  Future<void> softDelete(int id) => _mutate(() => softDeleteInRepository(id), [id]);

  Future<void> hardDelete(int id) => _mutate(() => hardDeleteInRepository(id), [id]);

  Future<void> restore(int id) => _mutate(() => restoreInRepository(id), [id]);

  Future<R?> _mutate<R>(Future<R> Function() action, List<int> ids) async {
    try {
      final value = await action();
      _selected.removeAll(ids);
      await _reloadAfterMutation();
      return value;
    } catch (e) {
      _error = e.toString();
      _status = LoadStatus.error;
      notifyListeners();
      return null;
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
