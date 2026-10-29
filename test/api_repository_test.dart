import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:boardgame_club_web/core/api_client.dart';
import 'package:boardgame_club_web/core/api_exceptions.dart';
import 'package:boardgame_club_web/models/board_game.dart';
import 'package:boardgame_club_web/models/game_query.dart';
import 'package:boardgame_club_web/repositories/api/api_repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Подменённый транспорт Dio: вместо сети — функция, решающая, что ответить.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map<String, dynamic> gameJson(int id, {String title = 'Каркассон'}) => {
      'id': id,
      'title': title,
      'barcode': '4627110079192',
      'year': 2000,
      'playTimeMin': 35,
      'minPlayers': 2,
      'maxPlayers': 5,
      // Сервер отдаёт развёрнутые объекты связей, а не идентификаторы.
      'publisher': {'id': 1, 'name': 'Hobby World'},
      'designers': [
        {'id': 1, 'lastName': 'Вреде'},
      ],
      'genres': [
        {'id': 2, 'name': 'Семейная'},
        {'id': 5, 'name': 'Евроигра'},
      ],
      'copiesTotal': 4,
      'copiesAvailable': 3,
      'deletedAt': null,
    };

(ApiBoardGameRepository, FakeAdapter) repoWith(
    Future<ResponseBody> Function(RequestOptions o) handler) {
  final adapter = FakeAdapter(handler);
  final dio = buildDio(
    baseUrl: 'http://test/api',
    debugParams: const {},
    retryDelay: const Duration(milliseconds: 1),
    adapter: adapter,
  );
  return (ApiBoardGameRepository(dio), adapter);
}

void main() {
  test('find: условия отбора уходят на сервер, ответ разбирается в PageResult',
      () async {
    final (repo, adapter) = repoWith((o) async => json(200, {
          'items': [gameJson(1), gameJson(2, title: 'Азул')],
          'page': 2,
          'size': 10,
          'total': 12,
        }));
    final result = await repo.find(const GameQuery(
        search: ' кар ',
        genreId: 5,
        sortField: 'year',
        sortAscending: false,
        page: 2));

    final params = adapter.requests.single.queryParameters;
    expect(adapter.requests.single.path, '/games');
    expect(params['search'], 'кар');
    expect(params['genreId'], 5);
    expect(params['sort'], 'year,desc');
    expect(params['page'], 2);
    expect(result.items.map((g) => g.title), ['Каркассон', 'Азул']);
    expect(result.total, 12);
    expect(result.totalPages, 2);
  });

  test('fromJson: развёрнутые publisher/designers/genres → идентификаторы', () {
    final game = BoardGame.fromJson(gameJson(1));
    expect(game.publisherId, 1);
    expect(game.designerIds, [1]);
    expect(game.genreIds, [2, 5]);
  });

  test('422: ошибки по полям приходят как ValidationException', () async {
    final (repo, _) = repoWith((o) async => json(422, {
          'message': 'Данные не прошли проверку сервера',
          'errors': {'barcode': 'Игра с таким штрихкодом уже есть в каталоге'},
        }));
    await expectLater(
      repo.create(BoardGame.fromJson(gameJson(0))),
      throwsA(isA<ValidationException>().having((e) => e.errors['barcode'],
          'errors[barcode]', contains('штрихкодом'))),
    );
  });

  test('409: конфликт приходит как ConflictException с текстом сервера',
      () async {
    final (repo, _) = repoWith((o) async =>
        json(409, {'message': 'Нет свободных коробок «Пандемия: Наследие»'}));
    await expectLater(
      repo.checkout(8),
      throwsA(isA<ConflictException>().having(
          (e) => e.message, 'message', contains('Нет свободных коробок'))),
    );
  });

  test('404 в findById — null, а не исключение', () async {
    final (repo, _) =
        repoWith((o) async => json(404, {'message': 'не найдена'}));
    expect(await repo.findById(9999), isNull);
  });

  test('500 — ServerException с текстом сервера', () async {
    final (repo, _) = repoWith((o) async =>
        json(500, {'message': 'Сымитированная ошибка сервера (500)'}));
    await expectLater(
      repo.find(const GameQuery()),
      throwsA(isA<ServerException>()
          .having((e) => e.message, 'message', contains('Сымитированная'))),
    );
  });

  test('сервер недоступен: NetworkException, чтение повторяется 3 раза',
      () async {
    final (repo, adapter) = repoWith((o) async =>
        throw DioException.connectionError(
            requestOptions: o, reason: 'Connection refused'));
    await expectLater(
      repo.find(const GameQuery()),
      throwsA(isA<NetworkException>()
          .having((e) => e.message, 'message', contains('CORS'))),
    );
    expect(adapter.requests, hasLength(3));
  });

  test('создание записи при сбое сети не повторяется', () async {
    final (repo, adapter) = repoWith((o) async =>
        throw DioException.connectionError(
            requestOptions: o, reason: 'Connection refused'));
    await expectLater(repo.create(BoardGame.fromJson(gameJson(0))),
        throwsA(isA<NetworkException>()));
    expect(adapter.requests, hasLength(1));
  });

  test('устаревший запрос поиска отменяется', () async {
    final (repo, _) = repoWith((o) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return json(200, {
        'items': [gameJson(1, title: '${o.queryParameters['search']}')],
        'page': 1,
        'size': 10,
        'total': 1,
      });
    });
    final first = repo.find(const GameQuery(search: 'во'));
    final second = repo.find(const GameQuery(search: 'война'));
    await expectLater(
      first,
      throwsA(isA<NetworkException>()
          .having((e) => e.message, 'message', 'Запрос отменён.')),
    );
    expect((await second).items.single.title, 'война');
  });

  test('множественное удаление возвращает число удалённых', () async {
    final (repo, adapter) = repoWith((o) async => json(200, {'deleted': 2}));
    expect(await repo.deleteMany([1, 2, 3]), 2);
    expect(adapter.requests.single.path, '/games/bulk-delete');
    expect(adapter.requests.single.method, 'POST');
  });
}
