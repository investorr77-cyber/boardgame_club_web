/// Одна страница выборки. Формат совпадает с будущим ответом сервера (ПР4),
/// поэтому экраны не придётся переделывать при смене источника данных.
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  /// Не const: пустой список с параметром типа T нельзя сделать константой.
  PageResult.empty({this.page = 1, this.size = 10})
      : items = List<T>.empty(),
        total = 0;

  final List<T> items;
  final int page;
  final int size;
  final int total;

  int get totalPages {
    if (total == 0 || size <= 0) return 1;
    return (total + size - 1) ~/ size;
  }

  bool get hasPrevious => page > 1;

  bool get hasNext => page < totalPages;
}
