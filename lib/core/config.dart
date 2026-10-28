/// Адрес сервера — параметр сборки, а не константа: на занятии он один,
/// дома другой, при публикации третий.
///
///   flutter run -d chrome --web-port 5555 --dart-define=API_BASE_URL=http://192.168.1.10:8080/api
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

/// Выход по бездействию, в секундах (по заданию — 3 минуты).
/// Для проверки: --dart-define=INACTIVITY_SECONDS=60
const inactivitySeconds = int.fromEnvironment('INACTIVITY_SECONDS', defaultValue: 180);

/// Ограничение общей длительности сессии, в минутах.
const sessionMaxMinutes = int.fromEnvironment('SESSION_MAX_MINUTES', defaultValue: 60);
