import '../models/designer.dart';
import '../models/designer_query.dart';
import '../models/page_result.dart';

/// Источник данных об авторах. Набор методов совпадает с BoardGameRepository.
abstract interface class DesignerRepository {
  Future<PageResult<Designer>> find(DesignerQuery query);
  Future<Designer?> findById(int id);
  Future<Designer> create(Designer designer);
  Future<Designer> update(Designer designer);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}
