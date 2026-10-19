import '../models/board_game.dart';
import '../models/game_query.dart';
import '../models/page_result.dart';
import 'board_game_repository.dart';
import 'paging.dart';
import 'repository_exception.dart';
import 'seed/seed_games.dart';

/// Игры в памяти. После перезагрузки страницы восстанавливается начальный набор.
class InMemoryBoardGameRepository implements BoardGameRepository {
  InMemoryBoardGameRepository({
    List<BoardGame>? initial,
    this.delay = const Duration(milliseconds: 250),
    bool Function()? shouldFail,
  })  : _games = List.of(initial ?? buildSeedGames()),
        _shouldFail = shouldFail ?? _never;

  /// Имитация сетевой задержки.
  final Duration delay;
  final List<BoardGame> _games;

  /// Включённый переключатель «Сымитировать ошибку» заставляет find бросать исключение.
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
  Future<PageResult<BoardGame>> find(GameQuery query) async {
    await _simulateNetwork();
    final search = query.search.trim().toLowerCase();
    final filtered = _games.where((g) {
      if (!query.includeDeleted && g.isDeleted) return false;
      if (search.isNotEmpty &&
          !g.title.toLowerCase().contains(search) &&
          !g.barcode.contains(search)) {
        return false;
      }
      if (query.genreId != null && !g.genreIds.contains(query.genreId)) {
        return false;
      }
      if (query.publisherId != null && g.publisherId != query.publisherId) {
        return false;
      }
      if (query.yearFrom != null && g.year < query.yearFrom!) return false;
      if (query.yearTo != null && g.year > query.yearTo!) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final byField = switch (query.sortField) {
          'year' => a.year.compareTo(b.year),
          'playTimeMin' => a.playTimeMin.compareTo(b.playTimeMin),
          _ => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        };
        final result = byField != 0 ? byField : a.id.compareTo(b.id);
        return query.sortAscending ? result : -result;
      });
    return paginate(filtered, query.page, query.size);
  }

  @override
  Future<BoardGame?> findById(int id) async {
    await _simulateNetwork();
    for (final game in _games) {
      if (game.id == id) return game;
    }
    return null;
  }

  @override
  Future<BoardGame> create(BoardGame game) async {
    final nextId = _games.fold(0, (max, g) => g.id > max ? g.id : max) + 1;
    final created = game.copyWith(id: nextId);
    _games.add(created);
    return created;
  }

  @override
  Future<BoardGame> update(BoardGame game) async {
    _games[_indexOf(game.id)] = game;
    return game;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _indexOf(id);
    if (!_games[i].isDeleted) {
      _games[i] = _games[i].copyWith(deletedAt: DateTime.now());
    }
  }

  @override
  Future<void> hardDelete(int id) async {
    _games.removeAt(_indexOf(id));
  }

  @override
  Future<void> restore(int id) async {
    final i = _indexOf(id);
    _games[i] = _games[i].copyWith(clearDeletedAt: true);
  }

  /// Логически удаляет записи и возвращает число реально удалённых
  /// (уже удалённые и отсутствующие не считаются).
  @override
  Future<int> deleteMany(List<int> ids) async {
    final now = DateTime.now();
    var count = 0;
    for (final id in ids) {
      // Ошибка методички: _books.indexWhere((b) => b.id == id && !b[i].isDeleted).
      // Внутри замыкания b — один объект, а не список: оператора [] у класса
      // нет, поэтому b[i] не компилируется. Кроме того, i ещё не объявлена —
      // её значение появляется только после возврата indexWhere.
      // Исправлено: проверяем сам элемент — !b.isDeleted.
      final i = _games.indexWhere((b) => b.id == id && !b.isDeleted);
      if (i == -1) continue;
      _games[i] = _games[i].copyWith(deletedAt: now);
      count++;
    }
    return count;
  }

  int _indexOf(int id) {
    final i = _games.indexWhere((g) => g.id == id);
    if (i == -1) throw RepositoryException('Игра с id $id не найдена');
    return i;
  }
}
