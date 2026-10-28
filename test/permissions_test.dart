import 'dart:convert';
import 'dart:typed_data';

import 'package:boardgame_club_web/core/api_client.dart';
import 'package:boardgame_club_web/core/api_exceptions.dart';
import 'package:boardgame_club_web/models/app_user.dart';
import 'package:boardgame_club_web/models/game_query.dart';
import 'package:boardgame_club_web/models/permissions.dart';
import 'package:boardgame_club_web/repositories/api/api_repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Права ролей', () {
    test('участник: каталог и свои выдачи, но не правка и не администрирование', () {
      expect(can(Role.member, Operation.viewCatalog), isTrue);
      expect(can(Role.member, Operation.viewOwnLoans), isTrue);
      expect(can(Role.member, Operation.extendLoan), isTrue);
      expect(can(Role.member, Operation.editCatalog), isFalse);
      expect(can(Role.member, Operation.viewMembers), isFalse);
      expect(can(Role.member, Operation.manageUsers), isFalse);
    });

    test('сотрудник: каталог, выдачи, участники; без физического удаления', () {
      expect(can(Role.staff, Operation.editCatalog), isTrue);
      expect(can(Role.staff, Operation.softDelete), isTrue);
      expect(can(Role.staff, Operation.issueLoans), isTrue);
      expect(can(Role.staff, Operation.manageMembers), isTrue);
      expect(can(Role.staff, Operation.hardDelete), isFalse);
      expect(can(Role.staff, Operation.restore), isFalse);
      expect(can(Role.staff, Operation.viewOwnLoans), isFalse);
    });

    test('администратор: пользователи, роли, восстановление, статистика', () {
      expect(can(Role.admin, Operation.manageUsers), isTrue);
      expect(can(Role.admin, Operation.hardDelete), isTrue);
      expect(can(Role.admin, Operation.restore), isTrue);
      expect(can(Role.admin, Operation.viewStats), isTrue);
      expect(can(Role.admin, Operation.editCatalog), isFalse);
    });

    test('у каждой роли есть операция, недоступная остальным', () {
      for (final role in Role.values) {
        final own = Operation.values.where((op) => permissions[op]!.length == 1 && can(role, op));
        expect(own, isNotEmpty, reason: role.name);
      }
    });

    test('без входа недоступно ничего', () {
      for (final op in Operation.values) {
        expect(can(null, op), isFalse, reason: op.name);
      }
    });

    test('неизвестная роль из ответа — самая слабая', () {
      expect(Role.parse('superuser'), Role.member);
      expect(Role.parse('admin'), Role.admin);
    });
  });

  group('Защита маршрутов', () {
    String? go(Role? role, String location) => authRedirect(role: role, uri: Uri.parse(location));

    test('без входа — на вход с запоминанием адреса', () {
      expect(go(null, '/games/5'), '/login?from=%2Fgames%2F5');
      expect(go(null, '/login'), isNull);
      expect(go(null, '/register'), isNull);
    });

    test('вошедший на экране входа — на главную', () {
      expect(go(Role.member, '/login'), '/');
    });

    test('чужой адрес вручную — экран отказа', () {
      expect(go(Role.member, '/games/new'), startsWith('/forbidden'));
      expect(go(Role.member, '/members'), startsWith('/forbidden'));
      expect(go(Role.member, '/admin/users'), startsWith('/forbidden'));
      expect(go(Role.staff, '/admin/stats'), startsWith('/forbidden'));
      expect(go(Role.staff, '/my-loans'), startsWith('/forbidden'));
      expect(go(Role.admin, '/games/3/edit'), startsWith('/forbidden'));
    });

    test('свой адрес — переход разрешён', () {
      expect(go(Role.member, '/games?sort=year,desc'), isNull);
      expect(go(Role.member, '/my-loans'), isNull);
      expect(go(Role.staff, '/games/3/edit'), isNull);
      expect(go(Role.staff, '/loans'), isNull);
      expect(go(Role.admin, '/admin/users'), isNull);
      expect(go(Role.admin, '/members'), isNull);
    });
  });

  group('Обновление токена (401)', () {
    late List<String> requests; // заголовок Authorization каждого запроса
    late int refreshCalls;

    Dio dioWith(int Function(RequestOptions o) status, {required bool refreshOk}) {
      requests = [];
      refreshCalls = 0;
      var token = 'old';
      return buildDio(
        baseUrl: 'http://test/api',
        debugParams: const {},
        tokenProvider: () => token,
        refreshSession: () async {
          refreshCalls++;
          if (refreshOk) token = 'new';
          return refreshOk;
        },
        adapter: _Adapter((o) {
          requests.add('${o.headers['Authorization']}');
          final code = status(o);
          return ResponseBody.fromString(
            jsonEncode(code == 200
                ? {'items': [], 'page': 1, 'size': 10, 'total': 0}
                : {'message': 'Требуется вход в систему.'}),
            code,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }),
      );
    }

    test('истёкший токен обновляется, запрос повторяется прозрачно', () async {
      final dio = dioWith(
          (o) => o.headers['Authorization'] == 'Bearer new' ? 200 : 401,
          refreshOk: true);
      final page = await ApiBoardGameRepository(dio).find(const GameQuery());
      expect(page.total, 0);
      expect(refreshCalls, 1);
      expect(requests, ['Bearer old', 'Bearer new']);
    });

    test('неудачное обновление — выход без зацикливания', () async {
      final dio = dioWith((o) => 401, refreshOk: false);
      await expectLater(ApiBoardGameRepository(dio).find(const GameQuery()),
          throwsA(isA<UnauthorizedException>()));
      expect(refreshCalls, 1);
      expect(requests, hasLength(1));
    });

    test('401 на /auth/login не запускает обновление токена', () async {
      final dio = dioWith((o) => 401, refreshOk: true);
      await expectLater(guard(() => dio.post<Object?>('/auth/login', data: {})),
          throwsA(isA<UnauthorizedException>()));
      expect(refreshCalls, 0);
    });
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
          Future<void>? cancelFuture) async =>
      handler(options);

  @override
  void close({bool force = false}) {}
}
