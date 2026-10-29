import 'package:boardgame_club_web/models/designer_query.dart';
import 'package:boardgame_club_web/models/game_query.dart';
import 'package:boardgame_club_web/repositories/in_memory_board_game_repository.dart';
import 'package:boardgame_club_web/repositories/in_memory_designer_repository.dart';
import 'package:boardgame_club_web/repositories/seed/seed_games.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryBoardGameRepository games;
  late InMemoryDesignerRepository designers;

  setUp(() {
    games = InMemoryBoardGameRepository(delay: Duration.zero);
    designers = InMemoryDesignerRepository(delay: Duration.zero);
  });

  group('BoardGameRepository', () {
    test('начальный набор: 30 игр, 3 страницы по 10', () async {
      final r = await games.find(const GameQuery());
      expect(r.total, 30);
      expect(r.totalPages, 3);
      expect(r.items, hasLength(10));
    });

    test('поиск по названию без учёта регистра', () async {
      final r = await games.find(const GameQuery(search: 'КАРКАССОН'));
      expect(r.total, greaterThan(0));
      expect(r.items.every((g) => g.title.toLowerCase().contains('каркассон')),
          isTrue);
    });

    test('поиск по штрихкоду', () async {
      final target = (await games.findById(7))!;
      final r = await games.find(GameQuery(search: target.barcode));
      expect(r.items.map((g) => g.id), [7]);
      expect(target.barcode, hasLength(13));
    });

    test('комбинация жанр + издатель + диапазон года', () async {
      const q = GameQuery(
          genreId: 5, publisherId: 2, yearFrom: 2010, yearTo: 2020, size: 50);
      final r = await games.find(q);
      final expected = buildSeedGames()
          .where((g) =>
              g.genreIds.contains(5) &&
              g.publisherId == 2 &&
              g.year >= 2010 &&
              g.year <= 2020)
          .map((g) => g.id)
          .toSet();
      expect(r.items.map((g) => g.id).toSet(), expected);
      expect(r.total, inInclusiveRange(1, 29));
    });

    test('фильтр комбинируется с поиском', () async {
      final r = await games
          .find(const GameQuery(search: 'крылья', genreId: 5, yearTo: 2020));
      expect(r.items.map((g) => g.title), ['Крылья']);
    });

    test('сортировка по году в обе стороны', () async {
      final asc =
          await games.find(const GameQuery(sortField: 'year', size: 50));
      final desc = await games.find(
          const GameQuery(sortField: 'year', sortAscending: false, size: 50));
      final ascYears = asc.items.map((g) => g.year).toList();
      final descYears = desc.items.map((g) => g.year).toList();
      expect(ascYears, [...ascYears]..sort());
      expect(descYears, [...descYears]..sort((a, b) => b.compareTo(a)));
      expect(ascYears.first, 1995);
      expect(descYears.first, 2022);
    });

    test('пагинация: последняя неполная страница и страница за диапазоном',
        () async {
      final last = await games.find(const GameQuery(size: 25, page: 2));
      expect(last.items, hasLength(5));
      expect(last.hasNext, isFalse);
      expect(last.hasPrevious, isTrue);

      final beyond = await games.find(const GameQuery(page: 9));
      expect(beyond.items, isEmpty);
      expect(beyond.total, 30);
    });

    test('softDelete скрывает запись, includeDeleted её показывает', () async {
      await games.softDelete(1);
      final hidden = await games.find(const GameQuery(size: 50));
      expect(hidden.items.any((g) => g.id == 1), isFalse);
      expect(hidden.total, 29);

      final shown =
          await games.find(const GameQuery(size: 50, includeDeleted: true));
      final deleted = shown.items.firstWhere((g) => g.id == 1);
      expect(deleted.isDeleted, isTrue);
    });

    test('restore возвращает запись', () async {
      await games.softDelete(1);
      await games.restore(1);
      final r = await games.find(const GameQuery(size: 50));
      expect(r.total, 30);
      expect((await games.findById(1))!.deletedAt, isNull);
    });

    test('deleteMany возвращает число только неудалённых записей', () async {
      await games.softDelete(1);
      final count = await games.deleteMany([1, 2, 3, 999]);
      expect(count, 2);
      expect((await games.find(const GameQuery())).total, 27);
    });

    test('hardDelete стирает запись насовсем', () async {
      await games.hardDelete(5);
      expect(await games.findById(5), isNull);
      final r = await games.find(const GameQuery(includeDeleted: true));
      expect(r.total, 29);
    });

    test('create выдаёт следующий id, update меняет запись', () async {
      final base = (await games.findById(1))!;
      final created = await games.create(base.copyWith(title: 'Новая игра'));
      expect(created.id, 31);
      await games.update(created.copyWith(year: 2024));
      expect((await games.findById(31))!.year, 2024);
    });

    test('сымитированная ошибка: find бросает исключение', () async {
      final failing = InMemoryBoardGameRepository(
          delay: Duration.zero, shouldFail: () => true);
      expect(failing.find(const GameQuery()), throwsException);
    });
  });

  group('DesignerRepository', () {
    test('начальный набор: 12 авторов, 2 страницы', () async {
      final r = await designers.find(const DesignerQuery());
      expect(r.total, 12);
      expect(r.totalPages, 2);
    });

    test('поиск авторов по фамилии и по стране', () async {
      final byName = await designers.find(const DesignerQuery(search: 'ВРЕДЕ'));
      expect(byName.items.map((d) => d.lastName), ['Вреде']);

      final byCountry =
          await designers.find(const DesignerQuery(search: 'германия'));
      expect(byCountry.total, 4);
      expect(byCountry.items.every((d) => d.country == 'Германия'), isTrue);
    });

    test('фильтр по стране и сортировка по году рождения', () async {
      final r = await designers.find(const DesignerQuery(
          country: 'США', sortField: 'birthYear', sortAscending: false));
      expect(r.items.map((d) => d.birthYear), [1973, 1963]);
    });

    test('deleteMany, restore и hardDelete авторов', () async {
      await designers.softDelete(1);
      expect(await designers.deleteMany([1, 2]), 1);
      await designers.restore(1);
      await designers.hardDelete(2);
      final r = await designers.find(const DesignerQuery(includeDeleted: true));
      expect(r.total, 11);
    });
  });
}
