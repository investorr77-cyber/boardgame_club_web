#!/usr/bin/env node
// Учебный REST-сервер клуба настольных игр (ПР4). Без зависимостей: node mock-server.js
//
//   node mock-server.js --port 8080 --origin http://localhost:5555
//
// Данные хранятся в памяти сервера (начальный набор — seed.js).
// Служебные параметры любого запроса:
//   ?__fail=500    — ответить указанным кодом ошибки
//   ?__delay=1500  — задержать ответ на N миллисекунд
// CORS разрешён только для источника из --origin: клиент с другого порта
// получит ошибку CORS в консоли браузера.

const http = require('http');
const seed = require('./seed');

const args = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const PORT = Number(arg('port', 8080));
const ORIGIN = arg('origin', 'http://localhost:5555');

let db = seed();

// ---------- вспомогательные функции ----------

class HttpError extends Error {
  constructor(status, message, errors) {
    super(message);
    this.status = status;
    this.errors = errors;
  }
}

const notFound = (what) => new HttpError(404, `${what}: запись не найдена.`);
const nextId = (list) => list.reduce((max, item) => Math.max(max, item.id), 0) + 1;
const text = (v) => (typeof v === 'string' ? v.trim() : '');
const int = (v) => (Number.isInteger(v) ? v : typeof v === 'string' && /^-?\d+$/.test(v) ? Number(v) : null);
const currentYear = new Date().getFullYear();
const EMAIL = /^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-z]{2,}$/;

function eanValid(code) {
  if (!/^\d{13}$/.test(code)) return false;
  let sum = 0;
  for (let i = 0; i < 12; i++) sum += Number(code[i]) * (i % 2 === 0 ? 1 : 3);
  return Number(code[12]) === (10 - (sum % 10)) % 10;
}

function requireText(errors, body, field, label, min, max) {
  const value = text(body[field]);
  if (!value) errors[field] = `${label}: обязательное поле`;
  else if (value.length < min || value.length > max) errors[field] = `${label}: от ${min} до ${max} символов`;
  return value;
}

function requireInt(errors, body, field, label, min, max) {
  const value = int(body[field]);
  if (value === null) errors[field] = `${label}: нужно целое число`;
  else if (value < min || value > max) errors[field] = `${label}: допустимо от ${min} до ${max}`;
  return value;
}

function fail(errors) {
  if (Object.keys(errors).length > 0) {
    throw new HttpError(422, 'Данные не прошли проверку сервера', errors);
  }
}

// ---------- описание ресурсов ----------

const expandGame = (g) => {
  // На чтение уходят развёрнутые объекты связей, на запись приходят идентификаторы.
  const { publisherId, designerIds, genreIds, ...rest } = g;
  return {
    ...rest,
    publisher: db.publishers.find((p) => p.id === publisherId) ?? { id: publisherId },
    designers: designerIds.map((id) => db.designers.find((d) => d.id === id) ?? { id }),
    genres: genreIds.map((id) => db.genres.find((x) => x.id === id) ?? { id }),
  };
};

