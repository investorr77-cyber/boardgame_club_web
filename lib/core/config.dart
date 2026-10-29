/// Адрес сервера — параметр сборки, а не константа: на занятии он один,
/// дома другой, при публикации третий.
///
///   flutter run -d chrome --web-port 5555 --dart-define=API_BASE_URL=http://192.168.1.10:8080/api
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

/// Источник данных: `supabase` (итоговый проект) или `rest` — свой сервер
/// из ПР4–ПР6 (server/mock-server.js).
///
///   flutter run -d chrome --web-port 5555 --dart-define=BACKEND=rest
const backend = String.fromEnvironment('BACKEND', defaultValue: 'supabase');

bool get useSupabase => backend == 'supabase';

/// Проект Supabase. Публикуемый ключ (publishable) не секретный: он виден
/// в браузере любому, а доступ к данным ограничивают политики RLS в базе.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://wzxfwqhsuunrdtluemjg.supabase.co',
);
const supabaseKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_2yc51PzzQ_EHN_LqGIHWLw__H7YOpRP',
);

/// Supabase Auth входит по почте. Логин без «@» превращается в служебный
/// адрес в зарезервированном домене .test — письма на него не отправляются.
const loginEmailDomain = 'boardgame-club.test';

/// Выход по бездействию, в секундах (по заданию — 3 минуты).
/// Для проверки: --dart-define=INACTIVITY_SECONDS=60
const inactivitySeconds =
    int.fromEnvironment('INACTIVITY_SECONDS', defaultValue: 180);

/// Ограничение общей длительности сессии, в минутах.
const sessionMaxMinutes =
    int.fromEnvironment('SESSION_MAX_MINUTES', defaultValue: 60);
