import '../models/board_game.dart';
import '../models/designer.dart';
import '../models/designer_query.dart';
import '../models/game_query.dart';
import '../models/page_result.dart';
import '../models/publisher.dart';
import '../models/simple_query.dart';
import '../models/text_utils.dart';
import '../repositories/board_game_repository.dart';
import '../repositories/crud_repository.dart';
import '../repositories/designer_repository.dart';
import '../repositories/reference_repositories.dart';
import '../repositories/repository_exception.dart';
import 'entity_list_notifier.dart';

/// Список, который просто передаёт операции в CrudRepository.
class CrudListNotifier<T, Q> extends EntityListNotifier<T, Q> {
  CrudListNotifier(
    this.repository, {
    required Q initial,
    required int Function(T item) idOfItem,
    required Q Function(Q query, int page) setPage,
    required int Function(Q query) getPage,
    super.changes,
  })  : _idOf = idOfItem,
        _setPage = setPage,
        _getPage = getPage,
        super(initial);

  final CrudRepository<T, Q> repository;
  final int Function(T item) _idOf;
  final Q Function(Q query, int page) _setPage;
  final int Function(Q query) _getPage;

  @override
  Future<PageResult<T>> fetch(Q query) => repository.find(query);

  @override
  int idOf(T item) => _idOf(item);

  @override
  int pageOf(Q query) => _getPage(query);

  @override
  Q withPage(Q query, int page) => _setPage(query, page);

  @override
  Future<int> deleteManyInRepository(List<int> ids) =>
      repository.deleteMany(ids);

  @override
  Future<void> softDeleteInRepository(int id) => repository.softDelete(id);

  @override
  Future<void> hardDeleteInRepository(int id) => repository.hardDelete(id);

  @override
  Future<void> restoreInRepository(int id) => repository.restore(id);
}

/// Состояние списка игр. Экраны работают только с ним, не с репозиторием.
class GameListNotifier extends CrudListNotifier<BoardGame, GameQuery> {
  GameListNotifier(BoardGameRepository super.repository, {super.changes})
      : super(
          initial: const GameQuery(),
          idOfItem: (g) => g.id,
          setPage: (q, page) => q.copyWith(page: page),
          getPage: (q) => q.page,
        );
}

/// Состояние списка авторов.
class DesignerListNotifier extends CrudListNotifier<Designer, DesignerQuery> {
  DesignerListNotifier(DesignerRepository super.repository, {super.changes})
      : super(
          initial: const DesignerQuery(),
          idOfItem: (d) => d.id,
          setPage: (q, page) => q.copyWith(page: page),
          getPage: (q) => q.page,
        );
}

/// Список жанров, издателей или участников.
class SimpleListNotifier<T> extends CrudListNotifier<T, SimpleQuery> {
  SimpleListNotifier(
    super.repository, {
    required String defaultSortField,
    required super.idOfItem,
    super.changes,
  }) : super(
          initial: SimpleQuery(defaultSortField: defaultSortField),
          setPage: (q, page) => q.copyWith(page: page),
          getPage: (q) => q.page,
        );
}

/// Список издателей: удалить издателя, на которого ссылаются игры, нельзя.
class PublisherListNotifier extends SimpleListNotifier<Publisher> {
  PublisherListNotifier(
    PublisherRepository super.repository,
    this._games, {
    super.changes,
  }) : super(defaultSortField: 'name', idOfItem: (p) => p.id);

  final BoardGameRepository _games;

  @override
  Future<void> checkCanDelete(List<int> ids) async {
    for (final id in ids) {
      final count = await _games.countByPublisher(id);
      if (count == 0) continue;
      final publisher = await repository.findById(id);
      final name = publisher?.name ?? 'id $id';
      throw OperationRefused(
        'Нельзя удалить издателя «$name»: на него ссылается '
        '$count ${plural(count, 'игра', 'игры', 'игр')}. '
        'Сначала укажите этим играм другого издателя или удалите их.',
      );
    }
  }
}
