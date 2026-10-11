-- Envia ao cliente os dados que a interface precisa, e mantém o placar (leaderstats).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local Config = require(Shared.Config)

local StateService = {}
local dirty = {}

function StateService:MarkDirty(player: Player)
	dirty[player] = true
end

function StateService:MarkAllDirty()
	for _, player in ipairs(Players:GetPlayers()) do
		dirty[player] = true
	end
end

function StateService:SetupLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Dinheiro"
	cash.Value = "$0"
	cash.Parent = stats
	local steals = Instance.new("IntValue")
	steals.Name = "Roubos"
	steals.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player
end

function StateService:Build(player: Player)
	local S = self.Services
	local data = S.DataService:Get(player)
	if not data then
		return nil
	end
	local now = workspace:GetServerTimeNow()
	local base = S.BaseService:GetBaseOf(player)

	local passes = {}
	for key in pairs(S.MonetizationService:GetOwnedPasses(player)) do
		passes[key] = true
	end

	return {
		Cash = data.Cash,
		Rebirths = data.Rebirths,
		Steals = data.TotalSteals,
		Income = S.DragonService:GetIncomePerSecond(player),
		Multiplier = S.DragonService:GetMultiplier(player),
		Slots = S.BaseService:GetCapacity(player),
		UsedSlots = S.BaseService:CountDragons(player),
		Gear = data.Gear,
		Passes = passes,
		Index = data.Index,
		Settings = data.Settings,
		TutorialDone = data.TutorialDone,
		Playtime = S.RewardService:GetPlaytimeState(player),
		Daily = S.RewardService:GetDailyState(player),
		BaseIndex = base and base.Index or 0,
		LockedUntil = base and base.LockedUntil or 0,
		ShieldUntil = base and base.ShieldUntil or 0,
		IsAdmin = S.AdminService:IsAdmin(player),
		ServerTime = now,
		CanSave = S.DataService.Profiles[player] and S.DataService.Profiles[player].CanSave or false,
	}
end

function StateService:Push(player: Player)
	local state = self:Build(player)
	if state then
		Remotes.State:FireClient(player, state)
	end
	self:UpdateLeaderstats(player)
end

function StateService:UpdateLeaderstats(player: Player)
	local data = self.Services.DataService:Get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	stats.Dinheiro.Value = Format.Cash(data.Cash)
	stats.Roubos.Value = data.TotalSteals
	stats.Rebirths.Value = data.Rebirths
	player:SetAttribute("Rebirths", data.Rebirths)
end

function StateService:Start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in pairs(dirty) do
				dirty[player] = nil
				if player.Parent then
					self:Push(player)
				end
			end
		end
	end)
	-- atualização periódica (renda, timers)
	task.spawn(function()
		while true do
			task.wait(Config.IncomeTick)
			self:MarkAllDirty()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)
end

return StateService
