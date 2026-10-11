-- Comandos de admin (painel "Admin" na interface). Use para fazer eventos
-- ao vivo ("admin abuse"), que atraem muitos jogadores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Dragons = require(Shared.Dragons)
local Mutations = require(Shared.Mutations)

local AdminService = {}

local cache = {}

local function check(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		if ok and rank >= 255 then
			return true
		end
	end
	return table.find(Config.AdminUserIds, player.UserId) ~= nil
end

function AdminService:IsAdmin(player: Player): boolean
	if cache[player] == nil then
		cache[player] = check(player)
	end
	return cache[player]
end

function AdminService:Start()
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
end

function AdminService:Run(player: Player, command: string, arg1, arg2)
	if not self:IsAdmin(player) then
		return
	end
	local S = self.Services
	if command == "Event" then
		if arg1 == "Stop" then
			S.EventService:StopEvent()
		else
			S.EventService:StartEvent(tostring(arg1))
		end
	elseif command == "Cash" then
		local data = S.DataService:Get(player)
		local amount = tonumber(arg1)
		if data and amount then
			data.Cash += amount
		end
	elseif command == "SpawnDragon" then
		local id = tostring(arg1)
		local mut = Mutations.ById[tostring(arg2)] and tostring(arg2) or "Normal"
		if Dragons.Get(id) then
			S.ConveyorService:Spawn(id, mut)
		end
	elseif command == "ServerLuck" then
		S.EventService:AddServerLuck(600, player)
	elseif command == "Meteor" then
		S.EventService:MeteorShower(player)
	elseif command == "FreezeAll" then
		S.EventService:FreezeAll(player)
	elseif command == "UnlockAll" then
		S.EventService:UnlockAll(player)
	elseif command == "Announce" then
		local text = tostring(arg1 or ""):sub(1, 120)
		if #text > 0 then
			local ok, filtered = pcall(function()
				local TextService = game:GetService("TextService")
				return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
			end)
			if ok then
				S.ActionService:AlertAll("📢 " .. filtered, Color3.fromRGB(255, 255, 255))
			end
		end
	elseif command == "GiveAllDragon" then
		-- presente para todos no servidor
		local id = tostring(arg1)
		if Dragons.Get(id) then
			for _, p in ipairs(Players:GetPlayers()) do
				S.DragonService:Give(p, id, "Normal")
			end
			S.ActionService:AlertAll("🎁 O ADMIN deu " .. Dragons.Get(id).Name .. " para TODOS!", Color3.fromRGB(255, 220, 80))
		end
	end
	S.StateService:MarkDirty(player)
end

return AdminService
