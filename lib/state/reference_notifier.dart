import 'package:flutter/foundation.dart';

import '../models/board_game.dart';
import '../models/designer.dart';
import '../models/genre.dart';
import '../models/member.dart';
import '../models/permissions.dart';
import '../models/publisher.dart';
import '../repositories/board_game_repository.dart';
import '../repositories/designer_repository.dart';
import '../repositories/reference_repositories.dart';
import 'auth_notifier.dart';
import 'data_changes.dart';

/// Справочные данные для экранов: имена в таблицах и варианты
/// для выпадающих списков форм. Берутся из репозиториев, а не из констант,
/// и перечитываются после любого изменения данных.
class ReferenceNotifier extends ChangeNotifier {
  ReferenceNotifier({
    required BoardGameRepository games,
    required DesignerRepository designers,
    required GenreRepository genres,
    required PublisherRepository publishers,
    required MemberRepository members,
    DataChanges? changes,
    AuthNotifier? auth,
  })  : _gameRepo = games,
        _designerRepo = designers,
        _genreRepo = genres,
        _publisherRepo = publishers,
        _memberRepo = members,
        _changes = changes,
        _auth = auth {
    _changes?.addListener(load);
    _auth?.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthNotifier? _auth;
  int? _loadedFor;

  /// Справочники загружаются после входа и сбрасываются при выходе.
  void _onAuthChanged() {
    final user = _auth?.user;
    if (_auth != null && user == null) {
      _loadedFor = null;
      _loaded = false;
      return;
    }
    final key = user == null ? null : Object.hash(user.id, user.role);
    if (_auth == null || key != _loadedFor) {
      _loadedFor = key;
      load();
    }
  }

  final BoardGameRepository _gameRepo;
  final DesignerRepository _designerRepo;
  final GenreRepository _genreRepo;
  final PublisherRepository _publisherRepo;
  final MemberRepository _memberRepo;
  final DataChanges? _changes;

  bool _loaded = false;
  List<BoardGame> _games = const [];
  List<Designer> _designers = const [];
  List<Genre> _genres = const [];
  List<Publisher> _publishers = const [];
  List<Member> _members = const [];

  bool get loaded => _loaded;
  List<BoardGame> get games => _games;
  List<Designer> get designers => _designers;
  List<Genre> get genres => _genres;
  List<Publisher> get publishers => _publishers;
  List<Member> get members => _members;

  /// Записи включая удалённые: имена нужны и для приглушённых строк.
  Future<void> load() async {
    if (_auth != null && !_auth.isAuthenticated) return;
    // Недоступный роли справочник (участники клуба для роли «участник»)
    // и сбой сети не ломают остальные: вместо них — пустой список.
    Future<List<T>> safe<T>(Future<List<T>> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return <T>[];
      }
    }

    final canSeeMembers = _auth == null || _auth.can(Operation.viewMembers);
    final results = await Future.wait<List<Object?>>([
      safe(() => _gameRepo.findAll(includeDeleted: true)),
      safe(() => _designerRepo.findAll(includeDeleted: true)),
      safe(() => _genreRepo.findAll(includeDeleted: true)),
      safe(() => _publisherRepo.findAll(includeDeleted: true)),
      canSeeMembers
          ? safe(() => _memberRepo.findAll(includeDeleted: true))
          : Future.value(const <Member>[]),
    ]);
    _games = results[0].cast<BoardGame>();
    _designers = results[1].cast<Designer>();
    _genres = results[2].cast<Genre>();
    _publishers = results[3].cast<Publisher>();
    _members = results[4].cast<Member>();
    _loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _changes?.removeListener(load);
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  String genreName(int id) {
    for (final genre in _genres) {
      if (genre.id == id) return genre.name;
    }
    return '—';
  }

  String publisherName(int id) {
    for (final publisher in _publishers) {
      if (publisher.id == id) return publisher.name;
    }
    return '—';
  }

  String designerName(int id) {
    for (final designer in _designers) {
      if (designer.id == id) return designer.fullName;
    }
    return '—';
  }

  List<String> get designerCountries =>
      _distinct([for (final d in _designers) d.country]);

  List<String> get publisherCountries =>
      _distinct([for (final p in _publishers) p.country]);

  List<String> get memberCities =>
      _distinct([for (final m in _members) m.city]);

  static List<String> _distinct(List<String> values) =>
      ({...values}..removeWhere((v) => v.isEmpty)).toList()..sort();
}
