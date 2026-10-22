import 'package:boardgame_club_web/repositories/seed/seed_games.dart' as seed;
import 'package:boardgame_club_web/widgets/form/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Валидаторы', () {
    test('обязательность и длина строки', () {
      final title = all([notEmpty(), minLength(2), maxLength(10)]);
      expect(title(''), 'Обязательное поле');
      expect(title('   '), 'Обязательное поле');
      expect(title('А'), contains('минимум 2'));
      expect(title('Очень длинное название'), contains('максимум 10'));
      expect(title('Азул'), isNull);
    });

    test('диапазон чисел и положительность количества', () {
      final players = intInRange(1, 20);
      expect(players('abc'), 'Введите целое число');
      expect(players('0'), 'Допустимо от 1 до 20');
      expect(players('5'), isNull);
      expect(players(''), isNull, reason: 'пустое значение проверяет notEmpty');

      final copies = positiveInt(max: 100);
      expect(copies('0'), 'Должно быть больше нуля');
      expect(copies('-3'), 'Должно быть больше нуля');
      expect(copies('101'), 'Не больше 100');
      expect(copies('4'), isNull);
    });

    test('год не в будущем', () {
      expect(year()('${currentYear + 1}'), contains('Допустимо'));
      expect(year()('1899'), contains('Допустимо'));
      expect(year()('2015'), isNull);
    });

    test('формат почты', () {
      expect(email()('ivan@example.com'), isNull);
      expect(email()('ivan@example'), contains('Неверный формат'));
      expect(email()('ivan.example.com'), contains('Неверный формат'));
      expect(email()(''), isNull, reason: 'почта издателя необязательна');
    });

    test('штрихкод EAN-13: длина и контрольная цифра', () {
      expect(ean13()('123'), 'Ровно 13 цифр');
      expect(ean13()(ean13FromSeed), isNull);
      final broken = '${ean13FromSeed.substring(0, 12)}'
          '${(int.parse(ean13FromSeed[12]) + 1) % 10}';
      expect(ean13()(broken), contains('контрольная цифра'));
    });

    test('телефон, номер карты, только буквы', () {
      expect(phone()('+79001234567'), isNull);
      expect(phone()('89001234567'), contains('+7'));
      expect(cardNumber()('BG-000123'), isNull);
      expect(cardNumber()('bg-000123'), isNull, reason: 'регистр не важен');
      expect(cardNumber()('BG-12'), contains('BG-'));
      expect(letters()('Санкт-Петербург'), isNull);
      expect(letters()('Москва1'), 'Только буквы, пробел и дефис');
    });

    test('all возвращает первую ошибку', () {
      final v = all([notEmpty('нет значения'), email()]);
      expect(v(''), 'нет значения');
      expect(v('x'), contains('Неверный формат'));
    });
  });
}

/// Штрихкод из начального набора — заведомо правильный EAN-13.
final ean13FromSeed = seed.ean13(1);
