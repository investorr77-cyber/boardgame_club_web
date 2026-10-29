import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/board_game.dart';
import '../models/designer.dart';
import '../repositories/board_game_repository.dart';
import '../repositories/designer_repository.dart';
import 'data_changes.dart';
import 'load_status.dart';

/// Карточка записи: загрузка, найдено, «не найдено», ошибка.
/// [related] — связанные игры (у автора, жанра, издателя).
class EntityDetailsNotifier<T> extends ChangeNotifier {
  EntityDetailsNotifier({
    required Future<T?> Function(int id) load,
    Future<List<BoardGame>> Function(T item)? related,
    DataChanges? changes,
  })  : _loadItem = load,
        _related = related,
        _changes = changes {
    _changes?.addListener(_onDataChanged);
  }

  final Future<T?> Function(int id) _loadItem;
  final Future<List<BoardGame>> Function(T item)? _related;
  final DataChanges? _changes;

  DetailsStatus _status = DetailsStatus.idle;
  int? _requestedId;
  T? _item;
  List<BoardGame> _games = const [];
  String? _error;
  int _token = 0;

  DetailsStatus get status => _status;
  int? get requestedId => _requestedId;
  T? get item => _item;
  List<BoardGame> get games => _games;
  String? get error => _error;

  void _onDataChanged() {
    if (_status == DetailsStatus.found) load(_requestedId);
  }

  @override
  void dispose() {
    _changes?.removeListener(_onDataChanged);
    super.dispose();
  }

  /// [id] == null — в адресе не число: сразу «не найдено», без исключения.
  Future<void> load(int? id) async {
    final token = ++_token;
    _requestedId = id;
    _error = null;
    if (id == null) {
      _item = null;
      _status = DetailsStatus.notFound;
      notifyListeners();
      return;
    }
    if (_status != DetailsStatus.found || _item == null) {
      _status = DetailsStatus.loading;
      notifyListeners();
    }
    try {
      final item = await _loadItem(id);
      final games = item == null || _related == null
          ? const <BoardGame>[]
          : await _related(item);
      if (token != _token) return;
      _item = item;
      _games = games;
      _status = item == null ? DetailsStatus.notFound : DetailsStatus.found;
    } catch (e) {
      if (token != _token) return;
      _item = null;
      _error = e.toString();
      _status = DetailsStatus.error;
    }
    notifyListeners();
  }
}

/// Карточка игры: игра и её авторы.
class GameDetailsNotifier extends EntityDetailsNotifier<BoardGame> {
  GameDetailsNotifier(this._gameRepository, this._designerRepository,
      {super.changes})
      : _dataChanges = changes,
        super(load: _gameRepository.findById);

  final BoardGameRepository _gameRepository;
  final DesignerRepository _designerRepository;
  final DataChanges? _dataChanges;
  List<Designer> _designers = const [];
  bool _busy = false;

  List<Designer> get designers => _designers;

  /// Идёт выдача или возврат: кнопки заблокированы от повторного нажатия.
  bool get busy => _busy;

  /// Выдать коробку. Возвращает текст для пользователя: успех
  /// или понятное сообщение о конфликте 409 («нет свободных коробок»).
  Future<String> checkout() =>
      _changeCopies(_gameRepository.checkout, 'Коробка выдана участнику');

  /// Вернуть коробку в клуб.
  Future<String> giveBack() =>
      _changeCopies(_gameRepository.giveBack, 'Коробка возвращена в клуб');

  Future<String> _changeCopies(
      Future<BoardGame> Function(int id) action, String success) async {
    final id = requestedId;
    if (id == null || _busy) return '';
    _busy = true;
    notifyListeners();
    try {
      await action(id);
      _dataChanges?.bump(); // перечитает карточку, списки и справочники
      return success;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  Future<void> load(int? id) async {
    await super.load(id);
    final game = item;
    if (game == null || requestedId != id) return;
    final found = <Designer>[];
    for (final designerId in game.designerIds) {
      final designer = await _designerRepository.findById(designerId);
      if (designer != null) found.add(designer);
    }
    if (requestedId != id) return;
    _designers = found;
    notifyListeners();
  }
}

/// Карточка автора со списком его игр.
class DesignerDetailsNotifier extends EntityDetailsNotifier<Designer> {
  DesignerDetailsNotifier(
      DesignerRepository designers, BoardGameRepository games,
      {super.changes})
      : super(
          load: designers.findById,
          related: (designer) async {
            // findAll, а не find: find отменяет предыдущий запрос списка игр.
            final all = await games.findAll(includeDeleted: true);
            return all
                .where((g) => g.designerIds.contains(designer.id))
                .toList();
          },
        );
}
