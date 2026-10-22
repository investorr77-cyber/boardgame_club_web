import 'package:shared_preferences/shared_preferences.dart';

/// Хранилище между перезагрузками страницы. На web shared_preferences
/// пишет в localStorage браузера.
///
/// Ключи имеют суффикс версии формата: `games_v2`. Когда состав полей
/// моделей меняется, версия увеличивается, и данные старого формата
/// не пытаются разобраться новым кодом.
class LocalStore {
  LocalStore(this._prefs);

  /// Текущая версия формата данных.
  static const formatVersion = 2;

  static final _versioned = RegExp(r'_v(\d+)$');

  final SharedPreferences _prefs;

  static String key(String name) => '${name}_v$formatVersion';

  String? read(String key) => _prefs.getString(key);

  Future<void> write(String key, String value) => _prefs.setString(key, value);

  /// Удаляет ключи прошлых версий формата. Возвращает сообщение
  /// для пользователя или null, если таких ключей не было.
  Future<String?> dropOutdated() async {
    final outdated = [
      for (final key in _prefs.getKeys())
        if (_versioned.firstMatch(key) case final match?
            when int.parse(match.group(1)!) < formatVersion)
          key,
    ];
    if (outdated.isEmpty) return null;
    for (final key in outdated) {
      await _prefs.remove(key);
    }
    return 'В браузере найдены данные старого формата (${outdated.join(', ')}). '
        'Они несовместимы с версией $formatVersion и удалены — '
        'загружен начальный набор.';
  }
}
