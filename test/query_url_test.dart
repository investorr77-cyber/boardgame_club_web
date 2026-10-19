import 'package:boardgame_club_web/models/designer_query.dart';
import 'package:boardgame_club_web/models/game_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameQuery.copyWith', () {
    test('смена фильтра сбрасывает page в 1', () {
      const q = GameQuery(page: 3);
      expect(q.copyWith(genreId: 2).page, 1);
      expect(q.copyWith(search: 'азул').page, 1);
      expect(q.copyWith(size: 25).page, 1);
      expect(q.copyWith(sortField: 'year').page, 1);
    });

    test('явный page сохраняется, вызов без изменений page не трогает', () {
      const q = GameQuery(page: 3, genreId: 1);
      expect(q.copyWith(page: 2).page, 2);
      expect(q.copyWith().page, 3);
    });

    test('copyWith(genreId: null) сбрасывает фильтр, без аргумента — сохраняет',
        () {
      const q = GameQuery(genreId: 4, publisherId: 2);
      expect(q.copyWith(genreId: null).genreId, isNull);
      expect(q.copyWith(genreId: null).publisherId, 2);
      expect(q.copyWith().genreId, 4);
      expect(q.copyWith(search: 'x').genreId, 4);
    });
  });

  group('GameQuery <-> URL', () {
    test('Query → URL → Query даёт равный объект', () {
      const q = GameQuery(
        search: 'каркассон',
        genreId: 2,
        publisherId: 1,
        yearFrom: 2000,
        yearTo: 2015,
        sortField: 'year',
        sortAscending: false,
        page: 2,
        size: 25,
        includeDeleted: true,
      );
      final params = q.toQueryParameters();
      expect(params, {
        'search': 'каркассон',
        'genreId': '2',
        'publisherId': '1',
        'yearFrom': '2000',
        'yearTo': '2015',
        'sort': 'year,desc',
        'page': '2',
        'size': '25',
        'deleted': '1',
      });
      final back = GameQuery.fromQueryParameters(params);
      expect(back, q);
      expect(back.hashCode, q.hashCode);
    });

    test('в адрес пишутся только параметры, отличные от умолчаний', () {
      expect(const GameQuery().toQueryParameters(), isEmpty);
      expect(const GameQuery(genreId: 3).toQueryParameters(), {'genreId': '3'});
    });

    test('мусор в адресе не ломает разбор', () {
      final q = GameQuery.fromQueryParameters({
        'page': 'abc',
        'size': '7',
        'sort': 'foo,bar',
        'genreId': '-1',
        'yearFrom': 'год',
        'deleted': 'maybe',
      });
      expect(q, const GameQuery());
      expect(GameQuery.fromQueryParameters({'sort': 'year,sideways'}).sortField,
          'title');
      expect(GameQuery.fromQueryParameters({'sort': 'playTimeMin'}).sortField,
          'playTimeMin');
    });
  });

  group('DesignerQuery <-> URL', () {
    test('Query → URL → Query даёт равный объект', () {
      const q = DesignerQuery(
        search: 'вреде',
        country: 'Германия',
        sortField: 'birthYear',
        sortAscending: false,
        page: 2,
        size: 10,
        includeDeleted: true,
      );
      expect(DesignerQuery.fromQueryParameters(q.toQueryParameters()), q);
    });

    test('мусор в адресе не ломает разбор; copyWith(country: null)', () {
      final q = DesignerQuery.fromQueryParameters(
          {'page': '0', 'size': '100', 'sort': 'lastName,up', 'country': '  '});
      expect(q, const DesignerQuery());
      const withCountry = DesignerQuery(country: 'США', page: 2);
      expect(withCountry.copyWith(country: null).country, isNull);
      expect(withCountry.copyWith(country: null).page, 1);
      expect(withCountry.copyWith().country, 'США');
    });
  });
}
