// Аутентификация и роли учебного сервера (ПР5).
//
// Токены — подписанные HMAC строки вида «данные.подпись». Роль берётся
// из подписанного токена, а не из того, что прислал клиент: подделать её
// в браузере нельзя — подпись не сойдётся.

const crypto = require('crypto');

const SECRET = crypto.randomBytes(32);

/** Роли и их уровни. Набор функций у каждой роли свой — см. can(). */
const ROLES = {
  member: 'участник клуба',
  staff: 'сотрудник клуба',
  admin: 'администратор',
};

/**
 * Права по операциям — то же, что lib/models/permissions.dart на клиенте.
 * На клиенте это удобство интерфейса, здесь — настоящая защита.
 */
const PERMISSIONS = {
  viewCatalog: ['member', 'staff', 'admin'],
  viewOwnLoans: ['member'],
  extendLoan: ['member'],
  editCatalog: ['staff'],
  softDelete: ['staff'],
  viewMembers: ['staff', 'admin'],
  manageMembers: ['staff'],
  issueLoans: ['staff'],
  hardDelete: ['admin'],
  restore: ['admin'],
  manageUsers: ['admin'],
  viewStats: ['admin'],
};

const can = (role, operation) => (PERMISSIONS[operation] ?? []).includes(role);

function sign(payload, ttlSeconds) {
  const body = Buffer.from(
    JSON.stringify({ ...payload, exp: Math.floor(Date.now() / 1000) + ttlSeconds }),
  ).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  return `${body}.${sig}`;
}

/** Проверяет подпись и срок. Возвращает данные токена или null. */
function verify(token, type) {
  if (typeof token !== 'string') return null;
  const [body, sig] = token.split('.');
  if (!body || !sig) return null;
  const expected = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  if (sig.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) {
    return null;
  }
  try {
    const data = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (data.type !== type || data.exp < Date.now() / 1000) return null;
    return data;
  } catch {
    return null;
  }
}

/** Пароль хешируется на сервере (scrypt с солью); клиент передаёт его как есть. */
function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  return `${salt}:${crypto.scryptSync(password, salt, 32).toString('hex')}`;
}

function checkPassword(password, stored) {
  const [salt, hash] = stored.split(':');
  const actual = crypto.scryptSync(String(password), salt, 32);
  return crypto.timingSafeEqual(actual, Buffer.from(hash, 'hex'));
}

/** Требования к паролю — те же, что проверяет форма регистрации. */
function passwordProblem(password) {
  if (typeof password !== 'string' || password.length < 8) return 'Пароль: не короче 8 символов';
  if (!/\d/.test(password)) return 'Пароль: нужна хотя бы одна цифра';
  if (!/[^A-Za-zА-Яа-яЁё0-9]/.test(password)) return 'Пароль: нужен хотя бы один специальный символ';
  return null;
}

const seedUsers = () => [
  { id: 1, username: 'admin', name: 'Анна Администратор', role: 'admin', password: hashPassword('Admin123!') },
  { id: 2, username: 'staff', name: 'Сергей Сотрудник', role: 'staff', password: hashPassword('Staff123!') },
  { id: 3, username: 'reader', name: 'Алексей Иванов', role: 'member', password: hashPassword('Reader123!') },
  { id: 4, username: 'maria', name: 'Мария Смирнова', role: 'member', password: hashPassword('Maria123!') },
];

const day = 24 * 3600 * 1000;
const seedLoans = () => {
  const now = Date.now();
  return [
    { id: 1, gameId: 6, userId: 3, issuedAt: new Date(now - 10 * day).toISOString(), dueDate: new Date(now + 4 * day).toISOString(), returnedAt: null, extensions: 0 },
    { id: 2, gameId: 8, userId: 3, issuedAt: new Date(now - 20 * day).toISOString(), dueDate: new Date(now - 6 * day).toISOString(), returnedAt: null, extensions: 1 },
    { id: 3, gameId: 6, userId: 4, issuedAt: new Date(now - 3 * day).toISOString(), dueDate: new Date(now + 11 * day).toISOString(), returnedAt: null, extensions: 0 },
    { id: 4, gameId: 1, userId: 4, issuedAt: new Date(now - 40 * day).toISOString(), dueDate: new Date(now - 26 * day).toISOString(), returnedAt: new Date(now - 28 * day).toISOString(), extensions: 0 },
  ];
};

const publicUser = (u) => ({ id: u.id, username: u.username, name: u.name, role: u.role });

module.exports = { ROLES, PERMISSIONS, can, sign, verify, hashPassword, checkPassword, passwordProblem, seedUsers, seedLoans, publicUser };
