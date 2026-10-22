/// Общие параметры любого списка. По ним работают обобщённый репозиторий
/// и обобщённый экран списка.
abstract interface class ListQuery {
  String get search;
  String get sortField;
  bool get sortAscending;
  int get page;
  int get size;
  bool get includeDeleted;

  /// Параметры адресной строки (только отличные от значений по умолчанию).
  Map<String, String> toQueryParameters();
}
