import 'query_parsing.dart';

/// Условия отбора списка игр. Источник правды — адресная строка:
/// `/games?search=каркассон&genreId=2&publisherId=1&yearFrom=2000&yearTo=2015&sort=year,desc&page=2&size=25&deleted=1`
class GameQuery {
  const GameQuery({
    this.search = '',
    this.genreId,
    this.publisherId,
    this.yearFrom,
    this.yearTo,
    this.sortField = defaultSortField,
    this.sortAscending = true,
    this.page = 1,
    this.size = defaultPageSize,
    this.includeDeleted = false,
  });

  /// Мусор в адресе (`page=abc`, `size=7`, `sort=foo,bar`) не ломает разбор:
  /// берётся значение по умолчанию.
  factory GameQuery.fromQueryParameters(Map<String, String> params) {
    final sort = parseSort(params['sort'], sortFields);
    return GameQuery(
      search: params['search']?.trim() ?? '',
      genreId: parsePositiveInt(params['genreId']),
      publisherId: parsePositiveInt(params['publisherId']),
      yearFrom: parseYear(params['yearFrom']),
      yearTo: parseYear(params['yearTo']),
      sortField: sort?.$1 ?? defaultSortField,
      sortAscending: sort?.$2 ?? true,
      page: parsePositiveInt(params['page']) ?? 1,
      size: parsePageSize(params['size']),
      includeDeleted: parseFlag(params['deleted']),
    );
  }

  static const sortFields = ['title', 'year', 'playTimeMin'];
  static const defaultSortField = 'title';

  /// Маркер «аргумент не передан» для nullable-фильтров:
  /// `copyWith(genreId: null)` сбрасывает фильтр, `copyWith()` его сохраняет.
  static const _unset = Object();

  final String search;
  final int? genreId;
  final int? publisherId;
  final int? yearFrom;
  final int? yearTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  /// Любое изменение условий отбора сбрасывает page в 1,
  /// кроме случая, когда page передан явно.
  GameQuery copyWith({
    String? search,
    Object? genreId = _unset,
    Object? publisherId = _unset,
    Object? yearFrom = _unset,
    Object? yearTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    final next = GameQuery(
      search: search ?? this.search,
      genreId: identical(genreId, _unset) ? this.genreId : genreId as int?,
      publisherId:
          identical(publisherId, _unset) ? this.publisherId : publisherId as int?,
      yearFrom: identical(yearFrom, _unset) ? this.yearFrom : yearFrom as int?,
      yearTo: identical(yearTo, _unset) ? this.yearTo : yearTo as int?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? this.page,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
    if (page != null || next == this) return next;
    return next._withPage(1);
  }

  GameQuery _withPage(int value) => GameQuery(
        search: search,
        genreId: genreId,
        publisherId: publisherId,
        yearFrom: yearFrom,
        yearTo: yearTo,
        sortField: sortField,
        sortAscending: sortAscending,
        page: value,
        size: size,
        includeDeleted: includeDeleted,
      );

  /// В адрес пишутся только параметры, отличные от значений по умолчанию.
  Map<String, String> toQueryParameters() => {
        if (search.isNotEmpty) 'search': search,
        if (genreId != null) 'genreId': '$genreId',
        if (publisherId != null) 'publisherId': '$publisherId',
        if (yearFrom != null) 'yearFrom': '$yearFrom',
        if (yearTo != null) 'yearTo': '$yearTo',
        if (sortField != defaultSortField || !sortAscending)
          'sort': formatSort(sortField, sortAscending),
        if (page != 1) 'page': '$page',
        if (size != defaultPageSize) 'size': '$size',
        if (includeDeleted) 'deleted': '1',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameQuery &&
          other.search == search &&
          other.genreId == genreId &&
          other.publisherId == publisherId &&
          other.yearFrom == yearFrom &&
          other.yearTo == yearTo &&
          other.sortField == sortField &&
          other.sortAscending == sortAscending &&
          other.page == page &&
          other.size == size &&
          other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(search, genreId, publisherId, yearFrom,
      yearTo, sortField, sortAscending, page, size, includeDeleted);

  @override
  String toString() => 'GameQuery(${toQueryParameters()})';
}
