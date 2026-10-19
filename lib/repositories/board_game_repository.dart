import '../models/board_game.dart';
import '../models/game_query.dart';
import '../models/page_result.dart';

/// Источник данных об играх. В ПР4 in-memory реализацию заменит HTTP-клиент
/// с тем же интерфейсом; notifier'ы и экраны при этом не меняются.
abstract interface class BoardGameRepository {
  Future<PageResult<BoardGame>> find(GameQuery query);
  Future<BoardGame?> findById(int id);
  Future<BoardGame> create(BoardGame game);
  Future<BoardGame> update(BoardGame game);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}
