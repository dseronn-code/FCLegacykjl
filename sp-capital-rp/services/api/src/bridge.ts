// Publica comandos assinados para o jogo (protocolo: docs/sp-capital-rp/specs/logs-e-bridge.md).
import { createHmac, randomUUID } from 'node:crypto';

export interface Publisher {
  publish(channel: string, message: string): Promise<unknown>;
}

export function buildEnvelope(secret: string, type: string, payload: unknown, actor: string, now = Date.now(), id = randomUUID()) {
  const body = JSON.stringify({ id, type, actor, ts: now, payload });
  const sig = createHmac('sha256', secret).update(body).digest('hex');
  return { id, envelope: JSON.stringify({ body, sig }) };
}

export async function sendCommand(pub: Publisher, secret: string, type: string, payload: unknown, actor: string) {
  const { id, envelope } = buildEnvelope(secret, type, payload, actor);
  await pub.publish('spc:cmd', envelope);
  return id;
}
