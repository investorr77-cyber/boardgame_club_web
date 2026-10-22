import '../models/page_result.dart';

/// Общий набор операций для всех пяти сущностей. В ПР4 его реализует
/// HTTP-клиент с тем же интерфейсом — notifier'ы и экраны не меняются.
abstract interface class CrudRepository<T, Q> {
  Future<PageResult<T>> find(Q query);

  /// Все записи без пагинации — для выпадающих списков и связей.
  Future<List<T>> findAll({bool includeDeleted = false});
  Future<T?> findById(int id);
  Future<T> create(T item);
  Future<T> update(T item);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}
