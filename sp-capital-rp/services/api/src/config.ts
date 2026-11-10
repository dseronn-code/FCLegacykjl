import { z } from 'zod';

const Env = z.object({
  PORT: z.coerce.number().int().default(3100),
  DB_HOST: z.string().default('127.0.0.1'),
  DB_PORT: z.coerce.number().int().default(3306),
  DB_SOCKET: z.string().optional(),
  DB_USER: z.string().default('root'),
  DB_PASSWORD: z.string().optional(),
  DB_NAME: z.string().default('spcapital'),
  REDIS_URL: z.string().default('redis://127.0.0.1:6379'),
  SPC_API_TOKEN: z.string().min(32, 'SPC_API_TOKEN precisa de pelo menos 32 caracteres'),
  SPC_BRIDGE_SECRET: z.string().min(16, 'SPC_BRIDGE_SECRET precisa de pelo menos 16 caracteres'),
});

export type Config = z.infer<typeof Env>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  return Env.parse(env);
}
