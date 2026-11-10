# Spec: `spc_ems` — Implementação do Hospital

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev · **Fase:** F2 · **Prioridade:** P0
Regras de negócio: [09-hospital.md](../09-hospital.md).

## 1. Estados de morte
- O cliente detecta a morte (`IsEntityDead` / evento `gameEventTriggered` `CEventNetworkEntityDamage`) e informa o servidor
  com causa e parte do corpo; o servidor registra `is_dead = 1` e o estado `downed` (state bag `ems`).
- O servidor controla os temporizadores (10 min caído; respawn liberado após 3 min sem médicos em serviço).
- Desconectar caído mantém o estado (volta caído). Respawn só pelo servidor.

## 2. Atendimento
- Médico em serviço (grupo `ems`) usa `ox_target` no paciente: diagnosticar, tratar (consome itens), reanimar.
- Cobrança: `Charge(paciente, valor, contaDoHospital)` + bônus ao médico pela conta do Governo; sem saldo → dívida.
- Prontuário: tabela `medical_records`, acesso com permissão `ems.records`; polícia só com mandado (spec da justiça).

## 3. Respawn
Hospital mais próximo; perde itens configurados (ilegais e espécie acima de R$ 1.000) via `ox_inventory`; taxa NPC.

## 4. Integração
- `spc_admin` `/reviver` dispara `spc_admin:server:revive` → tratado aqui (limpa estado).
- `spc_needs` pausa decaimento enquanto caído.

## 5. Critérios de aceite
1. O cliente não consegue "levantar" sozinho.
2. Respawn aplica perdas e cobrança exatamente uma vez.
