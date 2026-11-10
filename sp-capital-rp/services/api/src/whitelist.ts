// Regras de whitelist. Spec: docs/sp-capital-rp/specs/api-e-bot-whitelist.md · fila-whitelist.md
import type { Pool, PoolConnection, RowDataPacket, ResultSetHeader } from 'mysql2/promise';
import { roleHas } from './permissions.js';

export class HttpError extends Error {
  constructor(public status: number, public code: string, public extra: Record<string, unknown> = {}) { super(code); }
}

export const RETRY_DAYS = 7;

type Row = RowDataPacket & Record<string, any>;

export interface Staff { accountId: number; role: string }

/** Confere se o Discord pertence a staff ativa com a permissão exigida. */
export async function requireStaff(db: Pool, discordId: string, permission: string): Promise<Staff> {
  const [rows] = await db.query<Row[]>(
    `SELECT a.id, s.role FROM accounts a JOIN staff s ON s.account_id = a.id
     WHERE a.discord_id = ? AND s.active = 1`, [discordId]);
  const r = rows[0];
  if (!r || !roleHas(r.role, permission)) throw new HttpError(403, 'forbidden');
  return { accountId: Number(r.id), role: r.role };
}

async function audit(conn: Pool | PoolConnection, staff: Staff, action: string, target: string, after: unknown) {
  await conn.query('INSERT INTO audit_log (staff_account_id, action, target, after_data) VALUES (?, ?, ?, ?)',
    [staff.accountId, action, target, JSON.stringify(after)]);
}

export async function createApplication(db: Pool, discordId: string, answers: Record<string, string>) {
  const [acc] = await db.query<Row[]>('SELECT whitelist_status FROM accounts WHERE discord_id = ?', [discordId]);
  if (acc[0]?.whitelist_status === 'approved') throw new HttpError(409, 'already_approved');
  if (acc[0]?.whitelist_status === 'suspended') throw new HttpError(409, 'suspended');

  const [open] = await db.query<Row[]>(
    "SELECT id FROM whitelist_applications WHERE discord_id = ? AND status IN ('pending','interview') LIMIT 1", [discordId]);
  if (open[0]) throw new HttpError(409, 'already_pending', { applicationId: Number(open[0].id) });

  const [wait] = await db.query<Row[]>(
    `SELECT DATE_FORMAT(retry_after, '%Y-%m-%dT%H:%i:%sZ') AS retry_after FROM whitelist_applications
     WHERE discord_id = ? AND status = 'rejected' AND retry_after > NOW() ORDER BY retry_after DESC LIMIT 1`, [discordId]);
  if (wait[0]) throw new HttpError(409, 'retry_later', { retryAfter: wait[0].retry_after });

  const [res] = await db.query<ResultSetHeader>(
    'INSERT INTO whitelist_applications (discord_id, answers) VALUES (?, ?)', [discordId, JSON.stringify(answers)]);
  return { id: res.insertId };
}

export async function listApplications(db: Pool, status: string, limit = 25) {
  const [rows] = await db.query<Row[]>(
    `SELECT id, discord_id, answers, status, DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%sZ') AS created_at
     FROM whitelist_applications WHERE status = ? ORDER BY created_at, id LIMIT ?`, [status, limit]);
  return rows.map((r) => ({
    id: Number(r.id), discordId: r.discord_id, status: r.status, createdAt: r.created_at,
    answers: typeof r.answers === 'string' ? JSON.parse(r.answers) : r.answers,
  }));
}

/** Executa `fn` com a candidatura bloqueada (FOR UPDATE) e exige um dos estados permitidos. */
async function withApplication<T>(db: Pool, id: number, allowed: string[],
  fn: (conn: PoolConnection, app: Row) => Promise<T>): Promise<T> {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [rows] = await conn.query<Row[]>('SELECT * FROM whitelist_applications WHERE id = ? FOR UPDATE', [id]);
    const app = rows[0];
    if (!app) throw new HttpError(404, 'not_found');
    if (!allowed.includes(app.status)) throw new HttpError(409, 'invalid_state', { status: app.status });
    const result = await fn(conn, app);
    await conn.commit();
    return result;
  } catch (e) {
    await conn.rollback().catch(() => {});
    throw e;
  } finally {
    conn.release();
  }
}

export function markInterview(db: Pool, staff: Staff, id: number) {
  return withApplication(db, id, ['pending'], async (conn, app) => {
    await conn.query("UPDATE whitelist_applications SET status = 'interview', reviewer_account_id = ? WHERE id = ?", [staff.accountId, id]);
    await audit(conn, staff, 'whitelist.interview', `application:${id}`, { discordId: app.discord_id });
    return { discordId: app.discord_id as string };
  });
}

export function approve(db: Pool, staff: Staff, id: number) {
  return withApplication(db, id, ['pending', 'interview'], async (conn, app) => {
    await conn.query(
      `INSERT INTO accounts (discord_id, whitelist_status) VALUES (?, 'approved')
       ON DUPLICATE KEY UPDATE whitelist_status = 'approved'`, [app.discord_id]);
    await conn.query("UPDATE whitelist_applications SET status = 'approved', reviewer_account_id = ? WHERE id = ?", [staff.accountId, id]);
    await audit(conn, staff, 'whitelist.approve', `application:${id}`, { discordId: app.discord_id });
    return { discordId: app.discord_id as string };
  });
}

export function reject(db: Pool, staff: Staff, id: number, reason: string) {
  return withApplication(db, id, ['pending', 'interview'], async (conn, app) => {
    await conn.query(
      `UPDATE whitelist_applications SET status = 'rejected', reviewer_account_id = ?, retry_after = NOW() + INTERVAL ? DAY
       WHERE id = ?`, [staff.accountId, RETRY_DAYS, id]);
    await audit(conn, staff, 'whitelist.reject', `application:${id}`, { discordId: app.discord_id, reason });
    return { discordId: app.discord_id as string };
  });
}
