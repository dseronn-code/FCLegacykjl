import mysql from 'mysql2/promise';
import { createClient } from 'redis';
import { buildApp } from './app.js';
import { loadConfig } from './config.js';

const cfg = loadConfig();
const db = mysql.createPool({
  ...(cfg.DB_SOCKET ? { socketPath: cfg.DB_SOCKET } : { host: cfg.DB_HOST, port: cfg.DB_PORT }),
  user: cfg.DB_USER, password: cfg.DB_PASSWORD, database: cfg.DB_NAME,
  connectionLimit: 10, timezone: 'Z', supportBigNumbers: true,
});
const redis = createClient({ url: cfg.REDIS_URL });
redis.on('error', (e) => console.error('[api] redis:', e.message));
await redis.connect();

const app = buildApp({ db, redis, apiToken: cfg.SPC_API_TOKEN, bridgeSecret: cfg.SPC_BRIDGE_SECRET });
await app.listen({ port: cfg.PORT, host: '0.0.0.0' });
console.log(`[api] ouvindo na porta ${cfg.PORT}`);
