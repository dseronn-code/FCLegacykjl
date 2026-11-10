# Spec: `spc_multichar` — Seleção e Criação de Personagem

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev + UI · **Fase:** F1 · **Prioridade:** P0

## 1. Objetivo
Interface (NUI) exibida após a entrada na cidade para listar, criar e escolher personagens. Toda regra fica
no `spc_core` (callbacks já existentes); a NUI só coleta dados e mostra erros.

## 2. Fluxo
1. Cliente conectado (`spc_core` criou a sessão) → `spc_multichar` congela o ped, coloca câmera fixa
   (mirante da Avenida Paulistana), esconde HUD e radar, abre a NUI com foco.
2. NUI pede `spc_core:characters:list`. Mostra até `slots` cartões (nome, nascimento, `citizenid`) e cartões vazios.
3. **Criar:** formulário (nome, sobrenome, nascimento, gênero, nacionalidade) → `spc_core:characters:create`.
   Erros traduzidos (tabela abaixo). Sucesso → recarrega a lista.
4. **Entrar:** `spc_core:characters:select` → fecha NUI, destrói câmera, devolve controle. O spawn é feito pelo
   `spc_core` (evento `spc_core:client:characterLoaded`).
5. A NUI não abre de novo enquanto o personagem estiver carregado (`LocalPlayer.state.loaded`).

## 3. Mensagens de erro (código → texto)
| Código | Texto |
|--------|-------|
| `invalid_name_length` | O nome deve ter entre 2 e 20 letras. |
| `invalid_name_chars` / `invalid_name` | Use apenas letras, espaço, hífen ou apóstrofo. |
| `blocked_name` | Esse nome não é permitido na cidade. |
| `invalid_birthdate` | Data de nascimento inválida. |
| `invalid_age` | O personagem deve ter entre 18 e 90 anos. |
| `no_slots` | Você não tem vagas livres para novos personagens. |
| `rate_limited` | Aguarde alguns segundos e tente novamente. |
| outros | Não foi possível concluir. Tente novamente. |

## 4. Requisitos de UI
- HTML/CSS/JS sem framework (carregamento rápido), PT-BR, navegação por teclado, contraste AA.
- Nenhum dado sensível além do que o servidor devolveu.
- Orçamento: 0 ms de CPU quando fechada (sem loops), NUI < 200 KB.

## 5. Critérios de aceite
1. Jogador novo vê slots vazios, cria personagem e entra.
2. Erros de validação aparecem em português no formulário.
3. Após entrar, a câmera e o foco da NUI são liberados e o HUD aparece.
