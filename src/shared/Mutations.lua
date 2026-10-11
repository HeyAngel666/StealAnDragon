-- Mutações: versões especiais dos dragões que rendem mais dinheiro.
-- Chance = probabilidade (0 a 1) ao nascer na esteira. EventOnly = só aparece em evento.

local Mutations = {}

Mutations.List = {
	{ Id = "Normal", Name = "", Multiplier = 1, Chance = 0 },
	{ Id = "Ouro", Name = "Ouro", Multiplier = 1.5, Chance = 0.07, Color = Color3.fromRGB(255, 200, 40) },
	{ Id = "Diamante", Name = "Diamante", Multiplier = 2, Chance = 0.025, Color = Color3.fromRGB(120, 230, 255) },
	{ Id = "Lava", Name = "Lava", Multiplier = 3, Chance = 0, EventOnly = true, Color = Color3.fromRGB(255, 90, 20) },
	{ Id = "ArcoIris", Name = "Arco-Íris", Multiplier = 5, Chance = 0.005, Color = Color3.fromRGB(255, 120, 220) },
}

Mutations.ById = {}
for index, mutation in ipairs(Mutations.List) do
	mutation.Order = index
	Mutations.ById[mutation.Id] = mutation
end

function Mutations.Get(id: string?)
	return Mutations.ById[id or "Normal"] or Mutations.ById.Normal
end

-- Ordem de "subida" usada pelo passe de Sorte (Normal -> Ouro -> Diamante -> Arco-Íris)
Mutations.UpgradeChain = { Normal = "Ouro", Ouro = "Diamante", Diamante = "ArcoIris", Lava = "ArcoIris" }

-- Sorteia uma mutação. boosts = { Ouro = 5, Lava = 1 ... } multiplica/ativa chances.
function Mutations.Roll(boostsArg: { [string]: number }?, rngArg: Random?): string
	local rng = rngArg or Random.new()
	local boosts = boostsArg or {}
	local roll = rng:NextNumber()
	local acc = 0
	-- das mais raras para as mais comuns
	for i = #Mutations.List, 2, -1 do
		local m = Mutations.List[i]
		local chance = m.Chance
		local boost = boosts[m.Id]
		if m.EventOnly then
			chance = boost and 0.15 or 0
		elseif boost then
			chance *= boost
		end
		acc += chance
		if roll < acc then
			return m.Id
		end
	end
	return "Normal"
end

return Mutations
