import 'package:dio/dio.dart';

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
import 'supabase_crud_repository.dart';

// Репозитории сущностей поверх Supabase. Схема базы — supabase/schema.sql.

class SupabaseBoardGameRepository
    extends SupabaseCrudRepository<BoardGame, GameQuery>
    implements BoardGameRepository {
  SupabaseBoardGameRepository(super.dio);

  @override
  String get table => '/games';

  // designers(id) и genres(id) — многие ко многим через связующие таблицы
  // game_designers и game_genres: PostgREST находит их по внешним ключам.
  @override
  String get select => 'id,title,barcode,year,playTimeMin:play_time_min,'
      'minPlayers:min_players,maxPlayers:max_players,'
      'publisherId:publisher_id,copiesTotal:copies_total,'
      'copiesAvailable:copies_available,deletedAt:deleted_at,'
      'designers(id),genres(id)';

  @override
  String selectFor(GameQuery q) => q.genreId == null
      ? select
      : '$select,by_genre:game_genres!inner(genre_id)';

  @override
  Map<String, String> get sortColumns =>
      const {'title': 'title', 'year': 'year', 'playTimeMin': 'play_time_min'};

  @override
  List<String> get searchColumns => const ['title', 'barcode'];

  @override
  Map<String, String> filterParams(GameQuery q) => {
        if (q.genreId != null) 'by_genre.genre_id': 'eq.${q.genreId}',
        if (q.publisherId != null) 'publisher_id': 'eq.${q.publisherId}',
        if (q.yearFrom != null || q.yearTo != null)
          'and': '(${[
            if (q.yearFrom != null) 'year.gte.${q.yearFrom}',
            if (q.yearTo != null) 'year.lte.${q.yearTo}',
          ].join(',')})',
      };

  @override
  BoardGame fromJson(Map<String, dynamic> json) => BoardGame.fromJson(json);

  @override
  int idOf(BoardGame item) => item.id;

  @override
  Map<String, dynamic> toRow(BoardGame g) => const {};

  /// Игра и её авторы/жанры сохраняются одной функцией базы (транзакция).
  @override
  String get saveFunction => 'save_game';

  @override
  Map<String, dynamic> toSaveParams(BoardGame item) => item.toJson()
    ..remove('deletedAt')
    ..['id'] = item.id == 0 ? null : item.id;

  @override
  Future<bool> isBarcodeTaken(String barcode, {int? exceptId}) =>
      exists('/games', {'barcode': 'eq.${barcode.trim()}'},
          idColumn: 'id', exceptId: exceptId);

  @override
  Future<int> countByPublisher(int publisherId) => guard(() async {
        final response = await dio.get<Object?>('/games',
            queryParameters: {
              'select': 'id',
              'publisher_id': 'eq.$publisherId',
              'limit': 1,
            },
            options: Options(headers: {'Prefer': 'count=exact'}));
        return totalOf(response, 0);
      });

  Future<BoardGame> _rpc(String name, int id) => guard(() async {
        await dio.post<Object?>('/rpc/$name', data: {'p_id': id});
        final game = await findById(id);
        if (game == null) throw const NotFoundException();
        return game;
      });

  @override
  Future<BoardGame> checkout(int id) => _rpc('game_checkout', id);

  @override
  Future<BoardGame> giveBack(int id) => _rpc('game_return', id);
}

class SupabaseDesignerRepository
    extends SupabaseCrudRepository<Designer, DesignerQuery>
    implements DesignerRepository {
  SupabaseDesignerRepository(super.dio);

  @override
  String get table => '/designers';

  @override
  String get select => 'id,lastName:last_name,firstName:first_name,country,'
      'birthYear:birth_year,deletedAt:deleted_at';

  @override
  Map<String, String> get sortColumns => const {
        'lastName': 'last_name',
        'birthYear': 'birth_year',
        'country': 'country',
      };

  @override
  List<String> get searchColumns =>
      const ['last_name', 'first_name', 'country'];

  @override
  Map<String, String> filterParams(DesignerQuery q) =>
      {if (q.country != null) 'country': 'eq.${q.country}'};

  @override
  Designer fromJson(Map<String, dynamic> json) => Designer.fromJson(json);

  @override
  int idOf(Designer item) => item.id;

  @override
  Map<String, dynamic> toRow(Designer d) => {
        'last_name': d.lastName,
        'first_name': d.firstName,
        'country': d.country,
        'birth_year': d.birthYear,
      };
}

