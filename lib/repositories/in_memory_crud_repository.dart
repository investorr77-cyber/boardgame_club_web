import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/list_query.dart';
import '../models/page_result.dart';
import 'crud_repository.dart';
import 'local_store.dart';
import 'paging.dart';
import 'repository_exception.dart';

/// Общая реализация репозитория: записи в памяти, копия в [LocalStore].
/// Наследник описывает только поиск, сортировку и преобразование в JSON.
/// Без [store] (в тестах) данные живут только в памяти.
abstract class InMemoryCrudRepository<T, Q extends ListQuery>
    implements CrudRepository<T, Q> {
  InMemoryCrudRepository({
    required List<T> Function() seed,
    this.store,
    this.delay = const Duration(milliseconds: 250),
    bool Function()? shouldFail,
  })  : _seed = seed,
        _shouldFail = shouldFail ?? _never {
    _restore();
  }

  final LocalStore? store;

  /// Имитация сетевой задержки.
  final Duration delay;
  final List<T> Function() _seed;

  /// Включённый переключатель «Сымитировать ошибку» заставляет find бросать исключение.
  final bool Function() _shouldFail;

  @protected
  late List<T> items;

  String? _restoreNotice;

  /// Сообщение, если сохранённые данные не удалось прочитать.
  String? get restoreNotice => _restoreNotice;

  static bool _never() => false;

  /// Ключ в хранилище, например `games_v2`.
  @protected
  String get storageKey;

  /// Название набора для сообщений: «Игры».
  @protected
  String get collectionLabel;

  @protected
  String notFound(int id);
  @protected
  int idOf(T item);
  @protected
  T withId(T item, int id);
  @protected
  bool isDeletedItem(T item);
  @protected
  T markDeleted(T item, DateTime at);
  @protected
  T markRestored(T item);
  @protected
  Map<String, dynamic> encode(T item);
  @protected
  T decode(Map<String, dynamic> json);

  /// Поиск и фильтры конкретной сущности.
  @protected
  bool matches(T item, Q query);

  /// Сравнение по полю сортировки (направление учитывается снаружи).
  @protected
  int compareBy(T a, T b, Q query);

  void _restore() {
    final raw = store?.read(storageKey);
    if (raw == null) {
      items = _seed(); // первый запуск — начальный набор
      unawaited(_persist());
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('ожидался список');
      items = [
        for (final entry in decoded) decode(Map<String, dynamic>.from(entry as Map)),
      ];
    } catch (_) {
      // Данные испорчены или формат изменился — начинаем заново,
      // но не роняем приложение.
      items = _seed();
      _restoreNotice = 'Сохранённые данные раздела «$collectionLabel» '
          'не удалось прочитать — восстановлен начальный набор.';
      unawaited(_persist());
    }
  }

  Future<void> _persist() async {
    final s = store;
    if (s == null) return;
    await s.write(storageKey, jsonEncode([for (final item in items) encode(item)]));
  }

  /// Возврат к начальному набору (кнопка на главной).
  Future<void> reset() async {
    items = _seed();
    _restoreNotice = null;
    await _persist();
  }

  @protected
  Future<void> simulateNetwork() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (_shouldFail()) {
      throw const RepositoryException(
          'Сервер не отвечает (сымитированная ошибка сети)');
    }
  }

  @override
  Future<PageResult<T>> find(Q query) async {
    await simulateNetwork();
    final filtered = items
        .where((item) =>
            (query.includeDeleted || !isDeletedItem(item)) &&
            matches(item, query))
        .toList()
      ..sort((a, b) {
        final byField = compareBy(a, b, query);
        final result = byField != 0 ? byField : idOf(a).compareTo(idOf(b));
        return query.sortAscending ? result : -result;
      });
    return paginate(filtered, query.page, query.size);
  }

  @override
  Future<List<T>> findAll({bool includeDeleted = false}) async => [
        for (final item in items)
          if (includeDeleted || !isDeletedItem(item)) item,
      ];

  @override
  Future<T?> findById(int id) async {
    await simulateNetwork();
    for (final item in items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  /// create выдаёт следующий id.
  @override
  Future<T> create(T item) async {
    final nextId =
        items.fold<int>(0, (max, i) => idOf(i) > max ? idOf(i) : max) + 1;
    final created = withId(item, nextId);
    items.add(created);
    await _persist();
    return created;
  }

  @override
  Future<T> update(T item) async {
    items[_indexOf(idOf(item))] = item;
    await _persist();
    return item;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _indexOf(id);
    if (!isDeletedItem(items[i])) {
      items[i] = markDeleted(items[i], DateTime.now());
      await _persist();
    }
  }

  @override
  Future<void> hardDelete(int id) async {
    items.removeAt(_indexOf(id));
    await _persist();
  }

  @override
  Future<void> restore(int id) async {
    final i = _indexOf(id);
    items[i] = markRestored(items[i]);
    await _persist();
  }

  /// Логически удаляет записи и возвращает число реально удалённых
  /// (уже удалённые и отсутствующие не считаются).
  @override
  Future<int> deleteMany(List<int> ids) async {
    final now = DateTime.now();
    var count = 0;
    for (final id in ids) {
      // Ошибка методички: _books.indexWhere((b) => b.id == id && !b[i].isDeleted).
      // Внутри замыкания b — один объект, а не список: оператора [] у класса
      // нет, поэтому b[i] не компилируется. Кроме того, i ещё не объявлена —
      // её значение появляется только после возврата indexWhere.
      // Исправлено: проверяем сам элемент — !b.isDeleted.
      final i = items.indexWhere((b) => idOf(b) == id && !isDeletedItem(b));
      if (i == -1) continue;
      items[i] = markDeleted(items[i], now);
      count++;
    }
    if (count > 0) await _persist();
    return count;
  }

  int _indexOf(int id) {
    final i = items.indexWhere((item) => idOf(item) == id);
    if (i == -1) throw RepositoryException(notFound(id));
    return i;
  }
}
