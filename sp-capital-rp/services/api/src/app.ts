// API mínima. Spec: docs/sp-capital-rp/specs/api-e-bot-whitelist.md
import Fastify, { type FastifyInstance } from 'fastify';
import { timingSafeEqual } from 'node:crypto';
import type { Pool } from 'mysql2/promise';
import { z, ZodError } from 'zod';
import { sendCommand, type Publisher } from './bridge.js';
import * as wl from './whitelist.js';

export interface Deps {
  db: Pool;
  redis: Publisher & { sCard(key: string): Promise<number> };
  apiToken: string;
  bridgeSecret: string;
}

const DiscordId = z.string().regex(/^\d{17,20}$/, 'discordId inválido');
const Id = z.coerce.number().int().positive();
const Answers = z.record(z.string().max(64), z.string().max(1500)).refine(
  (a) => Object.keys(a).length > 0 && Object.keys(a).length <= 10 && JSON.stringify(a).length <= 8192,
  'answers: 1 a 10 respostas, até 8 KB');

function sameToken(given: string | undefined, expected: string) {
  if (!given?.startsWith('Bearer ')) return false;
  const a = Buffer.from(given.slice(7));
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

export function buildApp(deps: Deps): FastifyInstance {
  const app = Fastify({ logger: false, bodyLimit: 16 * 1024 });

  app.setErrorHandler((err, _req, reply) => {
    if (err instanceof wl.HttpError) return reply.code(err.status).send({ error: err.code, ...err.extra });
    if (err instanceof ZodError) return reply.code(400).send({ error: 'invalid_body', issues: err.issues.map((i) => i.message) });
    if ((err as { statusCode?: number }).statusCode === 400) return reply.code(400).send({ error: 'invalid_body' });
    app.log.error(err);
    return reply.code(500).send({ error: 'internal_error' });
  });

  app.get('/health', async () => ({ ok: true }));

  app.addHook('onRequest', async (req, reply) => {
    if (req.url === '/health') return;
    if (!sameToken(req.headers.authorization, deps.apiToken)) return reply.code(401).send({ error: 'unauthorized' });
  });

  const staffOf = (body: unknown, perm: string) => wl.requireStaff(deps.db, DiscordId.parse((body as any)?.staffDiscordId), perm);
  const refresh = (discordId: string, actor: string) =>
    sendCommand(deps.redis, deps.bridgeSecret, 'account.refresh', { discordId }, actor);

  app.post('/v1/whitelist/applications', async (req, reply) => {
    const body = z.object({ discordId: DiscordId, answers: Answers }).parse(req.body);
    const created = await wl.createApplication(deps.db, body.discordId, body.answers);
    return reply.code(201).send(created);
  });

  app.get('/v1/whitelist/applications', async (req) => {
    const q = z.object({
      status: z.enum(['pending', 'interview', 'approved', 'rejected']).default('pending'),
      staffDiscordId: DiscordId,
    }).parse(req.query);
    await wl.requireStaff(deps.db, q.staffDiscordId, 'whitelist.review');
    return { applications: await wl.listApplications(deps.db, q.status) };
  });

  app.post('/v1/whitelist/applications/:id/interview', async (req) => {
    const staff = await staffOf(req.body, 'whitelist.review');
    return wl.markInterview(deps.db, staff, Id.parse((req.params as any).id));
  });

  app.post('/v1/whitelist/applications/:id/approve', async (req) => {
    const staff = await staffOf(req.body, 'whitelist.review');
    const res = await wl.approve(deps.db, staff, Id.parse((req.params as any).id));
    const commandId = await refresh(res.discordId, `staff:${staff.accountId}`);
    return { ...res, commandId };
  });

  app.post('/v1/whitelist/applications/:id/reject', async (req) => {
    const staff = await staffOf(req.body, 'whitelist.review');
    const reason = z.string().trim().min(5).max(500).parse((req.body as any)?.reason);
    const res = await wl.reject(deps.db, staff, Id.parse((req.params as any).id), reason);
    return { ...res, retryDays: wl.RETRY_DAYS };
  });

  app.get('/v1/server/status', async () => ({ online: await deps.redis.sCard('spc:online') }));

  return app;
}
