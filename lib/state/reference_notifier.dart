import 'package:flutter/foundation.dart';

import '../models/board_game.dart';
import '../models/designer.dart';
import '../models/genre.dart';
import '../models/member.dart';
import '../models/publisher.dart';
import '../repositories/board_game_repository.dart';
import '../repositories/designer_repository.dart';
import '../repositories/reference_repositories.dart';
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
  })  : _gameRepo = games,
        _designerRepo = designers,
        _genreRepo = genres,
        _publisherRepo = publishers,
        _memberRepo = members,
        _changes = changes {
    _changes?.addListener(load);
    load();
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
    final results = await Future.wait([
      _gameRepo.findAll(includeDeleted: true),
      _designerRepo.findAll(includeDeleted: true),
      _genreRepo.findAll(includeDeleted: true),
      _publisherRepo.findAll(includeDeleted: true),
      _memberRepo.findAll(includeDeleted: true),
    ]);
    _games = results[0] as List<BoardGame>;
    _designers = results[1] as List<Designer>;
    _genres = results[2] as List<Genre>;
    _publishers = results[3] as List<Publisher>;
    _members = results[4] as List<Member>;
    _loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _changes?.removeListener(load);
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

  List<String> get memberCities => _distinct([for (final m in _members) m.city]);

  static List<String> _distinct(List<String> values) =>
      ({...values}..removeWhere((v) => v.isEmpty)).toList()..sort();
}
