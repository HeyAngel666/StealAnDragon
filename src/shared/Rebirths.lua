-- Rebirths: zera dinheiro e dragões em troca de bônus permanentes.
-- Cash = dinheiro necessário | NeedRarity = precisa ter ao menos 1 dragão dessa raridade (ou melhor)
-- Multiplier = multiplicador TOTAL de renda depois desse rebirth | Unlocks = equipamento liberado

local Rebirths = {}

Rebirths.List = {
	{ Cash = 1e6, NeedRarity = "Epico", Multiplier = 1.5, Unlocks = "TapaFerro" },
	{ Cash = 5e6, NeedRarity = "Epico", Multiplier = 2, Unlocks = "BobinaGravidade" },
	{ Cash = 2e7, NeedRarity = "Lendario", Multiplier = 2.5, Unlocks = "Teia" },
	{ Cash = 7.5e7, NeedRarity = "Lendario", Multiplier = 3, Unlocks = "Capa" },
	{ Cash = 2.5e8, NeedRarity = "Lendario", Multiplier = 4 },
	{ Cash = 1e9, NeedRarity = "Mitico", Multiplier = 5, Unlocks = "RaioCongelante" },
	{ Cash = 4e9, NeedRarity = "Mitico", Multiplier = 6.5 },
	{ Cash = 1.5e10, NeedRarity = "Mitico", Multiplier = 8, Unlocks = "TapaEsmeralda" },
	{ Cash = 6e10, NeedRarity = "Divino", Multiplier = 10 },
	{ Cash = 2.5e11, NeedRarity = "Divino", Multiplier = 13 },
}

Rebirths.Max = #Rebirths.List

-- Multiplicador de renda para quem já tem X rebirths
function Rebirths.MultiplierFor(count: number): number
	if count <= 0 then
		return 1
	end
	local entry = Rebirths.List[math.min(count, Rebirths.Max)]
	return entry.Multiplier
end

return Rebirths
