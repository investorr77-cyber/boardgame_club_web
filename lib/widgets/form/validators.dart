import 'package:flutter/widgets.dart';

// Валидаторы полей форм. Общие для всех пяти форм.
// Каждый возвращает текст ошибки (он показывается под полем) или null.
// Цепочку собирает [all]: показывается первая найденная ошибка.

int get currentYear => DateTime.now().year;

String _text(String? value) => value?.trim() ?? '';

FormFieldValidator<String> all(List<FormFieldValidator<String>> validators) =>
    (value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };

/// Обязательность заполнения.
FormFieldValidator<String> notEmpty([String message = 'Обязательное поле']) =>
    (value) => _text(value).isEmpty ? message : null;

/// Ограничение длины строки снизу.
FormFieldValidator<String> minLength(int min) => (value) {
      final text = _text(value);
      return text.isNotEmpty && text.length < min
          ? 'Слишком коротко: минимум $min симв.'
          : null;
    };

/// Ограничение длины строки сверху.
FormFieldValidator<String> maxLength(int max) => (value) =>
    _text(value).length > max ? 'Слишком длинно: максимум $max симв.' : null;

/// Целое число в диапазоне. Пустое значение пропускает — для него есть [notEmpty].
FormFieldValidator<String> intInRange(int min, int max) => (value) {
      final text = _text(value);
      if (text.isEmpty) return null;
      final number = int.tryParse(text);
      if (number == null) return 'Введите целое число';
      if (number < min || number > max) return 'Допустимо от $min до $max';
      return null;
    };

/// Положительное количество.
FormFieldValidator<String> positiveInt({int max = 1000000}) => (value) {
      final text = _text(value);
      if (text.isEmpty) return null;
      final number = int.tryParse(text);
      if (number == null) return 'Введите целое число';
      if (number <= 0) return 'Должно быть больше нуля';
      if (number > max) return 'Не больше $max';
      return null;
    };

/// Год не раньше [min] и не в будущем.
FormFieldValidator<String> year({int min = 1900, int? max}) =>
    intInRange(min, max ?? currentYear);

final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-z]{2,}$');

/// Формат почты. Пустое значение пропускает.
FormFieldValidator<String> email() => (value) {
      final text = _text(value);
      return text.isNotEmpty && !_emailPattern.hasMatch(text)
          ? 'Неверный формат почты, пример: name@example.com'
          : null;
    };

final _lettersPattern = RegExp(r"^[A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё\s'\-]*$");

/// Только буквы, пробел, дефис и апостроф (имена, страны, города).
FormFieldValidator<String> letters() => (value) {
      final text = _text(value);
      return text.isNotEmpty && !_lettersPattern.hasMatch(text)
          ? 'Только буквы, пробел и дефис'
          : null;
    };

/// Телефон в формате +7XXXXXXXXXX.
FormFieldValidator<String> phone() => (value) {
      final text = _text(value);
      return text.isNotEmpty && !RegExp(r'^\+7\d{10}$').hasMatch(text)
          ? 'Формат: +7XXXXXXXXXX (10 цифр после +7)'
          : null;
    };

/// Номер клубной карты вида BG-000123.
FormFieldValidator<String> cardNumber() => (value) {
      final text = _text(value).toUpperCase();
      return text.isNotEmpty && !RegExp(r'^BG-\d{6}$').hasMatch(text)
          ? 'Формат: BG- и 6 цифр, например BG-000123'
          : null;
    };

/// Штрихкод EAN-13 (аналог ISBN): 13 цифр и верная контрольная цифра.
FormFieldValidator<String> ean13() => (value) {
      final text = _text(value);
      if (text.isEmpty) return null;
      if (!RegExp(r'^\d{13}$').hasMatch(text)) return 'Ровно 13 цифр';
      var sum = 0;
      for (var i = 0; i < 12; i++) {
        final digit = text.codeUnitAt(i) - 48;
        sum += i.isEven ? digit : digit * 3;
      }
      final check = (10 - sum % 10) % 10;
      return text.codeUnitAt(12) - 48 == check
          ? null
          : 'Неверная контрольная цифра EAN-13 (ожидается $check)';
    };

/// Требования к паролю при регистрации. Те же правила проверяет сервер.
const passwordRules = <(String, bool Function(String))>[
  ('не короче 8 символов', _longEnough),
  ('есть цифра', _hasDigit),
  ('есть специальный символ (!, @, # …)', _hasSpecial),
];

bool _longEnough(String v) => v.length >= 8;
bool _hasDigit(String v) => RegExp(r'\d').hasMatch(v);
bool _hasSpecial(String v) => RegExp(r'[^A-Za-zА-Яа-яЁё0-9]').hasMatch(v);

/// Усиленная проверка пароля: длина ≥ 8, цифра, специальный символ.
FormFieldValidator<String> strongPassword() => (value) {
      final text = value ?? '';
      if (text.isEmpty) return 'Обязательное поле';
      for (final (label, ok) in passwordRules) {
        if (!ok(text)) return 'Пароль: $label';
      }
      return null;
    };

/// Логин: латиница, цифры и подчёркивание, 3–20 символов.
FormFieldValidator<String> username() => (value) {
      final text = _text(value);
      return text.isNotEmpty && !RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(text)
          ? 'Логин: 3–20 латинских букв, цифр или _'
          : null;
    };
