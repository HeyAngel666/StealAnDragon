-- Catálogo de dragões.
-- Price = preço na esteira | Income = dinheiro por segundo
-- Visual: cores, estilo do corpo e efeitos usados pelo DragonBuilder.

local Rarities = require(script.Parent.Rarities)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Dragons = {}

Dragons.List = {
	-- COMUM
	{ Id = "Verdinho", Name = "Dragãozinho Verde", Rarity = "Comum", Price = 25, Income = 1,
		Body = rgb(90, 180, 70), Belly = rgb(220, 230, 140), Wing = rgb(60, 140, 50), Eye = rgb(255, 255, 255), Style = "Basic" },
	{ Id = "Lagartixa", Name = "Lagartixa de Fogo", Rarity = "Comum", Price = 60, Income = 2,
		Body = rgb(230, 110, 50), Belly = rgb(255, 210, 120), Wing = rgb(200, 70, 40), Eye = rgb(255, 255, 0), Style = "Basic" },
	{ Id = "Lama", Name = "Dragão de Lama", Rarity = "Comum", Price = 120, Income = 4,
		Body = rgb(120, 85, 55), Belly = rgb(170, 130, 90), Wing = rgb(95, 65, 40), Eye = rgb(255, 230, 150), Style = "Chunky" },
	{ Id = "Cinzento", Name = "Filhote Cinzento", Rarity = "Comum", Price = 200, Income = 6,
		Body = rgb(140, 140, 150), Belly = rgb(200, 200, 205), Wing = rgb(110, 110, 120), Eye = rgb(120, 220, 255), Style = "Basic" },

	-- INCOMUM
	{ Id = "Pedra", Name = "Dragão de Pedra", Rarity = "Incomum", Price = 500, Income = 12,
		Body = rgb(105, 100, 95), Belly = rgb(150, 145, 135), Wing = rgb(85, 80, 75), Eye = rgb(255, 140, 0), Style = "Chunky", Material = "Slate" },
	{ Id = "Serpente", Name = "Serpente do Rio", Rarity = "Incomum", Price = 900, Income = 20,
		Body = rgb(40, 140, 190), Belly = rgb(170, 230, 240), Wing = rgb(30, 100, 160), Eye = rgb(255, 255, 255), Style = "Serpent" },
	{ Id = "Abobora", Name = "Dragão Abóbora", Rarity = "Incomum", Price = 1500, Income = 30,
		Body = rgb(240, 130, 20), Belly = rgb(255, 200, 80), Wing = rgb(60, 120, 40), Eye = rgb(255, 255, 0), Style = "Chunky", Effects = { "Smoke" } },
	{ Id = "Morcego", Name = "Dragão Morcego", Rarity = "Incomum", Price = 2500, Income = 45,
		Body = rgb(60, 45, 70), Belly = rgb(110, 90, 120), Wing = rgb(40, 30, 50), Eye = rgb(255, 50, 50), Style = "Spiky" },

	-- RARO
	{ Id = "Gelo", Name = "Dragão de Gelo", Rarity = "Raro", Price = 6000, Income = 90,
		Body = rgb(170, 225, 255), Belly = rgb(240, 250, 255), Wing = rgb(120, 190, 240), Eye = rgb(0, 120, 255), Style = "Spiky", Material = "Ice", Effects = { "Sparkles" } },
	{ Id = "Trovao", Name = "Dragão do Trovão", Rarity = "Raro", Price = 10000, Income = 140,
		Body = rgb(250, 220, 40), Belly = rgb(255, 250, 180), Wing = rgb(60, 60, 90), Eye = rgb(120, 220, 255), Style = "Spiky", Effects = { "Lightning" } },
	{ Id = "Esmeralda", Name = "Dragão Esmeralda", Rarity = "Raro", Price = 16000, Income = 210,
		Body = rgb(20, 170, 100), Belly = rgb(150, 255, 190), Wing = rgb(10, 120, 70), Eye = rgb(255, 255, 255), Style = "Crystal", Material = "Glass" },
	{ Id = "Sombrio", Name = "Dragão Sombrio", Rarity = "Raro", Price = 25000, Income = 300,
		Body = rgb(30, 25, 40), Belly = rgb(70, 50, 90), Wing = rgb(20, 15, 30), Eye = rgb(170, 60, 255), Style = "Spiky", Effects = { "Smoke" } },

	-- ÉPICO
	{ Id = "Cristal", Name = "Dragão de Cristal", Rarity = "Epico", Price = 60000, Income = 650,
		Body = rgb(230, 140, 255), Belly = rgb(255, 220, 255), Wing = rgb(180, 100, 240), Eye = rgb(255, 255, 255), Style = "Crystal", Material = "Glass", Effects = { "Sparkles" } },
	{ Id = "Tempestade", Name = "Dragão Tempestade", Rarity = "Epico", Price = 100000, Income = 1000,
		Body = rgb(70, 90, 140), Belly = rgb(150, 170, 210), Wing = rgb(40, 50, 90), Eye = rgb(200, 240, 255), Style = "Serpent", Effects = { "Lightning", "Smoke" } },
	{ Id = "Esqueleto", Name = "Dragão Esqueleto", Rarity = "Epico", Price = 160000, Income = 1500,
		Body = rgb(235, 230, 210), Belly = rgb(200, 195, 175), Wing = rgb(80, 75, 70), Eye = rgb(60, 255, 120), Style = "Skeleton", Effects = { "Aura" } },
	{ Id = "Wyvern", Name = "Wyvern Real", Rarity = "Epico", Price = 250000, Income = 2200,
		Body = rgb(150, 20, 40), Belly = rgb(255, 210, 100), Wing = rgb(110, 10, 30), Eye = rgb(255, 220, 0), Style = "Spiky", Effects = { "Crown" } },

	-- LENDÁRIO
	{ Id = "Fenix", Name = "Dragão Fênix", Rarity = "Lendario", Price = 750000, Income = 6000,
		Body = rgb(255, 120, 20), Belly = rgb(255, 230, 80), Wing = rgb(255, 60, 20), Eye = rgb(255, 255, 255), Style = "Basic", Material = "Neon", Effects = { "Fire" } },
	{ Id = "Vulcanico", Name = "Dragão Vulcânico", Rarity = "Lendario", Price = 1200000, Income = 9000,
		Body = rgb(45, 30, 30), Belly = rgb(255, 80, 0), Wing = rgb(70, 20, 10), Eye = rgb(255, 160, 0), Style = "Chunky", Effects = { "Fire", "Smoke" } },
	{ Id = "Celestial", Name = "Dragão Celestial", Rarity = "Lendario", Price = 2000000, Income = 14000,
		Body = rgb(240, 245, 255), Belly = rgb(255, 230, 150), Wing = rgb(200, 220, 255), Eye = rgb(80, 180, 255), Style = "Serpent", Effects = { "Sparkles", "Halo" } },
	{ Id = "Hidra", Name = "Hidra Dourada", Rarity = "Lendario", Price = 3500000, Income = 22000,
		Body = rgb(230, 180, 40), Belly = rgb(255, 240, 160), Wing = rgb(200, 140, 20), Eye = rgb(255, 30, 30), Style = "Hydra", Material = "Metal", Effects = { "Sparkles" } },

	-- MÍTICO
	{ Id = "Vacuo", Name = "Dragão do Vácuo", Rarity = "Mitico", Price = 10000000, Income = 55000,
		Body = rgb(20, 0, 40), Belly = rgb(120, 0, 200), Wing = rgb(60, 0, 120), Eye = rgb(255, 0, 255), Style = "Spiky", Effects = { "Aura", "Stars" } },
	{ Id = "Leviata", Name = "Leviatã Abissal", Rarity = "Mitico", Price = 18000000, Income = 90000,
		Body = rgb(10, 60, 90), Belly = rgb(40, 200, 200), Wing = rgb(5, 40, 70), Eye = rgb(0, 255, 200), Style = "Serpent", Material = "Glass", Effects = { "Bubbles", "Aura" } },
	{ Id = "Solar", Name = "Dragão Solar", Rarity = "Mitico", Price = 30000000, Income = 140000,
		Body = rgb(255, 200, 0), Belly = rgb(255, 255, 200), Wing = rgb(255, 140, 0), Eye = rgb(255, 255, 255), Style = "Spiky", Material = "Neon", Effects = { "Fire", "Halo" } },
	{ Id = "Lunar", Name = "Dragão Lunar", Rarity = "Mitico", Price = 45000000, Income = 200000,
		Body = rgb(190, 200, 230), Belly = rgb(240, 245, 255), Wing = rgb(90, 100, 160), Eye = rgb(140, 200, 255), Style = "Basic", Material = "Glass", Effects = { "Stars", "Halo" } },

	-- DIVINO
	{ Id = "Arcanjo", Name = "Dragão Arcanjo", Rarity = "Divino", Price = 150000000, Income = 600000,
		Body = rgb(255, 255, 255), Belly = rgb(255, 230, 140), Wing = rgb(255, 250, 220), Eye = rgb(255, 200, 0), Style = "Basic", Material = "Neon", Effects = { "Halo", "Sparkles", "Aura" } },
	{ Id = "Tempo", Name = "Dragão do Tempo", Rarity = "Divino", Price = 300000000, Income = 1100000,
		Body = rgb(60, 200, 220), Belly = rgb(220, 255, 255), Wing = rgb(30, 120, 160), Eye = rgb(255, 255, 255), Style = "Crystal", Material = "Glass", Effects = { "Stars", "Aura" } },
	{ Id = "Galactico", Name = "Dragão Galáctico", Rarity = "Divino", Price = 600000000, Income = 2000000,
		Body = rgb(40, 20, 110), Belly = rgb(255, 120, 230), Wing = rgb(20, 10, 70), Eye = rgb(255, 255, 255), Style = "Serpent", Material = "Neon", Effects = { "Stars", "Aura", "Sparkles" } },
	{ Id = "Bahamut", Name = "Bahamut", Rarity = "Divino", Price = 1000000000, Income = 3200000,
		Body = rgb(40, 40, 50), Belly = rgb(255, 215, 0), Wing = rgb(255, 215, 0), Eye = rgb(255, 60, 0), Style = "Spiky", Material = "Metal", Effects = { "Fire", "Crown", "Aura" } },

	-- SECRETO
	{ Id = "Glitch", Name = "Dragão Glitch", Rarity = "Secreto", Price = 5000000000, Income = 12000000,
		Body = rgb(0, 255, 120), Belly = rgb(255, 0, 255), Wing = rgb(0, 0, 0), Eye = rgb(255, 255, 255), Style = "Crystal", Material = "Neon", Effects = { "Glitch", "Aura" } },
	{ Id = "ReiSupremo", Name = "Dragão Rei Supremo", Rarity = "Secreto", Price = 15000000000, Income = 30000000,
		Body = rgb(120, 0, 20), Belly = rgb(255, 215, 0), Wing = rgb(255, 215, 0), Eye = rgb(255, 255, 255), Style = "Hydra", Material = "Metal", Effects = { "Crown", "Fire", "Aura" } },
	{ Id = "Ancestral", Name = "Dragão Arco-Íris Ancestral", Rarity = "Secreto", Price = 40000000000, Income = 70000000,
		Body = rgb(255, 255, 255), Belly = rgb(255, 255, 255), Wing = rgb(255, 255, 255), Eye = rgb(0, 0, 0), Style = "Serpent", Material = "Neon", Effects = { "Rainbow", "Stars", "Halo" } },
	{ Id = "Primordial", Name = "Dragão Primordial", Rarity = "Secreto", Price = 100000000000, Income = 150000000,
		Body = rgb(10, 10, 10), Belly = rgb(255, 40, 0), Wing = rgb(10, 10, 10), Eye = rgb(255, 0, 0), Style = "Skeleton", Material = "ForceField", Effects = { "Fire", "Aura", "Stars", "Halo" } },
}

