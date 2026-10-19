import 'package:flutter/foundation.dart';

import '../models/board_game.dart';
import '../models/designer.dart';
import '../models/game_query.dart';
import '../repositories/board_game_repository.dart';
import '../repositories/designer_repository.dart';
import 'load_status.dart';

/// Карточка автора: автор и его игры.
class DesignerDetailsNotifier extends ChangeNotifier {
  DesignerDetailsNotifier(this._designers, this._games);

  final DesignerRepository _designers;
  final BoardGameRepository _games;

  DetailsStatus _status = DetailsStatus.idle;
  int? _requestedId;
  Designer? _designer;
  List<BoardGame> _designerGames = const [];
  String? _error;
  int _token = 0;

  DetailsStatus get status => _status;
  int? get requestedId => _requestedId;
  Designer? get designer => _designer;
  List<BoardGame> get games => _designerGames;
  String? get error => _error;

  Future<void> load(int? id) async {
    final token = ++_token;
    _requestedId = id;
    _designer = null;
    _designerGames = const [];
    _error = null;
    if (id == null) {
      _status = DetailsStatus.notFound;
      notifyListeners();
      return;
    }
    _status = DetailsStatus.loading;
    notifyListeners();
    try {
      final designer = await _designers.findById(id);
      if (designer == null) {
        if (token != _token) return;
        _status = DetailsStatus.notFound;
      } else {
        // Все игры одной выборкой; в ПР4 здесь будет отдельный запрос к серверу.
        final all = await _games
            .find(const GameQuery(size: 1000, includeDeleted: true));
        if (token != _token) return;
        _designer = designer;
        _designerGames =
            all.items.where((g) => g.designerIds.contains(id)).toList();
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
