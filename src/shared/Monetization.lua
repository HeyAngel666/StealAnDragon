-- ===================================================================
--  ITENS DE ROBUX
--  Depois de publicar, crie cada Gamepass e Produto no Creator Hub
--  (create.roblox.com) e COLE O ID no campo "Id" abaixo.
--  Enquanto o Id for 0, no Studio a compra é simulada (de graça) para teste,
--  e no jogo publicado o item aparece como "Em breve".
--  "Robux" é só o preço SUGERIDO para mostrar na loja; o preço real é
--  o que você definir no Creator Hub.
-- ===================================================================

local Monetization = {}

-- Gamepasses: compra única, vale para sempre
Monetization.Passes = {
	{ Key = "VIP", Id = 0, Robux = 399, Name = "VIP",
		Description = "+50% de dinheiro, tag VIP no chat e renda offline de 3h." },
	{ Key = "DoubleCash", Id = 0, Robux = 299, Name = "Dinheiro x2",
		Description = "Todos os seus dragões rendem o dobro. Para sempre!" },
	{ Key = "AutoCollect", Id = 0, Robux = 199, Name = "Coleta Automática",
		Description = "O dinheiro vai direto pro seu bolso, sem precisar coletar." },
	{ Key = "ExtraSlots", Id = 0, Robux = 249, Name = "+4 Espaços",
		Description = "Mais 4 espaços para dragões na sua base." },
	{ Key = "Speed", Id = 0, Robux = 149, Name = "Velocidade Extra",
		Description = "Corra mais rápido para roubar e fugir." },
	{ Key = "Luck", Id = 0, Robux = 349, Name = "Sorte de Mutação",
		Description = "30% de chance do dragão comprado subir de mutação (Ouro, Diamante, Arco-Íris)." },
	{ Key = "TapaBuracoNegro", Id = 0, Robux = 199, Name = "Tapa Buraco Negro",
		Description = "Equipamento exclusivo que arremessa os ladrões longe." },
	{ Key = "Martelo", Id = 0, Robux = 499, Name = "Martelo do Banimento",
		Description = "Bata em alguém e mande ele de volta pra base dele!" },
}

-- Produtos: podem ser comprados várias vezes
Monetization.Products = {
	-- Dinheiro (valor cresce com o seu rebirth)
	{ Key = "Cash1", Id = 0, Robux = 49, Name = "Saco de Dinheiro", Category = "Dinheiro",
		Kind = "Cash", Amount = 25000, Description = "Dinheiro instantâneo." },
	{ Key = "Cash2", Id = 0, Robux = 149, Name = "Baú de Dinheiro", Category = "Dinheiro",
		Kind = "Cash", Amount = 150000, Description = "Muito dinheiro instantâneo." },
	{ Key = "Cash3", Id = 0, Robux = 449, Name = "Cofre de Dinheiro", Category = "Dinheiro",
		Kind = "Cash", Amount = 750000, Description = "Uma montanha de dinheiro." },

	-- Dragões
	{ Key = "DragonLendario", Id = 0, Robux = 199, Name = "Dragão Lendário", Category = "Dragões",
		Kind = "Dragon", Rarity = "Lendario", Description = "Ganhe um dragão Lendário aleatório na sua base." },
	{ Key = "DragonMitico", Id = 0, Robux = 499, Name = "Dragão Mítico", Category = "Dragões",
		Kind = "Dragon", Rarity = "Mitico", Description = "Ganhe um dragão Mítico aleatório na sua base." },

	-- Proteção
	{ Key = "Shield", Id = 0, Robux = 99, Name = "Escudo 10 min", Category = "Proteção",
		Kind = "Shield", Seconds = 600, Description = "Sua base fica trancada por 10 minutos." },

	-- Servidor (afeta todo mundo!)
	{ Key = "ServerLuck", Id = 0, Robux = 149, Name = "Sorte do Servidor", Category = "Servidor",
		Kind = "ServerLuck", Seconds = 900, Description = "Sorte x3 na esteira por 15 min para TODOS." },
	{ Key = "Meteor", Id = 0, Robux = 99, Name = "Chuva de Meteoros", Category = "Trollar",
		Kind = "Meteor", Description = "Meteoros caem no mapa derrubando todo mundo (menos você)!" },
	{ Key = "FreezeAll", Id = 0, Robux = 129, Name = "Congelar Todos", Category = "Trollar",
		Kind = "FreezeAll", Description = "Congela todos os outros jogadores por 8 segundos." },
	{ Key = "UnlockAll", Id = 0, Robux = 199, Name = "Abrir Todas as Bases", Category = "Trollar",
		Kind = "UnlockAll", Description = "Destranca TODAS as bases (menos a sua) por 30 segundos!" },
}

Monetization.PassByKey = {}
Monetization.PassById = {}
for _, p in ipairs(Monetization.Passes) do
	Monetization.PassByKey[p.Key] = p
	if p.Id ~= 0 then
		Monetization.PassById[p.Id] = p
	end
end

Monetization.ProductByKey = {}
Monetization.ProductById = {}
for _, p in ipairs(Monetization.Products) do
	Monetization.ProductByKey[p.Key] = p
	if p.Id ~= 0 then
		Monetization.ProductById[p.Id] = p
	end
end

return Monetization
