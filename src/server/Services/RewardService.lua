-- Recompensas para quem joga de graça: presentes por tempo, prêmio diário,
-- renda offline, códigos e tutorial.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Dragons = require(Shared.Dragons)
local Format = require(Shared.Format)

local RewardService = {}

-- Códigos: CODIGO = recompensa. Adicione novos códigos aqui a cada atualização!
RewardService.Codes = {
	-- Lançamento (português)
	LANCAMENTO = { Cash = 5000 },
	DRAGAO = { Cash = 1500 },
	ROUBEUMDRAGAO = { Dragon = "Raro" },
	OBRIGADO = { Cash = 3000 },
	-- Lançamento (inglês)
	RELEASE = { Cash = 10000 },
	LAUNCH = { Cash = 5000 },
	STEALADRAGON = { Dragon = "Raro" },
	THANKYOU = { Cash = 3000 },
}

local joinTime = {} -- [player] = server time
local claimed = {} -- [player] = { [index] = true }

local function now()
	return workspace:GetServerTimeNow()
end

local function scale(data, amount: number): number
	return math.floor(amount * (1 + data.Rebirths) ^ 2)
end

-- ============ Presentes por tempo ============

function RewardService:GetPlaytimeState(player: Player)
	-- chaves em texto para enviar ao cliente sem problemas
	local list = {}
	for index in pairs(claimed[player] or {}) do
		list[tostring(index)] = true
	end
	return {
		JoinTime = joinTime[player] or now(),
		Claimed = list,
	}
end

function RewardService:ClaimPlaytime(player: Player, index: number)
	local S = self.Services
	local reward = Config.PlaytimeRewards[index]
	local data = S.DataService:Get(player)
	if not reward or not data or not joinTime[player] then
		return
	end
	claimed[player] = claimed[player] or {}
	if claimed[player][index] then
		return
	end
	if now() - joinTime[player] < reward.Minutes * 60 - 1 then
		return S.ActionService:Notify(player, "Ainda não está pronto!", "error")
	end
	if reward.Kind == "Cash" then
		local amount = scale(data, reward.Amount)
		data.Cash += amount
		S.ActionService:Alert(player, "🎁 Presente: +" .. Format.Cash(amount), Color3.fromRGB(120, 255, 120))
	elseif reward.Kind == "Dragon" then
		local def = Dragons.RandomOfRarity(reward.Rarity)
		if not S.DragonService:Give(player, def.Id, "Normal") then
			return S.ActionService:Notify(player, "Base cheia! Libere um espaço para pegar o presente.", "error")
		end
		S.ActionService:Alert(player, "🎁 Presente: " .. def.Name .. "!", Color3.fromRGB(255, 200, 60))
	end
	claimed[player][index] = true
	S.ActionService:Effect(player, "Sound", { Name = "Reward" })
	S.StateService:MarkDirty(player)
end

-- ============ Prêmio diário ============

function RewardService:GetDailyState(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return { CanClaim = false, Streak = 0, NextIn = 0 }
	end
	local elapsed = os.time() - data.LastDaily
	local canClaim = elapsed >= 20 * 3600
	return {
		CanClaim = canClaim,
		Streak = data.DailyStreak,
		NextIn = canClaim and 0 or (20 * 3600 - elapsed),
	}
end

function RewardService:ClaimDaily(player: Player)
	local S = self.Services
	local data = S.DataService:Get(player)
	local state = self:GetDailyState(player)
	if not data or not state.CanClaim then
		return
	end
	if os.time() - data.LastDaily > 48 * 3600 then
		data.DailyStreak = 0
	end
	local day = (data.DailyStreak % #Config.DailyRewards) + 1
	local amount = scale(data, Config.DailyRewards[day])
	data.DailyStreak += 1
	data.LastDaily = os.time()
	data.Cash += amount
	S.ActionService:Alert(player, "📅 Prêmio do dia " .. day .. ": +" .. Format.Cash(amount), Color3.fromRGB(120, 255, 120))
	S.ActionService:Effect(player, "Sound", { Name = "Reward" })
	S.StateService:MarkDirty(player)
	task.spawn(S.DataService.Save, S.DataService, player)
end

-- ============ Códigos ============

function RewardService:RedeemCode(player: Player, code: string)
	local S = self.Services
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	code = string.upper((code:gsub("%s+", "")))
	local reward = self.Codes[code]
	if not reward then
		S.ActionService:Effect(player, "Sound", { Name = "Error" })
		return S.ActionService:Notify(player, "Código inválido!", "error")
	end
	if data.Codes[code] then
		return S.ActionService:Notify(player, "Você já usou esse código.", "error")
	end
	if reward.Dragon then
		local def = Dragons.RandomOfRarity(reward.Dragon)
		if not S.DragonService:Give(player, def.Id, "Normal") then
			return S.ActionService:Notify(player, "Base cheia! Libere um espaço e tente de novo.", "error")
		end
		S.ActionService:Alert(player, "🎟️ Código resgatado: " .. def.Name .. "!", Color3.fromRGB(255, 200, 60))
	end
	if reward.Cash then
		local amount = scale(data, reward.Cash)
		data.Cash += amount
		S.ActionService:Alert(player, "🎟️ Código resgatado: +" .. Format.Cash(amount), Color3.fromRGB(120, 255, 120))
	end
	data.Codes[code] = true
	S.ActionService:Effect(player, "Sound", { Name = "Reward" })
	S.StateService:MarkDirty(player)
end

-- ============ Entrada / offline / tutorial ============

function RewardService:OnPlayerReady(player: Player)
	local S = self.Services
	joinTime[player] = now()
	claimed[player] = {}
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	-- renda offline
	if data.LastOnline > 0 then
		local cap = S.MonetizationService:HasPass(player, "VIP") and Config.OfflineCapSecondsVIP or Config.OfflineCapSeconds
		local seconds = math.clamp(os.time() - data.LastOnline, 0, cap)
		local income = S.DragonService:GetIncomePerSecond(player)
		local amount = math.floor(income * seconds * Config.OfflineRate)
		if amount > 0 and seconds > 60 then
			data.Cash += amount
			task.delay(4, function()
				if player.Parent then
					S.ActionService:Effect(player, "Offline", { Amount = amount, Seconds = seconds })
				end
			end)
		end
	end
	-- jogador novo: um dragãozinho de presente para começar
	if not data.TutorialDone and next(data.Dragons) == nil and data.Rebirths == 0 and data.TotalEarned == 0 then
		S.DragonService:Give(player, "Verdinho", "Normal")
	end
end

function RewardService:OnTutorialEvent(player: Player, event: string)
	self.Services.ActionService:Effect(player, "Tutorial", { Event = event })
end

function RewardService:Start()
	Players.PlayerRemoving:Connect(function(player)
		joinTime[player] = nil
		claimed[player] = nil
	end)
end

return RewardService
