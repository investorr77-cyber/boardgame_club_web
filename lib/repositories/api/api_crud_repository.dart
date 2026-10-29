import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api_exceptions.dart';
import '../../models/list_query.dart';
import '../../models/page_result.dart';
import '../crud_repository.dart';

/// Общая реализация CrudRepository поверх REST API. Интерфейс тот же,
/// что у хранилища в памяти, — меняется только реализация.
///
/// Поиск, фильтры, сортировка и пагинация выполняются на сервере:
/// клиент хранит только текущую страницу.
abstract class ApiCrudRepository<T, Q extends ListQuery>
    implements CrudRepository<T, Q> {
  ApiCrudRepository(this.dio);

  final Dio dio;
  CancelToken? _findToken;

  /// Путь ресурса: '/games'.
  @protected
  String get path;
  @protected
  T fromJson(Map<String, dynamic> json);

  /// Тело запроса на запись: связи уходят идентификаторами.
  @protected
  Map<String, dynamic> toBody(T item);
  @protected
  int idOf(T item);

  /// Фильтры сущности в параметрах запроса.
  @protected
  Map<String, dynamic> filterParams(Q query);

  Map<String, dynamic> _listParams(Q q) => {
        if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
        ...filterParams(q),
        'sort': '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}',
        'page': q.page,
        'size': q.size,
        if (q.includeDeleted) 'includeDeleted': true,
      };

  @protected
  PageResult<T> parsePage(Object? data, int fallbackSize) {
    if (data is! Map) {
      throw const ServerException('Сервер вернул данные в неверном формате.');
    }
    final items = data['items'];
    return PageResult<T>(
      items: [
        if (items is List)
          for (final item in items)
            if (item is Map) fromJson(Map<String, dynamic>.from(item)),
      ],
      page: data['page'] is int ? data['page'] as int : 1,
      size: data['size'] is int ? data['size'] as int : fallbackSize,
      total: data['total'] is int ? data['total'] as int : 0,
    );
  }

  @protected
  T parseItem(Object? data) {
    if (data is! Map) {
      throw const ServerException('Сервер вернул данные в неверном формате.');
    }
    return fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<PageResult<T>> find(Q query) => guard(() async {
        // Отмена устаревшего запроса: при быстром вводе в поиск ответ на «во»
        // мог бы прийти после ответа на «война» и затереть его.
        _findToken?.cancel('устарел');
        final token = _findToken = CancelToken();
        final response = await dio.get<Object?>(path,
            queryParameters: _listParams(query), cancelToken: token);
        return parsePage(response.data, query.size);
      });

  @override
  Future<List<T>> findAll({bool includeDeleted = false}) => guard(() async {
        final response = await dio.get<Object?>(path, queryParameters: {
          'page': 1,
          'size': 1000,
          if (includeDeleted) 'includeDeleted': true,
        });
        return parsePage(response.data, 1000).items;
      });

  @override
  Future<T?> findById(int id) async {
    try {
      return await guard(
          () async => parseItem((await dio.get<Object?>('$path/$id')).data));
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<T> create(T item) => guard(() async =>
      parseItem((await dio.post<Object?>(path, data: toBody(item))).data));

  @override
  Future<T> update(T item) => guard(() async => parseItem(
      (await dio.put<Object?>('$path/${idOf(item)}', data: toBody(item)))
          .data));

  @override
  Future<void> softDelete(int id) =>
      guard(() => dio.delete<Object?>('$path/$id'));

  @override
  Future<void> hardDelete(int id) => guard(
      () => dio.delete<Object?>('$path/$id', queryParameters: {'hard': true}));

  @override
  Future<void> restore(int id) =>
      guard(() => dio.post<Object?>('$path/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
        final response =
            await dio.post<Object?>('$path/bulk-delete', data: {'ids': ids});
        final data = response.data;
        return data is Map && data['deleted'] is int
            ? data['deleted'] as int
            : 0;
      });
}
