// Хранение данных сервера в PostgreSQL (Render), если задан DATABASE_URL.
// Без него (локально) данные живут только в памяти, как раньше.
//
// Всё состояние сервера — один JSON-документ в таблице club_state:
// для учебного объёма этого достаточно, а схема не мешает менять модели.

let pool = null;

async function connect() {
  const url = process.env.DATABASE_URL;
  if (!url) return false;
  const { Pool } = require('pg');
  pool = new Pool({ connectionString: url, ssl: { rejectUnauthorized: false } });
  await pool.query(`CREATE TABLE IF NOT EXISTS club_state (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`);
  return true;
}

/** Сохранённое состояние или null, если база пустая. */
async function load() {
  if (!pool) return null;
  const { rows } = await pool.query("SELECT data FROM club_state WHERE id = 'main'");
  return rows[0]?.data ?? null;
}

let timer = null;
let latest = null;

/** Сохранение с задержкой: несколько изменений подряд — одна запись в базу. */
function save(db) {
  if (!pool) return;
  latest = db;
  clearTimeout(timer);
  timer = setTimeout(async () => {
    try {
      await pool.query(
        `INSERT INTO club_state (id, data, updated_at) VALUES ('main', $1, now())
         ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = now()`,
        [JSON.stringify(latest)],
      );
    } catch (e) {
      console.error('Не удалось сохранить в базу:', e.message);
    }
  }, 300);
}

module.exports = { connect, load, save };
