// spc_bridge — único ponto de contato do jogo com o Redis.
// Spec: docs/sp-capital-rp/specs/logs-e-bridge.md §2
const { createClient } = require('redis');
const { verify, ReplayCache } = require('./protocol');

const REDIS_URL = GetConvar('spc_redis_url', 'redis://127.0.0.1:6379');
const SECRET = GetConvar('spc_bridge_secret', '');
const ACK_TIMEOUT_MS = 10000;
const MAX_PENDING_LOG_BATCHES = 50;

const replay = new ReplayCache();
const pendingAcks = new Map(); // id → timer
const pendingLogs = [];
let pub = null;
let connected = false;

if (!SECRET) console.log('^1[spc_bridge] spc_bridge_secret não definido: comandos externos serão recusados^0');

function log(level, action, data) {
  if (GetResourceState('spc_logs') === 'started') exports.spc_logs.Log('bridge', action, data, level);
}

async function publish(channel, obj) {
  if (!connected) return false;
  try { await pub.publish(channel, JSON.stringify(obj)); return true; } catch { return false; }
}

async function writeLogs(batchJson) {
  try {
    await pub.xAdd('spc:logs', '*', { batch: batchJson }, { TRIM: { strategy: 'MAXLEN', strategyModifier: '~', threshold: 1000000 } });
    return true;
  } catch { return false; }
}

async function drainLogs() {
  while (connected && pendingLogs.length > 0) {
    if (!(await writeLogs(pendingLogs[0]))) return;
    pendingLogs.shift();
  }
}

// Logs vindos do spc_logs (evento LOCAL do servidor — `on`, nunca `onNet`)
on('spc_bridge:logs', (batchJson) => {
  if (typeof batchJson !== 'string') return;
  pendingLogs.push(batchJson);
  if (pendingLogs.length > MAX_PENDING_LOG_BATCHES) pendingLogs.shift();
  drainLogs();
});

function handleCommand(raw) {
  const res = verify(raw, SECRET, Date.now(), replay);
  if (!res.ok) {
    log('alert', 'command_rejected', { error: res.error });
    return;
  }
  const { id, type, actor, payload } = res.cmd;
  pendingAcks.set(id, setTimeout(() => {
    pendingAcks.delete(id);
    publish(`spc:ack:${id}`, { id, ok: false, error: 'timeout' });
  }, ACK_TIMEOUT_MS));
  log('info', 'command', { id, type, actor });
  emit(`spc:cmd:${type}`, id, payload, actor);
}

exports('Ack', (id, ok, result) => {
  const t = pendingAcks.get(id);
  if (!t) return;
  clearTimeout(t);
  pendingAcks.delete(id);
  publish(`spc:ack:${id}`, { id, ok: ok === true, result: result ?? null });
});

const publishEvent = (type, payload) => publish('spc:evt', { type, payload: payload ?? {}, ts: Date.now() });
exports('Publish', publishEvent);
exports('IsConnected', () => connected);

async function start() {
  pub = createClient({ url: REDIS_URL, socket: { reconnectStrategy: (n) => Math.min(1000 * 2 ** n, 30000) } });
  const sub = pub.duplicate();
  for (const c of [pub, sub]) c.on('error', (e) => console.log(`^3[spc_bridge] redis: ${e.message}^0`));
  pub.on('ready', () => { connected = true; console.log('[spc_bridge] conectado ao Redis'); drainLogs(); });
  pub.on('end', () => { connected = false; });
  pub.on('reconnecting', () => { connected = false; });
  await Promise.all([pub.connect(), sub.connect()]);
  await sub.subscribe('spc:cmd', handleCommand);
}

setInterval(() => replay.prune(Date.now()), 60000);
start().catch((e) => console.log(`^1[spc_bridge] falha ao iniciar: ${e.message}^0`));

// Eventos do jogo publicados para API/bot
on('spc_core:server:playerJoined', (src, accountId) => publishEvent('player.joined', { src, accountId }));
on('spc_core:server:playerDropped', (src, citizenid) => publishEvent('player.dropped', { src, citizenid }));
