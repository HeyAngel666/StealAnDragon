-- Raridades dos dragões, em ordem da mais comum para a mais rara.
-- Weight = chance relativa de aparecer na esteira.

local Rarities = {}

Rarities.List = {
	{ Id = "Comum", Name = "Comum", Color = Color3.fromRGB(200, 200, 200), Weight = 55, Scale = 1.0 },
	{ Id = "Incomum", Name = "Incomum", Color = Color3.fromRGB(90, 220, 90), Weight = 25, Scale = 1.08 },
	{ Id = "Raro", Name = "Raro", Color = Color3.fromRGB(70, 150, 255), Weight = 12, Scale = 1.16 },
	{ Id = "Epico", Name = "Épico", Color = Color3.fromRGB(180, 80, 255), Weight = 5.5, Scale = 1.25 },
	{ Id = "Lendario", Name = "Lendário", Color = Color3.fromRGB(255, 190, 40), Weight = 2, Scale = 1.35 },
	{ Id = "Mitico", Name = "Mítico", Color = Color3.fromRGB(255, 70, 90), Weight = 0.4, Scale = 1.45 },
	{ Id = "Divino", Name = "Divino", Color = Color3.fromRGB(255, 255, 140), Weight = 0.08, Scale = 1.55 },
	{ Id = "Secreto", Name = "Secreto", Color = Color3.fromRGB(20, 20, 20), Weight = 0.02, Scale = 1.65 },
}

Rarities.ById = {}
for index, rarity in ipairs(Rarities.List) do
	rarity.Order = index
	Rarities.ById[rarity.Id] = rarity
end

function Rarities.Get(id: string)
	return Rarities.ById[id]
end

return Rarities
