// Cliente da API da SP Capital (token de serviço).
export interface ApiResult<T = any> { ok: boolean; status: number; data: T & { error?: string } }

export class SpcApi {
  constructor(private baseUrl: string, private token: string, private fetchFn: typeof fetch = fetch) {}

  private async req<T>(method: string, path: string, body?: unknown): Promise<ApiResult<T>> {
    const res = await this.fetchFn(`${this.baseUrl}${path}`, {
      method,
      headers: { authorization: `Bearer ${this.token}`, ...(body ? { 'content-type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(8000),
    });
    const data = (await res.json().catch(() => ({}))) as T & { error?: string };
    return { ok: res.ok, status: res.status, data };
  }

  createApplication(discordId: string, answers: Record<string, string>) {
    return this.req<{ id: number }>('POST', '/v1/whitelist/applications', { discordId, answers });
  }
  interview(id: number, staffDiscordId: string) {
    return this.req<{ discordId: string }>('POST', `/v1/whitelist/applications/${id}/interview`, { staffDiscordId });
  }
  approve(id: number, staffDiscordId: string) {
    return this.req<{ discordId: string }>('POST', `/v1/whitelist/applications/${id}/approve`, { staffDiscordId });
  }
  reject(id: number, staffDiscordId: string, reason: string) {
    return this.req<{ discordId: string }>('POST', `/v1/whitelist/applications/${id}/reject`, { staffDiscordId, reason });
  }
  status() {
    return this.req<{ online: number }>('GET', '/v1/server/status');
  }
}
