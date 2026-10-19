import '../models/designer.dart';
import '../models/designer_query.dart';
import '../models/page_result.dart';
import 'designer_repository.dart';
import 'paging.dart';
import 'repository_exception.dart';
import 'seed/seed_designers.dart';

/// Авторы в памяти. После перезагрузки страницы восстанавливается начальный набор.
class InMemoryDesignerRepository implements DesignerRepository {
  InMemoryDesignerRepository({
    List<Designer>? initial,
    this.delay = const Duration(milliseconds: 250),
    bool Function()? shouldFail,
  })  : _designers = List.of(initial ?? seedDesigners),
        _shouldFail = shouldFail ?? _never;

  final Duration delay;
  final List<Designer> _designers;
  final bool Function() _shouldFail;

  static bool _never() => false;

  Future<void> _simulateNetwork() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (_shouldFail()) {
      throw const RepositoryException(
          'Сервер не отвечает (сымитированная ошибка сети)');
    }
  }

  @override
  Future<PageResult<Designer>> find(DesignerQuery query) async {
    await _simulateNetwork();
    final search = query.search.trim().toLowerCase();
    final filtered = _designers.where((d) {
      if (!query.includeDeleted && d.isDeleted) return false;
      if (search.isNotEmpty &&
          !d.lastName.toLowerCase().contains(search) &&
          !d.country.toLowerCase().contains(search)) {
        return false;
      }
      if (query.country != null && d.country != query.country) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final byField = switch (query.sortField) {
          'birthYear' => a.birthYear.compareTo(b.birthYear),
          'country' => a.country.compareTo(b.country),
          _ => a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()),
        };
        final result = byField != 0 ? byField : a.id.compareTo(b.id);
        return query.sortAscending ? result : -result;
      });
    return paginate(filtered, query.page, query.size);
  }

  @override
  Future<Designer?> findById(int id) async {
    await _simulateNetwork();
    for (final designer in _designers) {
      if (designer.id == id) return designer;
    }
    return null;
  }

  @override
  Future<Designer> create(Designer designer) async {
    final nextId = _designers.fold(0, (max, d) => d.id > max ? d.id : max) + 1;
    final created = designer.copyWith(id: nextId);
    _designers.add(created);
    return created;
  }

  @override
  Future<Designer> update(Designer designer) async {
    _designers[_indexOf(designer.id)] = designer;
    return designer;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _indexOf(id);
    if (!_designers[i].isDeleted) {
      _designers[i] = _designers[i].copyWith(deletedAt: DateTime.now());
    }
  }

  @override
  Future<void> hardDelete(int id) async {
    _designers.removeAt(_indexOf(id));
  }

  @override
  Future<void> restore(int id) async {
    final i = _indexOf(id);
    _designers[i] = _designers[i].copyWith(clearDeletedAt: true);
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    final now = DateTime.now();
    var count = 0;
    for (final id in ids) {
      // Та же исправленная логика, что и для игр: в методичке было
      // !b[i].isDeleted — b здесь один объект, а i ещё не объявлена.
      final i = _designers.indexWhere((b) => b.id == id && !b.isDeleted);
      if (i == -1) continue;
      _designers[i] = _designers[i].copyWith(deletedAt: now);
      count++;
    }
    return count;
  }

  int _indexOf(int id) {
    final i = _designers.indexWhere((d) => d.id == id);
    if (i == -1) throw RepositoryException('Автор с id $id не найден');
    return i;
  }
}
