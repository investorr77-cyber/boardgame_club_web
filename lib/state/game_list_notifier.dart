import '../models/board_game.dart';
import '../models/game_query.dart';
import '../models/page_result.dart';
import '../repositories/board_game_repository.dart';
import 'entity_list_notifier.dart';

/// Состояние списка игр. Экраны работают только с ним, не с репозиторием.
class GameListNotifier extends EntityListNotifier<BoardGame, GameQuery> {
  GameListNotifier(this._repository) : super(const GameQuery());

  final BoardGameRepository _repository;

  @override
  Future<PageResult<BoardGame>> fetch(GameQuery query) =>
      _repository.find(query);

  @override
  int idOf(BoardGame item) => item.id;

  @override
  int pageOf(GameQuery query) => query.page;

  @override
  GameQuery withPage(GameQuery query, int page) => query.copyWith(page: page);

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
