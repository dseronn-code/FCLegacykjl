// Protocolo de comandos assinados (puro, testável fora do FXServer).
// Envelope recebido em spc:cmd: { "body": "<JSON do comando>", "sig": "<hex HMAC-SHA256(segredo, body)>" }
// Comando: { id, type, actor, ts, payload }
const crypto = require('crypto');

const TYPE_RE = /^[a-z]+\.[a-z_]+$/;
const MAX_SKEW_MS = 30000;

function sign(secret, body) {
  return crypto.createHmac('sha256', secret).update(body).digest('hex');
}

function safeEqualHex(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length || !/^[0-9a-f]+$/.test(a)) return false;
  return crypto.timingSafeEqual(Buffer.from(a, 'hex'), Buffer.from(b, 'hex'));
}

/** Cache de ids vistos para impedir replay. */
class ReplayCache {
  constructor(ttlMs = 10 * 60 * 1000) { this.ttl = ttlMs; this.seen = new Map(); }
  has(id, now) { const exp = this.seen.get(id); return exp !== undefined && exp > now; }
  add(id, now) { this.seen.set(id, now + this.ttl); }
  prune(now) { for (const [id, exp] of this.seen) if (exp <= now) this.seen.delete(id); }
}

/** Valida o envelope. Retorna { ok: true, cmd } ou { ok: false, error }. */
function verify(raw, secret, now, replay) {
  if (!secret) return { ok: false, error: 'no_secret' };
  let env;
  try { env = JSON.parse(raw); } catch { return { ok: false, error: 'invalid_json' }; }
  if (!env || typeof env.body !== 'string' || !safeEqualHex(env.sig, sign(secret, env.body))) {
    return { ok: false, error: 'invalid_signature' };
  }
  let cmd;
  try { cmd = JSON.parse(env.body); } catch { return { ok: false, error: 'invalid_json' }; }
  if (!cmd || typeof cmd.id !== 'string' || cmd.id.length > 64) return { ok: false, error: 'invalid_id' };
  if (typeof cmd.type !== 'string' || !TYPE_RE.test(cmd.type)) return { ok: false, error: 'invalid_type' };
  if (typeof cmd.actor !== 'string') return { ok: false, error: 'invalid_actor' };
  if (typeof cmd.ts !== 'number' || Math.abs(now - cmd.ts) > MAX_SKEW_MS) return { ok: false, error: 'expired' };
  if (replay.has(cmd.id, now)) return { ok: false, error: 'replay' };
  replay.add(cmd.id, now);
  return { ok: true, cmd: { id: cmd.id, type: cmd.type, actor: cmd.actor, payload: cmd.payload ?? {} } };
}

module.exports = { sign, verify, ReplayCache };
