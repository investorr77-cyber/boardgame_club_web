import 'package:boardgame_club_web/models/publisher.dart';
import 'package:boardgame_club_web/models/simple_query.dart';
import 'package:boardgame_club_web/repositories/in_memory_board_game_repository.dart';
import 'package:boardgame_club_web/repositories/in_memory_reference_repositories.dart';
import 'package:boardgame_club_web/state/list_notifiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryBoardGameRepository games;
  late InMemoryPublisherRepository publishers;
  late InMemoryMemberRepository members;

  setUp(() {
    games = InMemoryBoardGameRepository(delay: Duration.zero);
    publishers = InMemoryPublisherRepository(delay: Duration.zero);
    members = InMemoryMemberRepository(delay: Duration.zero);
  });

  group('Уникальность', () {
    test('штрихкод игры: занят другой игрой, свободен для неё самой', () async {
      final game = (await games.findById(1))!;
      expect(await games.isBarcodeTaken(game.barcode), isTrue);
      expect(await games.isBarcodeTaken(game.barcode, exceptId: 1), isFalse);
      expect(await games.isBarcodeTaken('4600000000000'), isFalse);
    });

    test('почта и номер карты участника без учёта регистра', () async {
      expect(await members.isEmailTaken('ALEXEY.IVANOV@example.com'), isTrue);
      expect(
          await members.isEmailTaken('alexey.ivanov@example.com', exceptId: 1),
          isFalse);
      expect(await members.isCardNumberTaken('bg-000102'), isTrue);
      expect(await members.isCardNumberTaken('BG-999999'), isFalse);
    });
  });

  group('Удаление издателя со связанными играми', () {
    test('отказ с числом связанных записей', () async {
      final notifier = PublisherListNotifier(publishers, games);
      await notifier.load();
      final refusal = await notifier.hardDelete(1);
      expect(refusal, contains('Hobby World'));
      expect(refusal, contains('${await games.countByPublisher(1)} игр'));
      expect(await publishers.findById(1), isNotNull);
    });

    test('издателя без игр удалить можно', () async {
      final created = await publishers.create(const Publisher(
          id: 0, name: 'Новый', country: 'Россия', foundedYear: 2020));
      final notifier = PublisherListNotifier(publishers, games);
      await notifier.load();
      expect(await notifier.softDelete(created.id), isNull);
      expect((await publishers.findById(created.id))!.isDeleted, isTrue);
    });

    test('множественное удаление тоже проверяет связи', () async {
      final notifier = PublisherListNotifier(publishers, games);
      await notifier.load();
      notifier.toggleSelection(2);
      final outcome = await notifier.deleteSelected();
      expect(outcome.count, 0);
      expect(outcome.refusal, contains('Lavka Games'));
    });
  });

  test('поиск и фильтр участников по городу', () async {
    final result = await members.find(const SimpleQuery(
        defaultSortField: 'lastName', filter: 'Москва', search: 'ов'));
    expect(result.items, isNotEmpty);
    expect(result.items.every((m) => m.city == 'Москва'), isTrue);
  });
}