Dragons.ById = {}
Dragons.ByRarity = {}
for index, dragon in ipairs(Dragons.List) do
	dragon.Order = index
	Dragons.ById[dragon.Id] = dragon
	Dragons.ByRarity[dragon.Rarity] = Dragons.ByRarity[dragon.Rarity] or {}
	table.insert(Dragons.ByRarity[dragon.Rarity], dragon)
	assert(Rarities.Get(dragon.Rarity), "Raridade inválida: " .. dragon.Rarity)
end

function Dragons.Get(id: string)
	return Dragons.ById[id]
end

-- Sorteia um dragão aleatório de uma raridade
function Dragons.RandomOfRarity(rarityId: string, rngArg: Random?)
	local rng = rngArg or Random.new()
	local list = Dragons.ByRarity[rarityId]
	if not list then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

-- Sorteia uma raridade usando o peso; luck multiplica as raridades Raro ou melhor.
function Dragons.RollRarity(luckArg: number?, rngArg: Random?): string
	local rng = rngArg or Random.new()
	local luck = luckArg or 1
	local total = 0
	local weights = {}
	for _, r in ipairs(Rarities.List) do
		local w = r.Weight
		if r.Order >= 3 then
			w *= luck
		end
		weights[r.Id] = w
		total += w
	end
	local roll = rng:NextNumber() * total
	for _, r in ipairs(Rarities.List) do
		roll -= weights[r.Id]
		if roll <= 0 then
			return r.Id
		end
	end
	return "Comum"
end

return Dragons
