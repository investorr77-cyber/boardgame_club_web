// Генерирует supabase/seed.sql из начального набора сервера (server/seed.js),
// чтобы данные в Supabase совпадали с прошлыми работами.
//   node supabase/make-seed.js
const fs = require('fs');
const path = require('path');
const seed = require('../server/seed.js')();

const q = (v) => (v === null || v === undefined ? 'null' : typeof v === 'number' ? String(v) : `'${String(v).replace(/'/g, "''")}'`);
const rows = (list) => list.map((r) => `  (${r.map(q).join(', ')})`).join(',\n');

const out = [
  '-- Начальные данные клуба. Сгенерировано: node supabase/make-seed.js',
  'truncate public.loans, public.member_cards, public.members, public.game_genres,',
  '  public.game_designers, public.games, public.designers, public.genres, public.publishers restart identity cascade;',
  '',
  'insert into public.publishers (id, name, country, founded_year, email) values',
  rows(seed.publishers.map((p) => [p.id, p.name, p.country, p.foundedYear, p.email])) + ';',
  'insert into public.genres (id, name, description) values',
  rows(seed.genres.map((g) => [g.id, g.name, g.description])) + ';',
  'insert into public.designers (id, last_name, first_name, country, birth_year) values',
  rows(seed.designers.map((d) => [d.id, d.lastName, d.firstName, d.country, d.birthYear])) + ';',
  'insert into public.games (id, title, barcode, year, play_time_min, min_players, max_players, publisher_id, copies_total, copies_available) values',
  rows(seed.games.map((g) => [g.id, g.title, g.barcode, g.year, g.playTimeMin, g.minPlayers, g.maxPlayers, g.publisherId, g.copiesTotal, g.copiesAvailable])) + ';',
  'insert into public.game_designers (game_id, designer_id) values',
  rows(seed.games.flatMap((g) => g.designerIds.map((d) => [g.id, d]))) + ';',
  'insert into public.game_genres (game_id, genre_id) values',
  rows(seed.games.flatMap((g) => g.genreIds.map((d) => [g.id, d]))) + ';',
  'insert into public.members (id, last_name, first_name, email, phone, city) values',
  rows(seed.members.map((m) => [m.id, m.lastName, m.firstName, m.email, m.phone, m.city])) + ';',
  'insert into public.member_cards (member_id, number, issued_year, max_games) values',
  rows(seed.members.map((m) => [m.id, m.card.number, m.card.issuedYear, m.card.maxGames])) + ';',
  '',
  '-- Счётчики идентификаторов продолжаются после начальных записей.',
  ...['publishers', 'genres', 'designers', 'games', 'members'].map(
    (t) => `select setval(pg_get_serial_sequence('public.${t}', 'id'), (select max(id) from public.${t}));`,
  ),
  '',
];
fs.writeFileSync(path.join(__dirname, 'seed.sql'), out.join('\n'));
console.log('seed.sql готов');
