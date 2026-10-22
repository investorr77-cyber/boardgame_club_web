import 'package:flutter/foundation.dart';

import '../models/board_game.dart';
import '../models/member.dart';
import '../repositories/board_game_repository.dart';
import '../repositories/crud_repository.dart';
import '../repositories/reference_repositories.dart';
import 'data_changes.dart';
import 'load_status.dart';

/// Состояние формы создания и изменения: загрузка записи для редактирования
/// и сохранение. Один экран формы на оба режима.
class EntityEditNotifier<T> extends ChangeNotifier {
  EntityEditNotifier(this._repository, {DataChanges? changes})
      : _changes = changes;

  final CrudRepository<T, Object?> _repository;
  final DataChanges? _changes;

  DetailsStatus _status = DetailsStatus.idle;
  int? _requestedId;
  T? _item;
  String? _error;
  int _token = 0;

  DetailsStatus get status => _status;
  int? get requestedId => _requestedId;
  T? get item => _item;
  String? get error => _error;

  /// Загрузка записи для редактирования. Пока она идёт, форма не строится:
  /// иначе поля заполнились бы до прихода данных и остались пустыми.
  Future<void> load(int id) async {
    final token = ++_token;
    _requestedId = id;
    _item = null;
    _error = null;
    _status = DetailsStatus.loading;
    notifyListeners();
    try {
      final item = await _repository.findById(id);
      if (token != _token) return;
      _item = item;
      _status = item == null ? DetailsStatus.notFound : DetailsStatus.found;
    } catch (e) {
      if (token != _token) return;
      _error = e.toString();
      _status = DetailsStatus.error;
    }
    notifyListeners();
  }

  /// Создаёт ([isNew]) или обновляет запись и сообщает остальным экранам.
  Future<T> save(T item, {required bool isNew}) async {
    final saved =
        isNew ? await _repository.create(item) : await _repository.update(item);
    _item = saved;
    _changes?.bump(this);
    return saved;
  }
}

/// Форма игры: дополнительно проверка уникальности штрихкода.
class GameEditNotifier extends EntityEditNotifier<BoardGame> {
  GameEditNotifier(BoardGameRepository super.repository, {super.changes})
      : _games = repository;

  final BoardGameRepository _games;

  Future<bool> isBarcodeTaken(String barcode, {int? exceptId}) =>
      _games.isBarcodeTaken(barcode, exceptId: exceptId);
}

/// Форма участника: уникальность почты и номера клубной карты.
class MemberEditNotifier extends EntityEditNotifier<Member> {
  MemberEditNotifier(MemberRepository super.repository, {super.changes})
      : _members = repository;

  final MemberRepository _members;

  Future<bool> isEmailTaken(String email, {int? exceptId}) =>
      _members.isEmailTaken(email, exceptId: exceptId);

  Future<bool> isCardNumberTaken(String number, {int? exceptId}) =>
      _members.isCardNumberTaken(number, exceptId: exceptId);
}
