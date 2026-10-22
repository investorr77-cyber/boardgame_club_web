import 'list_query.dart';
import 'query_parsing.dart';

/// Условия отбора для жанров, издателей и участников клуба. Формат адреса:
/// `/publishers?search=...&filter=Россия&sort=name,desc&page=2&size=25&deleted=1`.
/// [filter] — значение единственного фильтра сущности (страна, город).
class SimpleQuery implements ListQuery {
  const SimpleQuery({
    required this.defaultSortField,
    this.search = '',
    this.filter,
    String? sortField,
    this.sortAscending = true,
    this.page = 1,
    this.size = defaultPageSize,
    this.includeDeleted = false,
  }) : sortField = sortField ?? defaultSortField;

  /// Мусор в адресе не ломает разбор: берётся значение по умолчанию.
  factory SimpleQuery.fromQueryParameters(
    Map<String, String> params, {
    required List<String> sortFields,
    required String defaultSortField,
  }) {
    final sort = parseSort(params['sort'], sortFields);
    return SimpleQuery(
      defaultSortField: defaultSortField,
      search: params['search']?.trim() ?? '',
      filter: parseText(params['filter']),
      sortField: sort?.$1 ?? defaultSortField,
      sortAscending: sort?.$2 ?? true,
      page: parsePositiveInt(params['page']) ?? 1,
      size: parsePageSize(params['size']),
      includeDeleted: parseFlag(params['deleted']),
    );
  }

  static const _unset = Object();

  final String defaultSortField;
  @override
  final String search;
  final String? filter;
  @override
  final String sortField;
  @override
  final bool sortAscending;
  @override
  final int page;
  @override
  final int size;
  @override
  final bool includeDeleted;

  /// Любое изменение условий отбора сбрасывает page в 1,
  /// кроме случая, когда page передан явно.
  SimpleQuery copyWith({
    String? search,
    Object? filter = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    final next = SimpleQuery(
      defaultSortField: defaultSortField,
      search: search ?? this.search,
      filter: identical(filter, _unset) ? this.filter : filter as String?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? this.page,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
    if (page != null || next == this) return next;
    return next.copyWith(page: 1);
  }

  @override
  Map<String, String> toQueryParameters() => {
        if (search.isNotEmpty) 'search': search,
        if (filter != null) 'filter': filter!,
        if (sortField != defaultSortField || !sortAscending)
          'sort': formatSort(sortField, sortAscending),
        if (page != 1) 'page': '$page',
        if (size != defaultPageSize) 'size': '$size',
        if (includeDeleted) 'deleted': '1',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimpleQuery &&
          other.defaultSortField == defaultSortField &&
          other.search == search &&
          other.filter == filter &&
          other.sortField == sortField &&
          other.sortAscending == sortAscending &&
          other.page == page &&
          other.size == size &&
          other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(defaultSortField, search, filter, sortField,
      sortAscending, page, size, includeDeleted);

  @override
  String toString() => 'SimpleQuery(${toQueryParameters()})';
}