class SupabaseGenreRepository extends SupabaseCrudRepository<Genre, SimpleQuery>
    implements GenreRepository {
  SupabaseGenreRepository(super.dio);

  @override
  String get table => '/genres';

  @override
  String get select => 'id,name,description,deletedAt:deleted_at';

  @override
  Map<String, String> get sortColumns => const {'name': 'name'};

  @override
  List<String> get searchColumns => const ['name', 'description'];

  @override
  Genre fromJson(Map<String, dynamic> json) => Genre.fromJson(json);

  @override
  int idOf(Genre item) => item.id;

  @override
  Map<String, dynamic> toRow(Genre g) =>
      {'name': g.name, 'description': g.description};
}

class SupabasePublisherRepository
    extends SupabaseCrudRepository<Publisher, SimpleQuery>
    implements PublisherRepository {
  SupabasePublisherRepository(super.dio);

  @override
  String get table => '/publishers';

  @override
  String get select =>
      'id,name,country,foundedYear:founded_year,email,deletedAt:deleted_at';

  @override
  Map<String, String> get sortColumns => const {
        'name': 'name',
        'country': 'country',
        'foundedYear': 'founded_year',
      };

  @override
  List<String> get searchColumns => const ['name', 'country', 'email'];

  @override
  Map<String, String> filterParams(SimpleQuery q) =>
      {if (q.filter != null) 'country': 'eq.${q.filter}'};

  @override
  Publisher fromJson(Map<String, dynamic> json) => Publisher.fromJson(json);

  @override
  int idOf(Publisher item) => item.id;

  @override
  Map<String, dynamic> toRow(Publisher p) => {
        'name': p.name,
        'country': p.country,
        'founded_year': p.foundedYear,
        'email': p.email,
      };
}

class SupabaseMemberRepository
    extends SupabaseCrudRepository<Member, SimpleQuery>
    implements MemberRepository {
  SupabaseMemberRepository(super.dio);

  @override
  String get table => '/members';

  // card — один к одному: первичный ключ member_cards ссылается на members,
  // поэтому PostgREST возвращает объект, а не список.
  @override
  String get select => 'id,lastName:last_name,firstName:first_name,email,phone,'
      'city,deletedAt:deleted_at,'
      'card:member_cards(number,issuedYear:issued_year,maxGames:max_games)';

  @override
  Map<String, String> get sortColumns =>
      const {'lastName': 'last_name', 'city': 'city', 'email': 'email'};

  @override
  List<String> get searchColumns =>
      const ['last_name', 'first_name', 'email', 'phone'];

  @override
  Map<String, String> filterParams(SimpleQuery q) =>
      {if (q.filter != null) 'city': 'eq.${q.filter}'};

  @override
  Member fromJson(Map<String, dynamic> json) => Member.fromJson(json);

  @override
  int idOf(Member item) => item.id;

  @override
  Map<String, dynamic> toRow(Member m) => const {};

  /// Участник и его карта сохраняются одной функцией базы.
  @override
  String get saveFunction => 'save_member';

  @override
  Map<String, dynamic> toSaveParams(Member item) => item.toJson()
    ..remove('deletedAt')
    ..['id'] = item.id == 0 ? null : item.id;

  @override
  Future<bool> isEmailTaken(String email, {int? exceptId}) =>
      exists('/members', {'email': 'ilike.${email.trim()}'},
          idColumn: 'id', exceptId: exceptId);

  @override
  Future<bool> isCardNumberTaken(String number, {int? exceptId}) =>
      exists('/member_cards', {'number': 'eq.${number.trim().toUpperCase()}'},
          idColumn: 'member_id', exceptId: exceptId);
}
