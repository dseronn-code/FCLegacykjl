// Bot de whitelist da SP Capital. Spec: docs/sp-capital-rp/specs/api-e-bot-whitelist.md
import {
  ActionRowBuilder, ButtonBuilder, ButtonStyle, ChannelType, Client, EmbedBuilder, Events, GatewayIntentBits,
  ModalBuilder, TextInputBuilder, TextInputStyle,
  type ButtonInteraction, type ChatInputCommandInteraction, type ModalSubmitInteraction, type TextChannel,
} from 'discord.js';
import { SpcApi } from './api.js';
import { Config } from './config.js';
import * as wl from './whitelist.js';

const cfg = Config.parse(process.env);
const api = new SpcApi(cfg.SPC_API_URL, cfg.SPC_API_TOKEN);
const client = new Client({ intents: [GatewayIntentBits.Guilds] });

const START_ID = 'wl:start';
const MODAL_ID = 'wl:form';

function reviewButtons(appId: number, discordId: string, disabled = false) {
  return new ActionRowBuilder<ButtonBuilder>().addComponents(
    new ButtonBuilder().setCustomId(wl.encodeId('interview', appId, discordId)).setLabel('Chamar p/ entrevista').setStyle(ButtonStyle.Secondary).setDisabled(disabled),
    new ButtonBuilder().setCustomId(wl.encodeId('approve', appId, discordId)).setLabel('Aprovar').setStyle(ButtonStyle.Success).setDisabled(disabled),
    new ButtonBuilder().setCustomId(wl.encodeId('reject', appId, discordId)).setLabel('Reprovar').setStyle(ButtonStyle.Danger).setDisabled(disabled),
  );
}

async function ensureFormMessage() {
  const channel = await client.channels.fetch(cfg.CHANNEL_FORM_ID);
  if (!channel || channel.type !== ChannelType.GuildText) throw new Error('CHANNEL_FORM_ID não é um canal de texto');
  const recent = await channel.messages.fetch({ limit: 20 });
  if (recent.some((m) => m.author.id === client.user?.id && m.components.length > 0)) return;
  await channel.send({
    embeds: [new EmbedBuilder().setColor(0xf2b705).setTitle('Whitelist da SP Capital')
      .setDescription('Leia as #regras e clique no botão abaixo. Depois do formulário, a staff pode chamar você para uma entrevista rápida por voz.')],
    components: [new ActionRowBuilder<ButtonBuilder>().addComponents(
      new ButtonBuilder().setCustomId(START_ID).setLabel('Fazer whitelist').setStyle(ButtonStyle.Primary))],
  });
}

async function showForm(i: ButtonInteraction) {
  const modal = new ModalBuilder().setCustomId(MODAL_ID).setTitle('Whitelist — SP Capital');
  for (const q of wl.QUESTIONS) {
    modal.addComponents(new ActionRowBuilder<TextInputBuilder>().addComponents(
      new TextInputBuilder().setCustomId(q.id).setLabel(q.label).setRequired(true).setMaxLength(q.max)
        .setStyle(q.style === 'short' ? TextInputStyle.Short : TextInputStyle.Paragraph)));
  }
  await i.showModal(modal);
}

async function submitForm(i: ModalSubmitInteraction) {
  await i.deferReply({ ephemeral: true });
  const answers = Object.fromEntries(wl.QUESTIONS.map((q) => [q.id, i.fields.getTextInputValue(q.id).trim()]));
  const ageError = wl.validateAge(answers.idade ?? '');
  if (ageError) return i.editReply(ageError);

  const res = await api.createApplication(i.user.id, answers);
  if (!res.ok) return i.editReply(wl.errorMessage(res.data.error, res.data));

  const ageDays = wl.accountAgeDays(i.user.id);
  const embed = new EmbedBuilder().setColor(0x4aa3ff).setTitle(`Whitelist #${res.data.id}`)
    .setDescription(`<@${i.user.id}> (${i.user.tag}) · conta Discord com ${ageDays} dia(s)`)
    .addFields(wl.QUESTIONS.map((q) => ({ name: q.label, value: answers[q.id]?.slice(0, 1024) || '—' })));
  if (ageDays < wl.RECENT_ACCOUNT_DAYS) embed.addFields({ name: '⚠️ Conta recente', value: 'Revisão extra: possível conta alternativa.' });

  const review = (await client.channels.fetch(cfg.CHANNEL_REVIEW_ID)) as TextChannel;
  await review.send({ embeds: [embed], components: [reviewButtons(res.data.id, i.user.id)] });
  await i.editReply('Whitelist enviada! Você receberá o resultado por mensagem direta.');
}

