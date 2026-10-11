-- Equipamentos (ferramentas).
-- Price = custo em dinheiro do jogo | Rebirth = rebirth mínimo para comprar
-- Pass = só vem com gamepass (Robux) | Cooldown em segundos

local Gear = {}

Gear.List = {
	{ Id = "Tapa", Name = "Tapa", Description = "Empurra quem estiver na sua frente e faz soltar o dragão.",
		Price = 500, Rebirth = 0, Cooldown = 2, Kind = "Slap", Power = 55, Range = 9, Color = Color3.fromRGB(255, 200, 160) },
	{ Id = "BobinaVelocidade", Name = "Bobina de Velocidade", Description = "Corre mais rápido enquanto segura.",
		Price = 1500, Rebirth = 0, Cooldown = 0, Kind = "SpeedCoil", Color = Color3.fromRGB(60, 160, 255) },
	{ Id = "Armadilha", Name = "Armadilha", Description = "Coloca uma armadilha que prende o ladrão por 4s.",
		Price = 3000, Rebirth = 0, Cooldown = 10, Kind = "Trap", Duration = 4, Color = Color3.fromRGB(120, 120, 120) },
	{ Id = "TapaFerro", Name = "Tapa de Ferro", Description = "Tapa mais forte que ainda atordoa por 1s.",
		Price = 25000, Rebirth = 1, Cooldown = 2, Kind = "Slap", Power = 85, Range = 10, Stun = 1, Color = Color3.fromRGB(160, 160, 170) },
	{ Id = "BobinaGravidade", Name = "Bobina de Gravidade", Description = "Pula muito mais alto enquanto segura.",
		Price = 100000, Rebirth = 2, Cooldown = 0, Kind = "GravityCoil", Color = Color3.fromRGB(170, 90, 255) },
	{ Id = "Teia", Name = "Lança-Teia", Description = "Prende o jogador mais próximo à sua frente por 3s.",
		Price = 500000, Rebirth = 3, Cooldown = 12, Kind = "Freeze", Range = 45, Duration = 3, Visual = "Web", Color = Color3.fromRGB(240, 240, 240) },
	{ Id = "Capa", Name = "Capa de Invisibilidade", Description = "Fica invisível e mais rápido por 8s.",
		Price = 2500000, Rebirth = 4, Cooldown = 30, Kind = "Invisible", Duration = 8, Color = Color3.fromRGB(80, 60, 120) },
	{ Id = "RaioCongelante", Name = "Raio Congelante", Description = "Congela o jogador mais próximo por 4s.",
		Price = 15000000, Rebirth = 6, Cooldown = 15, Kind = "Freeze", Range = 60, Duration = 4, Visual = "Ice", Color = Color3.fromRGB(120, 220, 255) },
	{ Id = "TapaEsmeralda", Name = "Tapa Esmeralda", Description = "Tapa gigante que arremessa longe.",
		Price = 100000000, Rebirth = 8, Cooldown = 2, Kind = "Slap", Power = 130, Range = 12, Stun = 1.5, Color = Color3.fromRGB(40, 220, 120) },

	-- Somente com Robux (gamepass)
	{ Id = "TapaBuracoNegro", Name = "Tapa Buraco Negro", Description = "Arremessa os inimigos para longe. (Gamepass)",
		Pass = "TapaBuracoNegro", Cooldown = 1.5, Kind = "Slap", Power = 170, Range = 13, Stun = 1.5, Color = Color3.fromRGB(20, 0, 40) },
	{ Id = "Martelo", Name = "Martelo do Banimento", Description = "\"Bane\" o alvo: manda ele de volta pra base dele. (Gamepass)",
		Pass = "Martelo", Cooldown = 20, Kind = "Ban", Range = 10, Color = Color3.fromRGB(255, 60, 60) },
}

Gear.ById = {}
for index, item in ipairs(Gear.List) do
	item.Order = index
	Gear.ById[item.Id] = item
end

function Gear.Get(id: string)
	return Gear.ById[id]
end

return Gear