const resources = {
  games: {
    label: 'Игра',
    search: (g, s) => g.title.toLowerCase().includes(s) || g.barcode.includes(s),
    filter: (g, q) =>
      (!q.get('genreId') || g.genreIds.includes(Number(q.get('genreId')))) &&
      (!q.get('publisherId') || g.publisherId === Number(q.get('publisherId'))) &&
      (!q.get('designerId') || g.designerIds.includes(Number(q.get('designerId')))) &&
      (!q.get('yearFrom') || g.year >= Number(q.get('yearFrom'))) &&
      (!q.get('yearTo') || g.year <= Number(q.get('yearTo'))),
    sort: { title: (g) => g.title.toLowerCase(), year: (g) => g.year, playTimeMin: (g) => g.playTimeMin },
    defaultSort: 'title',
    toResponse: expandGame,
    validate(body, id) {
      const e = {};
      const title = requireText(e, body, 'title', 'Название', 2, 100);
      const barcode = text(body.barcode);
      if (!barcode) e.barcode = 'Штрихкод: обязательное поле';
      else if (!eanValid(barcode)) e.barcode = 'Штрихкод: неверный EAN-13';
      else if (db.games.some((g) => g.barcode === barcode && g.id !== id)) {
        e.barcode = 'Игра с таким штрихкодом уже есть в каталоге';
      }
      const year = requireInt(e, body, 'year', 'Год издания', 1900, currentYear);
      const playTimeMin = requireInt(e, body, 'playTimeMin', 'Время партии', 1, 1440);
      const minPlayers = requireInt(e, body, 'minPlayers', 'Игроков от', 1, 20);
      const maxPlayers = requireInt(e, body, 'maxPlayers', 'Игроков до', 1, 100);
      if (minPlayers !== null && maxPlayers !== null && maxPlayers < minPlayers) {
        e.maxPlayers = 'Игроков до: не меньше, чем «от»';
      }
      const copiesTotal = requireInt(e, body, 'copiesTotal', 'Коробок в клубе', 1, 100);
      const copiesAvailable = requireInt(e, body, 'copiesAvailable', 'Свободно', 0, 100);
      if (copiesTotal !== null && copiesAvailable !== null && copiesAvailable > copiesTotal) {
        e.copiesAvailable = 'Свободно: не больше, чем коробок в клубе';
      }
      const publisherId = int(body.publisherId);
      if (!db.publishers.some((p) => p.id === publisherId && !p.deletedAt)) e.publisherId = 'Издатель не найден';
      const ids = (v) => (Array.isArray(v) ? v.map(int).filter((x) => x !== null) : []);
      const designerIds = ids(body.designerIds);
      const genreIds = ids(body.genreIds);
      if (designerIds.length === 0 || designerIds.some((d) => !db.designers.some((x) => x.id === d))) {
        e.designerIds = 'Укажите существующих авторов';
      }
      if (genreIds.length === 0 || genreIds.some((g) => !db.genres.some((x) => x.id === g))) {
        e.genreIds = 'Укажите существующие жанры';
      }
      fail(e);
      return { title, barcode, year, playTimeMin, minPlayers, maxPlayers, publisherId, designerIds, genreIds, copiesTotal, copiesAvailable };
    },
  },
  designers: {
    label: 'Автор',
    search: (d, s) => d.lastName.toLowerCase().includes(s) || d.country.toLowerCase().includes(s),
    filter: (d, q) => !q.get('country') || d.country === q.get('country'),
    sort: { lastName: (d) => d.lastName.toLowerCase(), birthYear: (d) => d.birthYear, country: (d) => d.country },
    defaultSort: 'lastName',
    validate(body) {
      const e = {};
      const lastName = requireText(e, body, 'lastName', 'Фамилия', 2, 40);
      const firstName = requireText(e, body, 'firstName', 'Имя', 2, 40);
      const country = requireText(e, body, 'country', 'Страна', 2, 40);
      const birthYear = requireInt(e, body, 'birthYear', 'Год рождения', 1900, currentYear - 10);
      fail(e);
      return { lastName, firstName, country, birthYear };
    },
  },
  genres: {
    label: 'Жанр',
    search: (g, s) => g.name.toLowerCase().includes(s) || g.description.toLowerCase().includes(s),
    filter: () => true,
    sort: { name: (g) => g.name.toLowerCase() },
    defaultSort: 'name',
    validate(body, id) {
      const e = {};
      const name = requireText(e, body, 'name', 'Название', 3, 40);
      if (name && db.genres.some((g) => g.name.toLowerCase() === name.toLowerCase() && g.id !== id)) {
        e.name = 'Жанр с таким названием уже есть';
      }
      const description = text(body.description);
      if (description.length > 200) e.description = 'Описание: до 200 символов';
      fail(e);
      return { name, description };
    },
  },
  publishers: {
    label: 'Издатель',
    search: (p, s) => p.name.toLowerCase().includes(s) || p.country.toLowerCase().includes(s),
    filter: (p, q) => !q.get('country') || p.country === q.get('country'),
    sort: { name: (p) => p.name.toLowerCase(), country: (p) => p.country, foundedYear: (p) => p.foundedYear },
    defaultSort: 'name',
    validate(body) {
      const e = {};
      const name = requireText(e, body, 'name', 'Название', 2, 60);
      const country = requireText(e, body, 'country', 'Страна', 2, 40);
      const foundedYear = requireInt(e, body, 'foundedYear', 'Год основания', 1800, currentYear);
      const email = text(body.email);
      if (email && !EMAIL.test(email)) e.email = 'Почта: неверный формат';
      fail(e);
      return { name, country, foundedYear, email };
    },
    // 409: на издателя ссылаются игры — удалять нельзя.
    beforeDelete(p) {
      const count = db.games.filter((g) => g.publisherId === p.id).length;
      if (count > 0) {
        throw new HttpError(409, `Нельзя удалить издателя «${p.name}»: на него ссылаются игры (${count} шт.).`);
      }
    },
  },
  members: {
    label: 'Участник',
    search: (m, s) =>
      m.lastName.toLowerCase().includes(s) || m.email.toLowerCase().includes(s) ||
      m.card.number.toLowerCase().includes(s),
    filter: (m, q) => !q.get('city') || m.city === q.get('city'),
    sort: { lastName: (m) => m.lastName.toLowerCase(), city: (m) => m.city, email: (m) => m.email },
    defaultSort: 'lastName',
    validate(body, id) {
      const e = {};
      const lastName = requireText(e, body, 'lastName', 'Фамилия', 2, 40);
      const firstName = requireText(e, body, 'firstName', 'Имя', 2, 40);
      const email = text(body.email).toLowerCase();
      if (!EMAIL.test(email)) e.email = 'Почта: неверный формат';
      else if (db.members.some((m) => m.email.toLowerCase() === email && m.id !== id)) {
        e.email = 'Участник с такой почтой уже зарегистрирован';
      }
      const phone = text(body.phone);
      if (!/^\+7\d{10}$/.test(phone)) e.phone = 'Телефон: формат +7XXXXXXXXXX';
      const city = requireText(e, body, 'city', 'Город', 2, 40);
      const card = body.card && typeof body.card === 'object' ? body.card : {};
      const number = text(card.number).toUpperCase();
      if (!/^BG-\d{6}$/.test(number)) e['card.number'] = 'Номер карты: формат BG-XXXXXX';
      else if (db.members.some((m) => m.card.number === number && m.id !== id)) {
        e['card.number'] = 'Карта с таким номером уже выдана';
      }
      const issuedYear = requireInt(e, card, 'issuedYear', 'Год выдачи', 2000, currentYear);
      if (e.issuedYear) e['card.issuedYear'] = e.issuedYear;
      delete e.issuedYear;
      const maxGames = requireInt(e, card, 'maxGames', 'Лимит игр', 1, 10);
      if (e.maxGames) e['card.maxGames'] = e.maxGames;
      delete e.maxGames;
      fail(e);
      return { lastName, firstName, email, phone, city, card: { number, issuedYear, maxGames } };
    },
  },
};

