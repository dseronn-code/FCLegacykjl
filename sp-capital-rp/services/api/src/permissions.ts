// Permissões de staff: mesma fonte do jogo (gerada de spc_core/shared/config.lua).
import perms from '../../../packages/shared/permissions.json' with { type: 'json' };

const effective = perms.effective as Record<string, string[]>;

export function roleHas(role: string | null | undefined, permission: string): boolean {
  if (!role) return false;
  const list = effective[role];
  if (!list) return false;
  if (list.includes('*') || list.includes(permission)) return true;
  const prefix = permission.split('.')[0];
  return list.includes(`${prefix}.*`);
}
