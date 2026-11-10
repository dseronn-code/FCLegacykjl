// Lógica pura do fluxo de whitelist no Discord (testável sem conexão).
// Spec: docs/sp-capital-rp/specs/api-e-bot-whitelist.md §3

export const QUESTIONS = [
  { id: 'idade', label: 'Qual a sua idade (real)?', style: 'short', max: 3 },
  { id: 'experiencia', label: 'Sua experiência com roleplay', style: 'paragraph', max: 500 },
  { id: 'personagem', label: 'Nome e história do seu personagem', style: 'paragraph', max: 1000 },
  { id: 'amorAVida', label: 'O que é "amor à vida"? Dê um exemplo.', style: 'paragraph', max: 500 },
  { id: 'metagaming', label: 'O que é metagaming? Dê um exemplo.', style: 'paragraph', max: 500 },
] as const;

export type Action = 'interview' | 'approve' | 'reject';

/** customId dos botões/modais: `wl:<ação>:<id da candidatura>:<discordId do candidato>` */
export function encodeId(action: Action | 'rejectReason', appId: number, discordId: string) {
  return `wl:${action}:${appId}:${discordId}`;
}

export function decodeId(customId: string): { action: string; appId: number; discordId: string } | null {
  const m = /^wl:(interview|approve|reject|rejectReason):(\d+):(\d{17,20})$/.exec(customId);
  if (!m) return null;
  return { action: m[1]!, appId: Number(m[2]), discordId: m[3]! };
}

const DISCORD_EPOCH = 1420070400000n;
/** Idade da conta Discord em dias, a partir do snowflake. */
export function accountAgeDays(discordId: string, now = Date.now()) {
  const created = Number((BigInt(discordId) >> 22n) + DISCORD_EPOCH);
  return Math.floor((now - created) / 86_400_000);
}

export const RECENT_ACCOUNT_DAYS = 30;

const ERRORS: Record<string, string> = {
  already_pending: 'Você já tem uma whitelist em análise. Aguarde o resultado.',
  already_approved: 'Sua conta já está aprovada. Bem-vindo(a) à SP Capital!',
  suspended: 'Sua conta está suspensa. Abra um ticket.',
  retry_later: 'Sua última whitelist foi reprovada. Você poderá tentar de novo a partir de {retryAfter}.',
  forbidden: 'Você não tem permissão para revisar whitelists.',
  invalid_state: 'Esta whitelist já foi decidida por outra pessoa.',
  not_found: 'Whitelist não encontrada.',
  invalid_body: 'Respostas inválidas. Revise e tente de novo.',
};

export function errorMessage(code: string | undefined, extra: Record<string, unknown> = {}) {
  let msg = (code && ERRORS[code]) || 'Algo deu errado. Tente novamente em instantes.';
  if (typeof extra.retryAfter === 'string') {
    msg = msg.replace('{retryAfter}', new Date(extra.retryAfter).toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' }));
  }
  return msg;
}

export function validateAge(value: string): string | null {
  const n = Number(value.trim());
  if (!Number.isInteger(n) || n < 1 || n > 120) return 'Idade inválida.';
  if (n < 16) return 'A idade mínima para jogar na SP Capital é 16 anos.';
  return null;
}
