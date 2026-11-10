// Testes da API contra MariaDB e Redis reais.
// Variáveis: DB_HOST/DB_USER/DB_PASSWORD ou DB_SOCKET; REDIS_URL. Banco usado: spc_api_test (recriado).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import mysql, { type Pool, type RowDataPacket } from 'mysql2/promise';
import { createClient } from 'redis';
import { buildApp } from '../src/app.js';
import { buildEnvelope } from '../src/bridge.js';

const require = createRequire(import.meta.url);
const root = join(import.meta.dirname, '..', '..', '..');
// Verificador do lado do jogo (spc_bridge) — garante compatibilidade API ↔ jogo
const { verify, ReplayCache } = require(join(root, 'game/resources/[spc-core]/spc_bridge/protocol.js'));

const TOKEN = 't'.repeat(40);
const SECRET = 'segredo-da-ponte-de-testes';
const DB = 'spc_api_test';
const conn = process.env.DB_HOST
  ? { host: process.env.DB_HOST, port: Number(process.env.DB_PORT || 3306), user: process.env.DB_USER || 'root', password: process.env.DB_PASSWORD }
  : { socketPath: process.env.DB_SOCKET || '/run/mysqld/mysqld.sock', user: process.env.DB_USER || 'root' };

let db: Pool;
let app: ReturnType<typeof buildApp>;
const redis = createClient({ url: process.env.REDIS_URL || 'redis://127.0.0.1:6399' });
const sub = redis.duplicate();
const commands: string[] = [];

const STAFF = '100000000000000001';
const PLAYER = '200000000000000002';
const PLAYER2 = '200000000000000003';
const auth = { authorization: `Bearer ${TOKEN}` };

