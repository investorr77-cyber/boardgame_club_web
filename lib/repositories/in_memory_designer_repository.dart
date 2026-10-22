import '../models/designer.dart';
import '../models/designer_query.dart';
import 'designer_repository.dart';
import 'in_memory_crud_repository.dart';
import 'local_store.dart';
import 'seed/seed_designers.dart';

/// Авторы: память + localStorage.
class InMemoryDesignerRepository
    extends InMemoryCrudRepository<Designer, DesignerQuery>
    implements DesignerRepository {
  InMemoryDesignerRepository({
    List<Designer>? initial,
    super.store,
    super.delay,
    super.shouldFail,
  }) : super(seed: () => List.of(initial ?? seedDesigners));

  @override
  String get storageKey => LocalStore.key('designers');

  @override
  String get collectionLabel => 'Авторы';

  @override
  String notFound(int id) => 'Автор с id $id не найден';

  @override
  int idOf(Designer item) => item.id;

  @override
  Designer withId(Designer item, int id) => item.copyWith(id: id);

  @override
  bool isDeletedItem(Designer item) => item.isDeleted;

  @override
  Designer markDeleted(Designer item, DateTime at) =>
      item.copyWith(deletedAt: at);

  @override
  Designer markRestored(Designer item) => item.copyWith(clearDeletedAt: true);

  @override
  Map<String, dynamic> encode(Designer item) => item.toJson();

  @override
  Designer decode(Map<String, dynamic> json) => Designer.fromJson(json);

  @override
  bool matches(Designer d, DesignerQuery query) {
    final search = query.search.trim().toLowerCase();
    if (search.isNotEmpty &&
        !d.lastName.toLowerCase().contains(search) &&
        !d.country.toLowerCase().contains(search)) {
      return false;
    }
    if (query.country != null && d.country != query.country) return false;
    return true;
  }

  @override
  int compareBy(Designer a, Designer b, DesignerQuery query) =>
      switch (query.sortField) {
        'birthYear' => a.birthYear.compareTo(b.birthYear),
        'country' => a.country.compareTo(b.country),
        _ => a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()),
      };
}
