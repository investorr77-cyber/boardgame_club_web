import '../models/designer.dart';
import '../models/designer_query.dart';
import '../models/page_result.dart';
import '../repositories/designer_repository.dart';
import 'entity_list_notifier.dart';

/// Состояние списка авторов.
class DesignerListNotifier extends EntityListNotifier<Designer, DesignerQuery> {
  DesignerListNotifier(this._repository) : super(const DesignerQuery());

  final DesignerRepository _repository;

  @override
  Future<PageResult<Designer>> fetch(DesignerQuery query) =>
      _repository.find(query);

  @override
  int idOf(Designer item) => item.id;

  @override
  int pageOf(DesignerQuery query) => query.page;

  @override
  DesignerQuery withPage(DesignerQuery query, int page) =>
      query.copyWith(page: page);

  @override
  Future<int> deleteManyInRepository(List<int> ids) =>
      _repository.deleteMany(ids);

  @override
  Future<void> softDeleteInRepository(int id) => _repository.softDelete(id);

  @override
  Future<void> hardDeleteInRepository(int id) => _repository.hardDelete(id);

  @override
  Future<void> restoreInRepository(int id) => _repository.restore(id);
}
