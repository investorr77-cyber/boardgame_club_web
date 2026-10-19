import '../models/page_result.dart';

/// Вырезает страницу из отфильтрованного и отсортированного списка.
PageResult<T> paginate<T>(List<T> all, int page, int size) {
  final total = all.length;
  final start = (page - 1) * size;
  if (page < 1 || size < 1 || start >= total) {
    // Страница за пределами диапазона: пустой список, но total настоящий.
    return PageResult<T>(
        items: List<T>.empty(), page: page, size: size, total: total);
  }
  // Граница считается явно, без num.clamp: clamp возвращает num,
  // и sublist(start, num) не компилируется без приведения типа.
  final end = start + size < total ? start + size : total;
  return PageResult<T>(
      items: all.sublist(start, end), page: page, size: size, total: total);
}
