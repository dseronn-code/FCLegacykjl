-- Configuração do spc_core. Valores de balanceamento ficam aqui, nunca espalhados no código.
-- Specs: docs/sp-capital-rp/specs/spc_core.md · docs/sp-capital-rp/specs/ledger.md
SPC = SPC or {}

SPC.Config = {
    -- Personagens
    DefaultCharSlots = 2,
    StarterMoney = 500000, -- centavos (R$ 5.000,00)
    Nationalities = { 'Brasileira', 'Portuguesa', 'Argentina', 'Italiana', 'Japonesa', 'Boliviana', 'Angolana' },
    MinAge = 18,
    MaxAge = 90,
    -- Palavras proibidas em nomes (comparação sem acento e minúscula). Lista completa mantida pela staff.
    BlockedNameWords = { 'admin', 'staff', 'policia', 'deus', 'hitler', 'teste' },
    DefaultSpawn = { x = -1037.74, y = -2738.04, z = 20.17, h = 330.0 }, -- Aeroporto Internacional da Capital

    -- Persistência
    SaveIntervalMs = 5 * 60 * 1000,
    SaveBatchSize = 25,
    SaveBatchDelayMs = 1000,

    -- Rate limits (ms entre chamadas por jogador)
    RateLimits = {
        ['characters:list'] = 1000,
        ['characters:create'] = 5000,
        ['characters:select'] = 2000,
    },

    -- Papéis de staff em ordem crescente (cada papel herda os anteriores)
    StaffRoles = { 'helper', 'mod', 'admin', 'head', 'dev', 'owner' },
    RolePermissions = {
        helper = { 'players.read', 'whitelist.review', 'tickets.handle' },
        mod    = { 'players.kick', 'players.spectate', 'players.teleport', 'players.revive', 'warnings.write', 'bans.temp', 'logs.read' },
        admin  = { 'bans.write', 'inventory.read', 'vehicles.manage' },
        head   = { 'economy.read', 'orgs.manage', 'staff.manage' },
        dev    = { 'server.manage', 'economy.revert' },
        owner  = { '*' },
    },

    -- Ledger
    Ledger = {
        MaxLegs = 10,
        MaxAmount = 1000000000000, -- 10 bilhões de reais em centavos, por movimento
        GovernmentCanGoNegative = false,
        -- Contas de sistema válidas. MINT = cria dinheiro, SINK = destrói, NEUTRAL = muda de forma (espécie)
        SystemAccounts = {
            MINT_STARTER = 'mint', MINT_SALARY = 'mint', MINT_NPC_SALE = 'mint', MINT_CRIME = 'mint',
            MINT_EVENT = 'mint', MINT_STAFF = 'mint',
            SINK_TAX = 'sink', SINK_SHOP = 'sink', SINK_FEE = 'sink', SINK_FINE = 'sink',
            SINK_FUEL = 'sink', SINK_RENT = 'sink', SINK_STAFF = 'sink',
            CASH_VAULT = 'neutral',
        },
        -- Alertas (centavos)
        AlertSingleMovement = 100000000, -- R$ 1.000.000,00
    },
}
