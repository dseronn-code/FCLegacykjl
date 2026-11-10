-- Itens da SP Capital mesclados aos itens originais do ox_inventory.
-- O instalador renomeia o items.lua original para items_upstream.lua (uma única vez).
-- Spec: docs/sp-capital-rp/specs/inventario.md §5
local items = lib.load('data.items_upstream') or {}

local spc = {
    ['money'] = { label = 'Dinheiro', weight = 0 },
    ['dirty_money'] = { label = 'Dinheiro sujo', weight = 0, description = 'Notas sem origem. Não aceitas no banco.' },
    ['phone'] = { label = 'Celular', weight = 190, stack = false, consume = 0 },
    ['radio'] = { label = 'Rádio comunicador', weight = 800, stack = false, allowArmed = true },
    ['id_card'] = { label = 'RG', weight = 5, stack = false, close = true },
    ['driver_license'] = { label = 'CNH', weight = 5, stack = false, close = true },
    -- Comida/bebida: efeitos em fome/sede virão com a spec de necessidades (servidor autoritativo)
    ['water'] = { label = 'Água mineral', weight = 500 },
    ['soda'] = { label = 'Refrigerante', weight = 350 },
    ['sandwich'] = { label = 'Misto-quente', weight = 220 },
    ['pastel'] = { label = 'Pastel de feira', weight = 200 },
    ['coffee'] = { label = 'Café coado', weight = 150 },
    ['bandage'] = { label = 'Atadura', weight = 115 },
    ['medkit'] = { label = 'Kit de primeiros socorros', weight = 1000, stack = false },
    ['lockpick'] = { label = 'Grampo', weight = 160 },
    ['repairkit'] = { label = 'Kit de reparo', weight = 2500, stack = false },
    ['fuelcan'] = { label = 'Galão de combustível', weight = 5000, stack = false },
}

for name, data in pairs(spc) do
    items[name] = items[name] and lib.table.merge(items[name], data, false) or data
end

return items
