import '../core/api_exceptions.dart';
import '../models/board_game.dart';
import '../models/game_query.dart';
import 'board_game_repository.dart';
import 'in_memory_crud_repository.dart';
import 'local_store.dart';
import 'seed/seed_games.dart';

/// Игры: память + localStorage.
class InMemoryBoardGameRepository
    extends InMemoryCrudRepository<BoardGame, GameQuery>
    implements BoardGameRepository {
  InMemoryBoardGameRepository({
    List<BoardGame>? initial,
    super.store,
    super.delay,
    super.shouldFail,
  }) : super(seed: () => List.of(initial ?? buildSeedGames()));

  @override
  String get storageKey => LocalStore.key('games');

  @override
  String get collectionLabel => 'Игры';

  @override
  String notFound(int id) => 'Игра с id $id не найдена';

  @override
  int idOf(BoardGame item) => item.id;

  @override
  BoardGame withId(BoardGame item, int id) => item.copyWith(id: id);

  @override
  bool isDeletedItem(BoardGame item) => item.isDeleted;

  @override
  BoardGame markDeleted(BoardGame item, DateTime at) =>
      item.copyWith(deletedAt: at);

  @override
  BoardGame markRestored(BoardGame item) => item.copyWith(clearDeletedAt: true);

  @override
  Map<String, dynamic> encode(BoardGame item) => item.toJson();

  @override
  BoardGame decode(Map<String, dynamic> json) => BoardGame.fromJson(json);

  @override
  bool matches(BoardGame g, GameQuery query) {
    final search = query.search.trim().toLowerCase();
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
  }

  @override
  int compareBy(BoardGame a, BoardGame b, GameQuery query) =>
      switch (query.sortField) {
        'year' => a.year.compareTo(b.year),
        'playTimeMin' => a.playTimeMin.compareTo(b.playTimeMin),
        _ => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      };

  @override
  Future<bool> isBarcodeTaken(String barcode, {int? exceptId}) async {
    final value = barcode.trim();
    return items.any((g) => g.barcode == value && g.id != exceptId);
  }

  @override
  Future<int> countByPublisher(int publisherId) async =>
      items.where((g) => g.publisherId == publisherId).length;

  @override
  Future<BoardGame> checkout(int id) async {
    final game = (await findById(id))!;
    if (game.copiesAvailable <= 0) {
      throw ConflictException('Нет свободных коробок «${game.title}»: '
          'все ${game.copiesTotal} на руках.');
    }
    return update(game.copyWith(copiesAvailable: game.copiesAvailable - 1));
  }

  @override
  Future<BoardGame> giveBack(int id) async {
    final game = (await findById(id))!;
    if (game.copiesAvailable >= game.copiesTotal) {
      throw ConflictException('Все коробки «${game.title}» уже в клубе.');
    }
    return update(game.copyWith(copiesAvailable: game.copiesAvailable + 1));
  }
}