async function dm(discordId: string, text: string) {
  try { await (await client.users.fetch(discordId)).send(text); } catch { /* DM fechada */ }
}

async function closeCard(i: ButtonInteraction | ModalSubmitInteraction, result: string) {
  if (!i.message) return;
  const parsed = wl.decodeId(i.message.components[0]?.components[0]?.customId ?? '');
  const embed = EmbedBuilder.from(i.message.embeds[0]!).addFields({ name: 'Resultado', value: `${result} por <@${i.user.id}>` });
  await i.message.edit({ embeds: [embed], components: parsed ? [reviewButtons(parsed.appId, parsed.discordId, true)] : [] });
}

async function review(i: ButtonInteraction) {
  const id = wl.decodeId(i.customId);
  if (!id) return;
  if (id.action === 'reject') {
    const modal = new ModalBuilder().setCustomId(wl.encodeId('rejectReason', id.appId, id.discordId)).setTitle(`Reprovar whitelist #${id.appId}`)
      .addComponents(new ActionRowBuilder<TextInputBuilder>().addComponents(
        new TextInputBuilder().setCustomId('reason').setLabel('Motivo (enviado ao candidato)').setStyle(TextInputStyle.Paragraph).setMinLength(5).setMaxLength(500).setRequired(true)));
    return i.showModal(modal);
  }

  await i.deferReply({ ephemeral: true });
  if (id.action === 'interview') {
    const res = await api.interview(id.appId, i.user.id);
    if (!res.ok) return i.editReply(wl.errorMessage(res.data.error));
    await dm(id.discordId, 'Sua whitelist da SP Capital avançou! Entre na sala de espera de entrevistas no Discord.');
    return i.editReply('Candidato avisado para a entrevista.');
  }

  const res = await api.approve(id.appId, i.user.id);
  if (!res.ok) return i.editReply(wl.errorMessage(res.data.error));
  try {
    const guild = await client.guilds.fetch(cfg.DISCORD_GUILD_ID);
    await (await guild.members.fetch(id.discordId)).roles.add(cfg.ROLE_CITIZEN_ID, `Whitelist #${id.appId} aprovada`);
  } catch { await i.followUp({ content: 'Aprovado, mas não consegui dar o cargo (o candidato saiu do servidor?).', ephemeral: true }); }
  await dm(id.discordId, '✅ Sua whitelist foi **aprovada**! Bem-vindo(a) à SP Capital. Você já pode entrar na cidade.');
  await closeCard(i, '✅ Aprovada');
  return i.editReply('Whitelist aprovada.');
}

async function rejectWithReason(i: ModalSubmitInteraction) {
  const id = wl.decodeId(i.customId);
  if (!id) return;
  await i.deferReply({ ephemeral: true });
  const reason = i.fields.getTextInputValue('reason').trim();
  const res = await api.reject(id.appId, i.user.id, reason);
  if (!res.ok) return i.editReply(wl.errorMessage(res.data.error));
  await dm(id.discordId, `❌ Sua whitelist da SP Capital foi reprovada.\nMotivo: ${reason}\nVocê pode tentar novamente em 7 dias.`);
  await closeCard(i, '❌ Reprovada');
  return i.editReply('Whitelist reprovada.');
}

async function status(i: ChatInputCommandInteraction) {
  const res = await api.status();
  await i.reply({ content: res.ok ? `🏙️ SP Capital online — **${res.data.online}** jogador(es) na cidade.` : 'Servidor indisponível no momento.', ephemeral: true });
}

client.once(Events.ClientReady, async (c) => {
  console.log(`[bot] conectado como ${c.user.tag}`);
  const guild = await c.guilds.fetch(cfg.DISCORD_GUILD_ID);
  await guild.commands.set([{ name: 'status', description: 'Status da cidade (jogadores online)' }]);
  await ensureFormMessage();
});

client.on(Events.InteractionCreate, async (i) => {
  try {
    if (i.isButton() && i.customId === START_ID) return await showForm(i);
    if (i.isButton() && i.customId.startsWith('wl:')) return await review(i);
    if (i.isModalSubmit() && i.customId === MODAL_ID) return await submitForm(i);
    if (i.isModalSubmit() && i.customId.startsWith('wl:rejectReason:')) return await rejectWithReason(i);
    if (i.isChatInputCommand() && i.commandName === 'status') return await status(i);
  } catch (e) {
    console.error('[bot] erro na interação', e);
    if (i.isRepliable()) {
      const msg = { content: 'Algo deu errado. Tente novamente.', ephemeral: true };
      await (i.deferred || i.replied ? i.followUp(msg) : i.reply(msg)).catch(() => {});
    }
  }
});

await client.login(cfg.DISCORD_TOKEN);
