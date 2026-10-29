import '../../core/api_exceptions.dart';
import '../../models/board_game.dart';
import '../../models/designer.dart';
import '../../models/designer_query.dart';
import '../../models/game_query.dart';
import '../../models/genre.dart';
import '../../models/member.dart';
import '../../models/publisher.dart';
import '../../models/simple_query.dart';
import '../board_game_repository.dart';
import '../designer_repository.dart';
import '../reference_repositories.dart';
import 'api_crud_repository.dart';

// Репозитории пяти сущностей поверх REST API. Эндпоинты — в server/README.md.

class ApiBoardGameRepository extends ApiCrudRepository<BoardGame, GameQuery>
    implements BoardGameRepository {
  ApiBoardGameRepository(super.dio);

  @override
  String get path => '/games';

  @override
  BoardGame fromJson(Map<String, dynamic> json) => BoardGame.fromJson(json);

  @override
  int idOf(BoardGame item) => item.id;

  // На запись уходят publisherId, designerIds, genreIds,
  // а приходят развёрнутые publisher, designers, genres — их разбирает fromJson.
  @override
  Map<String, dynamic> toBody(BoardGame g) => {
        'title': g.title,
        'barcode': g.barcode,
        'year': g.year,
        'playTimeMin': g.playTimeMin,
        'minPlayers': g.minPlayers,
        'maxPlayers': g.maxPlayers,
        'publisherId': g.publisherId,
        'designerIds': g.designerIds,
        'genreIds': g.genreIds,
        'copiesTotal': g.copiesTotal,
        'copiesAvailable': g.copiesAvailable,
      };

  @override
  Map<String, dynamic> filterParams(GameQuery q) => {
        if (q.genreId != null) 'genreId': q.genreId,
        if (q.publisherId != null) 'publisherId': q.publisherId,
        if (q.yearFrom != null) 'yearFrom': q.yearFrom,
        if (q.yearTo != null) 'yearTo': q.yearTo,
      };

  @override
  Future<bool> isBarcodeTaken(String barcode, {int? exceptId}) =>
      guard(() async {
        final page = parsePage(
            (await dio.get<Object?>(path, queryParameters: {
              'search': barcode.trim(),
              'includeDeleted': true,
              'size': 50,
            }))
                .data,
            50);
        return page.items
            .any((g) => g.barcode == barcode.trim() && g.id != exceptId);
      });

  @override
  Future<int> countByPublisher(int publisherId) => guard(() async {
        final page = parsePage(
            (await dio.get<Object?>(path, queryParameters: {
              'publisherId': publisherId,
              'includeDeleted': true,
              'size': 1,
            }))
                .data,
            1);
        return page.total;
      });

  @override
  Future<BoardGame> checkout(int id) => guard(() async =>
      parseItem((await dio.post<Object?>('$path/$id/checkout')).data));

  @override
  Future<BoardGame> giveBack(int id) => guard(() async =>
      parseItem((await dio.post<Object?>('$path/$id/return')).data));
}

class ApiDesignerRepository extends ApiCrudRepository<Designer, DesignerQuery>
    implements DesignerRepository {
  ApiDesignerRepository(super.dio);

  @override
  String get path => '/designers';

  @override
  Designer fromJson(Map<String, dynamic> json) => Designer.fromJson(json);

  @override
  int idOf(Designer item) => item.id;

  @override
  Map<String, dynamic> toBody(Designer d) => {
        'lastName': d.lastName,
        'firstName': d.firstName,
        'country': d.country,
        'birthYear': d.birthYear,
      };

  @override
  Map<String, dynamic> filterParams(DesignerQuery q) =>
      {if (q.country != null) 'country': q.country};
}

class ApiGenreRepository extends ApiCrudRepository<Genre, SimpleQuery>
    implements GenreRepository {
  ApiGenreRepository(super.dio);

  @override
  String get path => '/genres';

  @override
  Genre fromJson(Map<String, dynamic> json) => Genre.fromJson(json);

  @override
  int idOf(Genre item) => item.id;

  @override
  Map<String, dynamic> toBody(Genre g) =>
      {'name': g.name, 'description': g.description};

  @override
  Map<String, dynamic> filterParams(SimpleQuery q) => const {};
}

class ApiPublisherRepository extends ApiCrudRepository<Publisher, SimpleQuery>
    implements PublisherRepository {
  ApiPublisherRepository(super.dio);

  @override
  String get path => '/publishers';

  @override
  Publisher fromJson(Map<String, dynamic> json) => Publisher.fromJson(json);

  @override
  int idOf(Publisher item) => item.id;

  @override
  Map<String, dynamic> toBody(Publisher p) => {
        'name': p.name,
        'country': p.country,
        'foundedYear': p.foundedYear,
        'email': p.email,
      };

  @override
  Map<String, dynamic> filterParams(SimpleQuery q) =>
      {if (q.filter != null) 'country': q.filter};
}

class ApiMemberRepository extends ApiCrudRepository<Member, SimpleQuery>
    implements MemberRepository {
  ApiMemberRepository(super.dio);

  @override
  String get path => '/members';

  @override
  Member fromJson(Map<String, dynamic> json) => Member.fromJson(json);

  @override
  int idOf(Member item) => item.id;

  @override
  Map<String, dynamic> toBody(Member m) {
    final json = m.toJson()
      ..remove('id')
      ..remove('deletedAt');
    return json;
  }

  @override
  Map<String, dynamic> filterParams(SimpleQuery q) =>
      {if (q.filter != null) 'city': q.filter};

  Future<bool> _exists(String search, bool Function(Member m) match) =>
      guard(() async {
        final page = parsePage(
            (await dio.get<Object?>(path, queryParameters: {
              'search': search,
              'includeDeleted': true,
              'size': 50,
            }))
                .data,
            50);
        return page.items.any(match);
      });

  @override
  Future<bool> isEmailTaken(String email, {int? exceptId}) => _exists(
      email.trim(),
      (m) =>
          m.email.toLowerCase() == email.trim().toLowerCase() &&
          m.id != exceptId);

  @override
  Future<bool> isCardNumberTaken(String number, {int? exceptId}) => _exists(
      number.trim(),
      (m) =>
          m.card.number.toUpperCase() == number.trim().toUpperCase() &&
          m.id != exceptId);
}
