# Spec: `spc_police` — Ferramentas da Polícia e MDT

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev + Comando da Polícia · **Fase:** F2 · **Prioridade:** P0
Regras de negócio: [08-policia.md](../08-policia.md) · Código Penal: [publico/codigo-penal.md](../publico/codigo-penal.md).

## 1. Serviço
- Grupos `pmc`, `pciv`, `prc` com graus (empregos de governo). Entrar/sair de serviço no batalhão (ponto em `job_sessions`).
- Ao entrar: equipamentos do armário por patente, com número de série registrado; ao sair, devolução obrigatória.

## 2. Ações (todas validadas no servidor)
Algemar/desalgemar, escoltar, colocar no veículo, revistar (abre o inventário do alvo via `ox_inventory`), apreender
item, multar (`IssueFine` do DETRAN), prender (envia ao sistema prisional com pena calculada).

## 3. MDT (NUI)
- Busca de pessoa (nome/RG/CPF) e de veículo (placa).
- Prisão: o policial escolhe artigos do `penal-code.json`; **o servidor calcula** pena e multa (atenuantes/agravantes
  da seção "Regras de aplicação" do Código Penal), limita a 120 meses e grava `criminal_records`.
- Boletins de ocorrência, mandados (pedido ao juiz; emitidos pela justiça).
- Unidades em serviço e status por Código Q.

## 4. Despacho
Alertas de crime com atraso e imprecisão configuráveis, chamadas 190 do celular, botão de pânico.

## 5. Prisão
Pena em minutos (1 mês = 1 min), contada no servidor só com o jogador online; `jail_minutes` persiste.
Desconectar algemado ou em abordagem → pena em dobro no próximo login.

## 6. Critérios de aceite
1. Cálculo de pena idêntico ao documento público (testes unitários com o `penal-code.json`).
2. Cliente não consegue prender/multar sem estar em serviço e próximo do alvo.
