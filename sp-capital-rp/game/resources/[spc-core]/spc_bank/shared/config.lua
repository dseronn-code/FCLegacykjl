-- Locais e limites do Banco Capital (valores em REAIS inteiros; o servidor converte para centavos)
SPCBank = SPCBank or {}
SPCBank.Config = {
    -- Agências (antigas Fleeca/Pacific). Coordenadas a revisar no primeiro boot em staging.
    Branches = {
        { label = 'Agência Centro', coords = { x = 149.9, y = -1040.46, z = 29.37 } },
        { label = 'Agência Jardins', coords = { x = 314.23, y = -278.83, z = 54.17 } },
        { label = 'Agência Bela Vista', coords = { x = -350.8, y = -49.57, z = 49.04 } },
        { label = 'Agência Litoral', coords = { x = -1213.0, y = -330.39, z = 37.79 } },
        { label = 'Agência Rodovia', coords = { x = -2962.71, y = 482.25, z = 15.7 } },
        { label = 'Agência Serra Verde', coords = { x = 1175.06, y = 2706.64, z = 38.09 } },
        { label = 'Banco Central da Capital', coords = { x = 246.64, y = 223.2, z = 106.29 } },
        { label = 'Agência Vila do Porto', coords = { x = -112.2, y = 6469.29, z = 31.63 } },
    },
    AtmModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' },
    MaxDistance = 3.0,
    Limits = {
        AtmWithdrawPerOp = 2000, AtmWithdrawPerDay = 10000, AtmDepositPerOp = 2000,
        BranchWithdrawPerOp = 50000, BranchDepositPerOp = 1000000,
        PixPerOp = 100000, PixTaxThreshold = 50000, PixTaxPercent = 1,
    },
    CooldownMs = 2000,
}
