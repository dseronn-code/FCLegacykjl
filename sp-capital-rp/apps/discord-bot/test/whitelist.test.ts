import { describe, expect, it } from 'vitest';
import { SpcApi } from '../src/api.js';
import * as wl from '../src/whitelist.js';

describe('customId', () => {
  it('codifica e decodifica', () => {
    const id = wl.encodeId('approve', 42, '123456789012345678');
    expect(id.length).toBeLessThanOrEqual(100); // limite do Discord
    expect(wl.decodeId(id)).toEqual({ action: 'approve', appId: 42, discordId: '123456789012345678' });
  });
  it('recusa ids estranhos', () => {
    expect(wl.decodeId('wl:delete:1:123456789012345678')).toBeNull();
    expect(wl.decodeId('wl:approve:x:123')).toBeNull();
  });
});

describe('regras', () => {
  it('idade da conta pelo snowflake', () => {
    // 175928847299117063 = 2016-04-30T11:18:25.796Z (exemplo da documentação do Discord; mês 3 = abril)
    expect(wl.accountAgeDays('175928847299117063', Date.UTC(2016, 3, 30, 11, 18, 26))).toBe(0);
    expect(wl.accountAgeDays('175928847299117063', Date.UTC(2016, 4, 31, 12))).toBe(31);
  });
  it('idade mínima 16', () => {
    expect(wl.validateAge('15')).toMatch(/16 anos/);
    expect(wl.validateAge('abc')).toBe('Idade inválida.');
    expect(wl.validateAge('22')).toBeNull();
  });
  it('mensagens de erro em português com data de nova tentativa', () => {
    expect(wl.errorMessage('retry_later', { retryAfter: '2026-11-17T15:00:00Z' })).toContain('17/11/2026');
    expect(wl.errorMessage('qualquer')).toMatch(/Algo deu errado/);
  });
  it('perguntas cabem no modal do Discord (máx. 5, rótulo ≤ 45)', () => {
    expect(wl.QUESTIONS.length).toBeLessThanOrEqual(5);
    for (const q of wl.QUESTIONS) expect(q.label.length).toBeLessThanOrEqual(45);
  });
});

describe('cliente da API', () => {
  it('envia token e corpo JSON', async () => {
    let seen: any;
    const fake = (async (url: string, init: any) => {
      seen = { url, init };
      return new Response(JSON.stringify({ id: 7 }), { status: 201 });
    }) as unknown as typeof fetch;
    const r = await new SpcApi('http://api', 'tok', fake).createApplication('123456789012345678', { a: 'b' });
    expect(r).toEqual({ ok: true, status: 201, data: { id: 7 } });
    expect(seen.url).toBe('http://api/v1/whitelist/applications');
    expect(seen.init.headers.authorization).toBe('Bearer tok');
    expect(JSON.parse(seen.init.body)).toEqual({ discordId: '123456789012345678', answers: { a: 'b' } });
  });
});
