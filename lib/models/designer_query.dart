import 'list_query.dart';
import 'query_parsing.dart';

/// Условия отбора списка авторов:
/// `/designers?search=...&country=...&sort=lastName,asc&page=2&size=10&deleted=1`
class DesignerQuery implements ListQuery {
  const DesignerQuery({
    this.search = '',
    this.country,
    this.sortField = defaultSortField,
    this.sortAscending = true,
    this.page = 1,
    this.size = defaultPageSize,
    this.includeDeleted = false,
  });

  factory DesignerQuery.fromQueryParameters(Map<String, String> params) {
    final sort = parseSort(params['sort'], sortFields);
    return DesignerQuery(
      search: params['search']?.trim() ?? '',
      country: parseText(params['country']),
      sortField: sort?.$1 ?? defaultSortField,
      sortAscending: sort?.$2 ?? true,
      page: parsePositiveInt(params['page']) ?? 1,
      size: parsePageSize(params['size']),
      includeDeleted: parseFlag(params['deleted']),
    );
  }

  static const sortFields = ['lastName', 'birthYear', 'country'];
  static const defaultSortField = 'lastName';
  static const _unset = Object();

  @override
  final String search;
  final String? country;
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
  DesignerQuery copyWith({
    String? search,
    Object? country = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    final next = DesignerQuery(
      search: search ?? this.search,
      country: identical(country, _unset) ? this.country : country as String?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? this.page,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
    if (page != null || next == this) return next;
    return DesignerQuery(
      search: next.search,
      country: next.country,
      sortField: next.sortField,
      sortAscending: next.sortAscending,
      page: 1,
      size: next.size,
      includeDeleted: next.includeDeleted,
    );
  }

  @override
  Map<String, String> toQueryParameters() => {
        if (search.isNotEmpty) 'search': search,
        if (country != null) 'country': country!,
        if (sortField != defaultSortField || !sortAscending)
          'sort': formatSort(sortField, sortAscending),
        if (page != 1) 'page': '$page',
        if (size != defaultPageSize) 'size': '$size',
        if (includeDeleted) 'deleted': '1',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesignerQuery &&
          other.search == search &&
          other.country == country &&
          other.sortField == sortField &&
          other.sortAscending == sortAscending &&
          other.page == page &&
          other.size == size &&
          other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
      search, country, sortField, sortAscending, page, size, includeDeleted);

  @override
  String toString() => 'DesignerQuery(${toQueryParameters()})';
}
