import 'package:flutter/foundation.dart';

import '../models/board_game.dart';
import '../models/designer.dart';
import '../repositories/board_game_repository.dart';
import '../repositories/designer_repository.dart';
import 'load_status.dart';

/// Карточка игры: игра и её авторы.
class GameDetailsNotifier extends ChangeNotifier {
  GameDetailsNotifier(this._games, this._designers);

  final BoardGameRepository _games;
  final DesignerRepository _designers;

  DetailsStatus _status = DetailsStatus.idle;
  int? _requestedId;
  BoardGame? _game;
  List<Designer> _gameDesigners = const [];
  String? _error;
  int _token = 0;

  DetailsStatus get status => _status;
  int? get requestedId => _requestedId;
  BoardGame? get game => _game;
  List<Designer> get designers => _gameDesigners;
  String? get error => _error;

  /// [id] == null — в адресе не число: сразу «не найдено», без исключения.
  Future<void> load(int? id) async {
    final token = ++_token;
    _requestedId = id;
    _game = null;
    _gameDesigners = const [];
    _error = null;
    if (id == null) {
      _status = DetailsStatus.notFound;
      notifyListeners();
      return;
    }
    _status = DetailsStatus.loading;
    notifyListeners();
    try {
      final game = await _games.findById(id);
      if (game == null) {
        if (token != _token) return;
        _status = DetailsStatus.notFound;
      } else {
        final designers = <Designer>[];
        for (final designerId in game.designerIds) {
          final designer = await _designers.findById(designerId);
          if (designer != null) designers.add(designer);
        }
        if (token != _token) return;
        _game = game;
        _gameDesigners = designers;
        _status = DetailsStatus.found;
      }
    } catch (e) {
      if (token != _token) return;
      _error = e.toString();
      _status = DetailsStatus.error;
    }
    notifyListeners();
  }
}
