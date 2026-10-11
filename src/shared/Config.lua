-- Configurações gerais do jogo "Roube um Dragão".
-- Altere os números aqui para balancear o jogo sem mexer no resto do código.

local Config = {}

Config.GameName = "Roube um Dragão"
Config.DataStoreName = "RoubeUmDragao_v1"

-- IDs de usuário que podem usar comandos de admin (/dinheiro, /evento...).
-- O dono do jogo (CreatorId) já tem acesso automaticamente.
Config.AdminUserIds = {}

-- Economia
Config.StartingCash = 100
Config.SellRefund = 0.5 -- vender devolve 50% do preço do dragão
Config.IncomeTick = 1 -- segundos entre cada pagamento dos dragões

-- Bases
Config.BaseCount = 8
Config.StartSlots = 6
Config.SlotsPerRebirth = 1
Config.ExtraSlotsPass = 4
Config.MaxSlots = 20

-- Trava da base
Config.LockDuration = 60
Config.LockPerRebirth = 5
Config.JoinLockDuration = 30

-- Roubo
Config.StealHoldTime = 1.2
Config.StealTimeout = 90 -- se não levar pra base nesse tempo, o dragão volta

-- Movimento
Config.WalkSpeed = 20
Config.CarrySpeed = 13
Config.SpeedPassBonus = 6
Config.SpeedCoilBonus = 10

-- Esteira (dragões passando no meio do mapa)
Config.ConveyorSpeed = 7 -- studs por segundo
Config.ConveyorSpawnInterval = 2.5
Config.ConveyorMaxDragons = 22

-- Renda offline
Config.OfflineCapSeconds = 60 * 60 -- 1 hora
Config.OfflineCapSecondsVIP = 3 * 60 * 60 -- 3 horas
Config.OfflineRate = 0.5 -- 50% da renda normal

-- Bônus de amigos no servidor
Config.FriendBoostPer = 0.10
Config.FriendBoostMax = 0.50

-- Bônus por completar raridades no Índice
Config.IndexBonusPerRarity = 0.05

-- Eventos automáticos
Config.EventInterval = 9 * 60
Config.EventDuration = 3 * 60

-- Salvamento
Config.AutoSaveInterval = 120

-- Presentes por tempo jogado (minutos desde que entrou)
-- Dinheiro é multiplicado por (1 + rebirths)^2 para continuar valendo a pena.
Config.PlaytimeRewards = {
	{ Minutes = 2, Kind = "Cash", Amount = 300 },
	{ Minutes = 5, Kind = "Cash", Amount = 1500 },
	{ Minutes = 10, Kind = "Cash", Amount = 6000 },
	{ Minutes = 15, Kind = "Dragon", Rarity = "Raro" },
	{ Minutes = 25, Kind = "Cash", Amount = 40000 },
	{ Minutes = 40, Kind = "Dragon", Rarity = "Epico" },
	{ Minutes = 60, Kind = "Dragon", Rarity = "Lendario" },
}

-- Recompensa diária (sequência de dias seguidos)
Config.DailyRewards = { 500, 1500, 4000, 10000, 25000, 60000, 150000 }

return Config
