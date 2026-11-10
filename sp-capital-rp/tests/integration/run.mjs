// Teste de integração: executa o Lua real do spc_core (Lua 5.4 via wasmoon) contra um MariaDB real.
// Variáveis: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_SOCKET (opcional). Banco usado: spc_it (recriado).
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import mysql from 'mysql2/promise';
import { LuaFactory } from 'wasmoon';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const core = join(root, 'game', 'resources', '[spc-core]', 'spc_core');
const DB_NAME = 'spc_it';

const base = process.env.DB_SOCKET || !process.env.DB_HOST
  ? { socketPath: process.env.DB_SOCKET || '/run/mysqld/mysqld.sock' }
  : { host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 3306) };
const cfg = { ...base, user: process.env.DB_USER || 'root', password: process.env.DB_PASSWORD || undefined,
  multipleStatements: true, dateStrings: true, supportBigNumbers: true, bigNumberStrings: false };

const admin = await mysql.createConnection(cfg);
await admin.query(`DROP DATABASE IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
await admin.end();

const conn = await mysql.createConnection({ ...cfg, database: DB_NAME });
const migrations = join(root, 'packages', 'db', 'migrations');
for (const f of readdirSync(migrations).filter((f) => f.endsWith('.sql')).sort()) {
  await conn.query(readFileSync(join(migrations, f), 'utf8'));
}

// Lua → JS: tabelas viram objetos; arrays podem chegar como objeto {1:..,2:..} — normalizar
const toParams = (p) => (p == null ? [] : Array.isArray(p) ? p : Object.keys(p).sort((a, b) => a - b).map((k) => p[k]));
const isWrite = (sql) => /^\s*(insert|update|delete|replace)/i.test(sql);
const plain = (rows) => rows.map((r) => ({ ...r }));

async function jsdb(op, sql, params) {
  if (op === 'begin') { await conn.beginTransaction(); return true; }
  if (op === 'commit') { await conn.commit(); return true; }
  if (op === 'rollback') { await conn.rollback(); return true; }
  const [res] = await conn.query(sql, toParams(params));
  const header = isWrite(sql) ? { affectedRows: res.affectedRows, insertId: res.insertId } : null;
  switch (op) {
    case 'query': return header ?? plain(res);
    case 'single': return res[0] ? { ...res[0] } : null;
    case 'scalar': return res[0] ? Object.values(res[0])[0] : null;
    case 'insert': return res.insertId;
    case 'update': return res.affectedRows;
    default: throw new Error(`op desconhecida ${op}`);
  }
}

const lua = await new LuaFactory().createEngine();
// O wasmoon falha ao converter `null` para Lua: removemos nulls (equivalem a nil em Lua, como no oxmysql).
const clean = (v) => {
  if (v === null || v === undefined) return undefined;
  if (Array.isArray(v)) return v.map(clean);
  if (typeof v === 'object') {
    const o = {};
    for (const [k, x] of Object.entries(v)) if (x !== null && x !== undefined) o[k] = clean(x);
    return o;
  }
  return v;
};
lua.global.set('jsdb', async (op, sql, params) => {
  const v = clean(await jsdb(op, sql, params));
  return v === undefined ? {} : { v };
});
lua.global.set('jsonEncode', (v) => JSON.stringify(v ?? null));
lua.global.set('jsonDecode', (s) => clean(JSON.parse(s)) ?? {});

const files = [
  join(here, 'fivem_fake.lua'),
  ...['config', 'util', 'identity', 'permissions_core', 'ledger_core'].map((f) => join(core, 'shared', `${f}.lua`)),
  ...['db', 'log', 'players', 'permissions', 'ledger', 'connection', 'characters', 'persistence', 'commands', 'exports']
    .map((f) => join(core, 'server', `${f}.lua`)),
];
for (const f of files) await lua.doString(readFileSync(f, 'utf8'));

const results = await lua.doString(readFileSync(join(here, 'test_server.lua'), 'utf8'));
for (const f of Object.values(results.failures ?? {})) console.log(`FALHOU  ${f}`);
console.log(`${results.passed} passaram, ${results.failed} falharam`);
await conn.end();
lua.global.close();
process.exit(results.failed === 0 ? 0 : 1);
