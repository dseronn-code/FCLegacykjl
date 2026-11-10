# Spec: SPhone — Celular

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** UI + Lead Dev · **Fase:** F2 · **Prioridade:** P1

## 1. Decisão
Avaliar adotar um celular de código aberto mantido (ex.: npwd) com apps próprios, em vez de escrever do zero.
Critérios: licença compatível, performance (NUI carregada sob demanda), suporte a apps externos, ausência de
lógica sensível no cliente. Decisão registrada em ADR antes da implementação.

## 2. Apps da fase 2
| App | Dados | Observação |
|-----|-------|-----------|
| Telefone e Contatos | `phone_contacts`, `phone_calls` | Chamadas via `pma-voice` |
| Mensagens ("Zap") | `phone_messages` (particionada por mês, 90 dias) | Paginação no servidor |
| Banco Capital | `spc_bank` (saldo, extrato, PIX) | Mesmas validações do caixa, sem exigir proximidade |
| 190 / 192 / 193 | Despacho | Localização aproximada |
| Classificados ("Desapega") | Tabela própria | Taxa de anúncio (dreno) |
| Câmera e galeria | URLs de imagem em CDN | Upload por serviço com limite de tamanho |

## 3. Regras
- Precisa do item `phone`; sem ele, o celular não abre.
- Número = `characters.phone_number`.
- Mensagens e chamadas são logadas (metadados), conteúdo só acessível com mandado (spec da justiça).
