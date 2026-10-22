import 'dart:convert';

import 'package:boardgame_club_web/models/board_game.dart';
import 'package:boardgame_club_web/models/game_query.dart';
import 'package:boardgame_club_web/models/member.dart';
import 'package:boardgame_club_web/models/simple_query.dart';
import 'package:boardgame_club_web/repositories/in_memory_board_game_repository.dart';
import 'package:boardgame_club_web/repositories/in_memory_reference_repositories.dart';
import 'package:boardgame_club_web/repositories/local_store.dart';
import 'package:boardgame_club_web/repositories/seed/seed_games.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('toJson / fromJson', () {
    test('игра: туда и обратно без потерь', () {
      final game = buildSeedGames().first.copyWith(deletedAt: DateTime(2026, 10, 1));
      final back = BoardGame.fromJson(jsonDecode(jsonEncode(game.toJson())));
      expect(back.toJson(), game.toJson());
    });

    test('игра: отсутствующие поля, null и чужие типы не роняют разбор', () {
      final game = BoardGame.fromJson({
        'id': '7',
        'title': null,
        'year': 'не число',
        'designerIds': [1, '2', null, 'x'],
        'genreIds': 'не список',
        'deletedAt': 'не дата',
      });
      expect(game.id, 7);
      expect(game.title, '');
      expect(game.year, 0);
      expect(game.designerIds, [1, 2]);
      expect(game.genreIds, isEmpty);
      expect(game.deletedAt, isNull);
      expect(game.minPlayers, 1);
    });

    test('участник с вложенной картой; без карты — карта по умолчанию', () {
      const member = Member(
        id: 1,
        lastName: 'Иванов',
        firstName: 'Иван',
        email: 'ivan@example.com',
        phone: '+79001234567',
        city: 'Москва',
        card: MemberCard(number: 'BG-000001', issuedYear: 2024, maxGames: 3),
      );
      final back = Member.fromJson(jsonDecode(jsonEncode(member.toJson())));
      expect(back.card.number, 'BG-000001');
      expect(back.card.maxGames, 3);

      final noCard = Member.fromJson({'id': 2, 'lastName': 'Петров'});
      expect(noCard.card.number, '');
      expect(noCard.card.maxGames, 1);
    });
  });

  group('Сохранение между перезагрузками', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<LocalStore> store() async =>
        LocalStore(await SharedPreferences.getInstance());

    test('созданная запись видна после «перезагрузки» (новый репозиторий)', () async {
      final s = await store();
      final first = InMemoryBoardGameRepository(store: s, delay: Duration.zero);
      final created = await first.create(
          buildSeedGames().first.copyWith(title: 'Новая игра', barcode: ean13(99)));
      await first.softDelete(2);

      final reloaded = InMemoryBoardGameRepository(store: s, delay: Duration.zero);
      expect((await reloaded.findById(created.id))?.title, 'Новая игра');
      expect((await reloaded.findById(2))?.isDeleted, isTrue);
      expect((await reloaded.find(const GameQuery())).total, 30);
    });

    test('испорченные данные: начальный набор и сообщение, без падения', () async {
      SharedPreferences.setMockInitialValues({LocalStore.key('games'): '{oops'});
      final repo = InMemoryBoardGameRepository(store: await store(), delay: Duration.zero);
      expect((await repo.find(const GameQuery())).total, 30);
      expect(repo.restoreNotice, contains('не удалось прочитать'));
    });

    test('данные старой версии формата удаляются с сообщением', () async {
      SharedPreferences.setMockInitialValues({
        'games_v1': '[{"name": "старый формат"}]',
        LocalStore.key('members'): '[]',
      });
      final s = await store();
      final notice = await s.dropOutdated();
      expect(notice, contains('games_v1'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('games_v1'), isFalse);
      expect(prefs.containsKey(LocalStore.key('members')), isTrue);
      expect(await s.dropOutdated(), isNull);
    });

    test('сброс к начальному набору', () async {
      final repo = InMemoryMemberRepository(store: await store(), delay: Duration.zero);
      await repo.hardDelete(1);
      await repo.reset();
      expect((await repo.find(const SimpleQuery(defaultSortField: 'lastName'))).total, 12);
    });
  });
}