beforeAll(async () => {
  const admin = await mysql.createConnection({ ...conn, multipleStatements: true });
  await admin.query(`DROP DATABASE IF EXISTS ${DB}; CREATE DATABASE ${DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  await admin.query(`USE ${DB}`);
  const dir = join(root, 'packages/db/migrations');
  for (const f of readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()) await admin.query(readFileSync(join(dir, f), 'utf8'));
  await admin.query(`INSERT INTO accounts (discord_id, whitelist_status) VALUES ('${STAFF}', 'approved'), ('300000000000000004', 'approved')`);
  await admin.query(`INSERT INTO staff (account_id, role) SELECT id, 'helper' FROM accounts WHERE discord_id = '${STAFF}'`);
  await admin.end();

  db = mysql.createPool({ ...conn, database: DB, timezone: 'Z' });
  await redis.connect();
  await sub.connect();
  await sub.subscribe('spc:cmd', (m) => commands.push(m));
  await redis.del('spc:online');
  app = buildApp({ db, redis, apiToken: TOKEN, bridgeSecret: SECRET });
});

afterAll(async () => {
  await app.close();
  await db.end();
  await sub.quit();
  await redis.quit();
});

const call = (method: 'GET' | 'POST', url: string, payload?: unknown, headers: Record<string, string> = auth) =>
  app.inject({ method, url, payload: payload as any, headers });

const answers = { idade: '22', experiencia: '2 anos', personagem: 'Zé, mecânico da Zona Leste', amorAVida: 'temer a morte', metagaming: 'usar info de fora' };

describe('autenticação', () => {
  it('health é público; o resto exige token', async () => {
    expect((await call('GET', '/health', undefined, {})).statusCode).toBe(200);
    expect((await call('GET', '/v1/server/status', undefined, {})).statusCode).toBe(401);
    expect((await call('GET', '/v1/server/status', undefined, { authorization: 'Bearer errado' })).statusCode).toBe(401);
  });
});

describe('whitelist', () => {
  let appId = 0;

  it('valida entrada', async () => {
    expect((await call('POST', '/v1/whitelist/applications', { discordId: 'abc', answers })).json().error).toBe('invalid_body');
    expect((await call('POST', '/v1/whitelist/applications', { discordId: PLAYER, answers: {} })).statusCode).toBe(400);
  });

  it('cria candidatura e recusa duplicada', async () => {
    const r = await call('POST', '/v1/whitelist/applications', { discordId: PLAYER, answers });
    expect(r.statusCode).toBe(201);
    appId = r.json().id;
    const dup = await call('POST', '/v1/whitelist/applications', { discordId: PLAYER, answers });
    expect(dup.statusCode).toBe(409);
    expect(dup.json().error).toBe('already_pending');
  });

  it('conta já aprovada não pode pedir de novo', async () => {
    expect((await call('POST', '/v1/whitelist/applications', { discordId: STAFF, answers })).json().error).toBe('already_approved');
  });

  it('listar exige staff com whitelist.review', async () => {
    expect((await call('GET', `/v1/whitelist/applications?staffDiscordId=300000000000000004`)).statusCode).toBe(403);
    const r = await call('GET', `/v1/whitelist/applications?staffDiscordId=${STAFF}`);
    expect(r.statusCode).toBe(200);
    expect(r.json().applications[0]).toMatchObject({ id: appId, discordId: PLAYER, answers: { idade: '22' } });
  });

  it('entrevista e aprovação criam a conta e publicam account.refresh assinado e aceito pela ponte', async () => {
    expect((await call('POST', `/v1/whitelist/applications/${appId}/interview`, { staffDiscordId: STAFF })).statusCode).toBe(200);
    commands.length = 0;
    const r = await call('POST', `/v1/whitelist/applications/${appId}/approve`, { staffDiscordId: STAFF });
    expect(r.statusCode).toBe(200);
    const [rows] = await db.query<RowDataPacket[]>('SELECT whitelist_status FROM accounts WHERE discord_id = ?', [PLAYER]);
    expect(rows[0]?.whitelist_status).toBe('approved');

    await new Promise((res) => setTimeout(res, 200));
    expect(commands).toHaveLength(1);
    const v = verify(commands[0], SECRET, Date.now(), new ReplayCache());
    expect(v.ok).toBe(true);
    expect(v.cmd).toMatchObject({ type: 'account.refresh', payload: { discordId: PLAYER }, id: r.json().commandId });

    const [audit] = await db.query<RowDataPacket[]>("SELECT COUNT(*) AS n FROM audit_log WHERE action LIKE 'whitelist.%'");
    expect(Number(audit[0]?.n)).toBe(2);
  });

  it('não aprova duas vezes', async () => {
    const r = await call('POST', `/v1/whitelist/applications/${appId}/approve`, { staffDiscordId: STAFF });
    expect(r.json()).toMatchObject({ error: 'invalid_state', status: 'approved' });
  });

  it('reprovação exige motivo e impõe prazo de 7 dias', async () => {
    const id = (await call('POST', '/v1/whitelist/applications', { discordId: PLAYER2, answers })).json().id;
    expect((await call('POST', `/v1/whitelist/applications/${id}/reject`, { staffDiscordId: STAFF, reason: 'x' })).statusCode).toBe(400);
    const r = await call('POST', `/v1/whitelist/applications/${id}/reject`, { staffDiscordId: STAFF, reason: 'Respostas copiadas da internet' });
    expect(r.statusCode).toBe(200);
    const again = await call('POST', '/v1/whitelist/applications', { discordId: PLAYER2, answers });
    expect(again.json().error).toBe('retry_later');
    expect(again.json().retryAfter).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  it('id inexistente → 404; staff sem permissão → 403', async () => {
    expect((await call('POST', '/v1/whitelist/applications/99999/approve', { staffDiscordId: STAFF })).statusCode).toBe(404);
    expect((await call('POST', '/v1/whitelist/applications/1/approve', { staffDiscordId: '300000000000000004' })).statusCode).toBe(403);
  });
});

describe('status e protocolo', () => {
  it('status conta jogadores do conjunto spc:online', async () => {
    await redis.sAdd('spc:online', ['1', '2', '3']);
    expect((await call('GET', '/v1/server/status')).json()).toEqual({ online: 3 });
  });

  it('envelope adulterado é recusado pela ponte', () => {
    const { envelope } = buildEnvelope(SECRET, 'player.kick', { citizenid: 'SPC1' }, 'staff:1');
    const e = JSON.parse(envelope);
    e.body = e.body.replace('SPC1', 'SPC2');
    expect(verify(JSON.stringify(e), SECRET, Date.now(), new ReplayCache()).error).toBe('invalid_signature');
  });
});