// ---------- обработка запросов ----------

function list(name, q) {
  const r = resources[name];
  const search = (q.get('search') ?? '').trim().toLowerCase();
  const includeDeleted = q.get('includeDeleted') === 'true';
  const [field, dir] = (q.get('sort') ?? r.defaultSort).split(',');
  const key = r.sort[field] ?? r.sort[r.defaultSort];
  const sign = dir === 'desc' ? -1 : 1;
  const page = Math.max(1, int(q.get('page')) ?? 1);
  const size = Math.min(1000, Math.max(1, int(q.get('size')) ?? 10));
  const filtered = db[name]
    .filter((x) => includeDeleted || !x.deletedAt)
    .filter((x) => !search || r.search(x, search))
    .filter((x) => r.filter(x, q))
    .sort((a, b) => {
      const ka = key(a);
      const kb = key(b);
      const c = ka < kb ? -1 : ka > kb ? 1 : a.id - b.id;
      return c * sign;
    });
  const start = (page - 1) * size;
  const items = filtered.slice(start, start + size).map((x) => (r.toResponse ? r.toResponse(x) : x));
  return { items, page, size, total: filtered.length };
}

function find(name, id) {
  const item = db[name].find((x) => x.id === id);
  if (!item) throw notFound(resources[name].label);
  return item;
}

const respond = (name, item) => (resources[name].toResponse ? resources[name].toResponse(item) : item);

