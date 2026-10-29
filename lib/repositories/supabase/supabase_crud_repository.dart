import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api_exceptions.dart';
import '../../models/list_query.dart';
import '../../models/page_result.dart';
import '../crud_repository.dart';

/// CrudRepository поверх Supabase (PostgREST). Интерфейс тот же, что у
/// репозиториев ПР4, — notifier'ы и экраны не меняются.
///
/// Поиск, фильтры, сортировка и пагинация выполняются в базе:
///   GET /rest/v1/games?select=...&or=(title.ilike."*кар*")&year=gte.2000
///       &order=title.asc&offset=10&limit=10   Prefer: count=exact
/// Общее число записей приходит в заголовке Content-Range: `10-19/30`.
abstract class SupabaseCrudRepository<T, Q extends ListQuery>
    implements CrudRepository<T, Q> {
  SupabaseCrudRepository(this.dio);

  final Dio dio;
  CancelToken? _findToken;

  /// Таблица: '/games'.
  @protected
  String get table;

  /// Столбцы ответа. Псевдонимы (`playTimeMin:play_time_min`) сразу дают
  /// имена полей модели, поэтому fromJson общий с REST-версией.
  @protected
  String get select;

  /// Поле сортировки модели → столбец таблицы.
  @protected
  Map<String, String> get sortColumns;

  /// Столбцы, по которым ищет строка поиска.
  @protected
  List<String> get searchColumns;

  /// Фильтры сущности в формате PostgREST: {'country': 'eq.Россия'}.
  @protected
  Map<String, String> filterParams(Q q) => const {};

  /// Столбцы ответа с учётом фильтров: фильтр по связи многие ко многим
  /// требует добавить в select связующую таблицу с `!inner`.
  @protected
  String selectFor(Q q) => select;

  @protected
  T fromJson(Map<String, dynamic> json);

  /// Запись для таблицы (имена столбцов базы).
  @protected
  Map<String, dynamic> toRow(T item);
  @protected
  int idOf(T item);

  /// Функция базы, сохраняющая запись вместе со связями в одной транзакции.
  /// null — запись идёт прямо в таблицу.
  @protected
  String? get saveFunction => null;

  /// Тело для [saveFunction].
  @protected
  Map<String, dynamic> toSaveParams(T item) => const {};

  static String _quote(String value) =>
      '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  Map<String, dynamic> _listParams(Q q) {
    final search = q.search.trim();
    final column = sortColumns[q.sortField] ?? sortColumns.values.first;
    return {
      'select': selectFor(q),
      if (search.isNotEmpty)
        'or':
            '(${searchColumns.map((c) => '$c.ilike.${_quote('*$search*')}').join(',')})',
      ...filterParams(q),
      if (!q.includeDeleted) 'deleted_at': 'is.null',
      // id — второй ключ: при равных значениях порядок страниц устойчив.
      'order': '$column.${q.sortAscending ? 'asc' : 'desc'},id.asc',
      'offset': (q.page - 1) * q.size,
      'limit': q.size,
    };
  }

  @protected
  List<Map<String, dynamic>> rows(Object? data) => [
        if (data is List)
          for (final item in data)
            if (item is Map) Map<String, dynamic>.from(item),
      ];

  /// `0-9/30` → 30; `*/0` → 0.
  @protected
  int totalOf(Response<Object?> response, int fallback) {
    final range = response.headers.value('content-range');
    final total = range == null ? null : int.tryParse(range.split('/').last);
    return total ?? fallback;
  }

  @override
  Future<PageResult<T>> find(Q query) => guard(() async {
        // Отмена устаревшего запроса: ответ на «во» не затрёт ответ на «война».
        _findToken?.cancel('устарел');
        final token = _findToken = CancelToken();
        final response = await dio.get<Object?>(
          table,
          queryParameters: _listParams(query),
          cancelToken: token,
          options: Options(
            headers: {'Prefer': 'count=exact'},
            // 416 — запрошенная страница за пределами выборки.
            extra: {'acceptStatus': 416},
          ),
        );
        final items = response.statusCode == 416
            ? <T>[]
            : rows(response.data).map(fromJson).toList();
        return PageResult<T>(
          items: items,
          page: query.page,
          size: query.size,
          total: totalOf(response, items.length),
        );
      });

  @override
  Future<List<T>> findAll({bool includeDeleted = false}) => guard(() async {
        final response = await dio.get<Object?>(table, queryParameters: {
          'select': select,
          if (!includeDeleted) 'deleted_at': 'is.null',
          'order': 'id.asc',
          'limit': 1000,
        });
        return rows(response.data).map(fromJson).toList();
      });

  @override
  Future<T?> findById(int id) => guard(() async {
        final response = await dio.get<Object?>(table,
            queryParameters: {'select': select, 'id': 'eq.$id'});
        final list = rows(response.data);
        return list.isEmpty ? null : fromJson(list.first);
      });

  /// Запись с возвратом изменённых строк. Пустой ответ — политика RLS
  /// не пропустила изменение (или записи нет): PostgREST в этом случае
  /// не возвращает ошибку, а просто ничего не меняет.
  Future<List<Map<String, dynamic>>> _write(
    String method, {
    required Map<String, dynamic> query,
    Object? data,
  }) async {
    final response = await dio.request<Object?>(
      table,
      data: data,
      queryParameters: {'select': select, ...query},
      options:
          Options(method: method, headers: {'Prefer': 'return=representation'}),
    );
    final list = rows(response.data);
    if (list.isEmpty && method != 'POST') {
      throw const NotFoundException(
          'Запись не найдена или недостаточно прав на изменение.');
    }
    return list;
  }

  Future<T> _save(T item) async {
    final id = await dio
        .post<Object?>('/rpc/$saveFunction', data: {'p': toSaveParams(item)});
    final saved = await findById(id.data is int ? id.data as int : idOf(item));
    if (saved == null) throw const NotFoundException();
    return saved;
  }

  @override
  Future<T> create(T item) => guard(() async {
        if (saveFunction != null) return _save(item);
        return fromJson(
            (await _write('POST', query: const {}, data: toRow(item))).first);
      });

  @override
  Future<T> update(T item) => guard(() async {
        if (saveFunction != null) return _save(item);
        return fromJson((await _write('PATCH',
                query: {'id': 'eq.${idOf(item)}'}, data: toRow(item)))
            .first);
      });

  String get _now => DateTime.now().toUtc().toIso8601String();

  @override
  Future<void> softDelete(int id) => guard(() =>
      _write('PATCH', query: {'id': 'eq.$id'}, data: {'deleted_at': _now}));

  @override
  Future<void> hardDelete(int id) =>
      guard(() => _write('DELETE', query: {'id': 'eq.$id'}));

  @override
  Future<void> restore(int id) => guard(() =>
      _write('PATCH', query: {'id': 'eq.$id'}, data: {'deleted_at': null}));

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
        if (ids.isEmpty) return 0;
        final list = await _write('PATCH',
            query: {'id': 'in.(${ids.join(',')})'}, data: {'deleted_at': _now});
        return list.length;
      });

  /// Есть ли запись по условию — для проверок уникальности до сохранения.
  @protected
  Future<bool> exists(String path, Map<String, String> where,
          {required String idColumn, int? exceptId}) =>
      guard(() async {
        final response = await dio.get<Object?>(path,
            queryParameters: {'select': idColumn, ...where, 'limit': 50});
        return rows(response.data)
            .any((r) => exceptId == null || r[idColumn] != exceptId);
      });
}
