import { z } from 'zod';

const Snowflake = z.string().regex(/^\d{17,20}$/);
export const Config = z.object({
  DISCORD_TOKEN: z.string().min(10),
  DISCORD_GUILD_ID: Snowflake,
  CHANNEL_FORM_ID: Snowflake,
  CHANNEL_REVIEW_ID: Snowflake,
  ROLE_CITIZEN_ID: Snowflake,
  SPC_API_URL: z.string().url(),
  SPC_API_TOKEN: z.string().min(32),
});
export type Config = z.infer<typeof Config>;