function route(method, parts, q, body) {
  const [name, idPart, action] = parts;
  if (name === '__health' && method === 'GET') return [200, { status: 'ok', time: new Date().toISOString() }];
  if (name === '__reset' && method === 'POST') {
    db = seed();
    return [200, { status: 'reset' }];
  }
  const r = resources[name];
  if (!r) throw new HttpError(404, `Неизвестный адрес /api/${parts.join('/')}`);

  if (!idPart) {
    if (method === 'GET') return [200, list(name, q)];
    if (method === 'POST') {
      const data = r.validate(body ?? {}, null);
      const item = { id: nextId(db[name]), ...data, deletedAt: null };
      db[name].push(item);
      return [201, respond(name, item)];
    }
  }

  if (idPart === 'bulk-delete' && method === 'POST') {
    const ids = Array.isArray(body?.ids) ? body.ids.map(int).filter((x) => x !== null) : [];
    const targets = db[name].filter((x) => ids.includes(x.id) && !x.deletedAt);
    if (r.beforeDelete) targets.forEach((x) => r.beforeDelete(x));
    const now = new Date().toISOString();
    targets.forEach((x) => (x.deletedAt = now));
    return [200, { deleted: targets.length }];
  }

  const id = int(idPart);
  if (id === null) throw new HttpError(404, `Некорректный идентификатор «${idPart}»`);
  const item = find(name, id);

  if (!action) {
    if (method === 'GET') return [200, respond(name, item)];
    if (method === 'PUT') {
      Object.assign(item, r.validate(body ?? {}, id));
      return [200, respond(name, item)];
    }
    if (method === 'DELETE') {
      if (r.beforeDelete) r.beforeDelete(item);
      if (q.get('hard') === 'true') db[name] = db[name].filter((x) => x.id !== id);
      else item.deletedAt = item.deletedAt ?? new Date().toISOString();
      return [204, null];
    }
  }
  if (action === 'restore' && method === 'POST') {
    item.deletedAt = null;
    return [200, respond(name, item)];
  }
  // 409: выдать игру, у которой нет свободных коробок, нельзя.
  if (name === 'games' && action === 'checkout' && method === 'POST') {
    if (item.copiesAvailable <= 0) {
      throw new HttpError(409, `Нет свободных коробок «${item.title}»: все ${item.copiesTotal} на руках.`);
    }
    item.copiesAvailable -= 1;
    return [200, respond(name, item)];
  }
  if (name === 'games' && action === 'return' && method === 'POST') {
    if (item.copiesAvailable >= item.copiesTotal) {
      throw new HttpError(409, `Все коробки «${item.title}» уже в клубе.`);
    }
    item.copiesAvailable += 1;
    return [200, respond(name, item)];
  }
  throw new HttpError(405, `Метод ${method} не поддерживается для /api/${parts.join('/')}`);
}

function send(res, origin, status, payload) {
  const headers = { 'Content-Type': 'application/json; charset=utf-8' };
  if (origin === ORIGIN) {
    headers['Access-Control-Allow-Origin'] = ORIGIN;
    headers['Vary'] = 'Origin';
  }
  res.writeHead(status, headers);
  res.end(payload === null ? '' : JSON.stringify(payload));
}

const server = http.createServer((req, res) => {
  const origin = req.headers.origin;
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const started = Date.now();

  // Предварительный запрос CORS (OPTIONS) перед POST/PUT/DELETE с JSON.
  if (req.method === 'OPTIONS') {
    if (origin === ORIGIN) {
      res.writeHead(204, {
        'Access-Control-Allow-Origin': ORIGIN,
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '600',
      });
    } else {
      console.warn(`CORS: отклонён источник ${origin} (разрешён ${ORIGIN})`);
      res.writeHead(403);
    }
    return res.end();
  }
  if (origin && origin !== ORIGIN) {
    console.warn(`CORS: запрос с источника ${origin} — заголовок Access-Control-Allow-Origin не выдан`);
  }

  let raw = '';
  req.on('data', (chunk) => (raw += chunk));
  req.on('end', () => {
    const delay = Math.min(10000, int(url.searchParams.get('__delay')) ?? 0);
    setTimeout(() => {
      let status;
      let payload;
      try {
        const forced = int(url.searchParams.get('__fail'));
        if (forced) throw new HttpError(forced, `Сымитированная ошибка сервера (${forced})`);
        if (!url.pathname.startsWith('/api/')) throw new HttpError(404, 'Адрес должен начинаться с /api/');
        let body = null;
        if (raw) {
          try {
            body = JSON.parse(raw);
          } catch {
            throw new HttpError(400, 'Тело запроса — не JSON');
          }
        }
        const parts = url.pathname.slice('/api/'.length).split('/').filter(Boolean);
        [status, payload] = route(req.method, parts, url.searchParams, body);
      } catch (e) {
        status = e instanceof HttpError ? e.status : 500;
        payload = { message: e.message, ...(e.errors ? { errors: e.errors } : {}) };
        if (!(e instanceof HttpError)) console.error(e);
      }
      send(res, origin, status, payload);
      console.log(`${req.method} ${url.pathname}${url.search} → ${status} (${Date.now() - started} мс)`);
    }, delay);
  });
});

server.listen(PORT, () => {
  console.log(`Сервер клуба настольных игр: http://localhost:${PORT}/api`);
  console.log(`Проверка: http://localhost:${PORT}/api/__health`);
  console.log(`CORS разрешён для: ${ORIGIN}`);
});
