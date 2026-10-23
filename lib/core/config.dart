/// Адрес сервера — параметр сборки, а не константа: на занятии он один,
/// дома другой, при публикации третий.
///
///   flutter run -d chrome --web-port 5555 --dart-define=API_BASE_URL=http://192.168.1.10:8080/api
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);
