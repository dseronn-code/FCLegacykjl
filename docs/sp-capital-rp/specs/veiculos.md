# Spec: `spc_vehicles` — Veículos, Chaves, Garagens e Combustível

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev · **Fase:** F2 · **Prioridade:** P0

## 1. Modelo
Tabela `vehicles` (migração 0003) + colunas novas: `renavam`, `crlv_valid_until`, `ipva_paid_until`, `stolen`.
Placa Mercosul `ABC1D23` gerada no servidor (única). Veículo **é do banco**, não do cliente: o servidor cria a
entidade (`CreateVehicleServerSetter`) ao retirar da garagem e grava `state = 'out'`.

## 2. Chaves
- Item `vehicle_key` com metadados `{ plate }`. Dono recebe 1 chave na compra; cópia no chaveiro (R$ 300, dreno).
- Trancar/destrancar (tecla) valida no servidor: o jogador tem a chave da placa e está a ≤ 10 m.
- Ligação direta com `lockpick` (crime, alerta à polícia com 40% de chance).

## 3. Garagens
- Públicas (bairros, R$ 50 por retirada — dreno) e privadas (casas, empresas, facções, instituições).
- Guardar: o servidor salva combustível, dano do motor/lataria e mods, apaga a entidade, `state = 'garage'`.
- Veículo `out` que sumiu (despawn, restart): após o restart volta como `garage` na última garagem.
- Veículo destruído: `state = 'destroyed'`; com seguro, recuperável na seguradora; sem seguro, perdido.

## 4. Combustível
- Consumo por classe/rotação, calculado no **cliente do motorista** e enviado ao servidor no máximo a cada 10 s
  como `fuel` absoluto; o servidor aceita somente **redução** (nunca aumento) — evita cheat de combustível.
- Abastecer: posto (preço do litro na config), cobrança via `Charge(... 'SINK_FUEL', 'fuel.buy')` antes de encher.

## 5. Concessionárias
Catálogo em config (modelo, preço, categoria de CNH exigida, estoque opcional). Compra: `Charge` → cria veículo,
placa, RENAVAM, chave e emplacamento automático (DETRAN). Exige CNH da categoria (export do DETRAN).

## 6. Critérios de aceite
1. Não é possível retirar o mesmo veículo duas vezes.
2. Combustível nunca aumenta sem pagamento.
3. Só quem tem a chave tranca/destranca.
