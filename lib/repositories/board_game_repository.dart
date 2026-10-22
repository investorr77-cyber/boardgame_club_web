import '../models/board_game.dart';
import '../models/game_query.dart';
import 'crud_repository.dart';

/// Источник данных об играх.
abstract interface class BoardGameRepository
    implements CrudRepository<BoardGame, GameQuery> {
  /// Штрихкод уже занят другой игрой (удалённые тоже учитываются).
  Future<bool> isBarcodeTaken(String barcode, {int? exceptId});

  /// Сколько игр ссылается на издателя — нужно для запрета удаления.
  Future<int> countByPublisher(int publisherId);
}
