-- Rankings globais (todos os servidores): mais ricos e mais roubos.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local LeaderboardService = {}
local stores = {}
local nameCache = {}

local BOARDS = {
	{ Key = "TopMoney", Store = "TopEarned", Field = "TotalEarned", Prefix = "$" },
	{ Key = "TopSteals", Store = "TopSteals", Field = "TotalSteals", Prefix = "" },
}

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	name = ok and name or "???"
	nameCache[userId] = name
	return name
end

function LeaderboardService:Init()
	for _, b in ipairs(BOARDS) do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.DataStoreName .. "_" .. b.Store)
		if ok then
			stores[b.Key] = store
		end
	end
end

function LeaderboardService:SubmitPlayer(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	for _, b in ipairs(BOARDS) do
		local store = stores[b.Key]
		if store then
			-- OrderedDataStore só aceita inteiros; dinheiro guardado em "milhares" para caber
			local value = data[b.Field] or 0
			if b.Field == "TotalEarned" then
				value = math.floor(value / 1000)
			end
			task.spawn(pcall, store.SetAsync, store, "Player_" .. player.UserId, math.clamp(math.floor(value), 0, 2 ^ 52))
		end
	end
end

function LeaderboardService:Refresh()
	local plaza = workspace.Map:FindFirstChild("Plaza")
	if not plaza then
		return
	end
	for _, b in ipairs(BOARDS) do
		local store = stores[b.Key]
		local board = plaza:FindFirstChild(b.Key)
		if store and board then
			local ok, pages = pcall(store.GetSortedAsync, store, false, 10)
			if ok then
				local entries = pages:GetCurrentPage()
				local list = board.BoardGui.List
				for i = 1, 10 do
					local row = list:FindFirstChild("Row" .. i)
					local entry = entries[i]
					if entry then
						local userId = tonumber((entry.key:gsub("Player_", "")))
						local value = entry.value
						if b.Field == "TotalEarned" then
							value *= 1000
						end
						row.Text = string.format("%d. %s  -  %s%s", i, userId and getName(userId) or "?", b.Prefix, Format.Number(value))
					else
						row.Text = i .. ". ---"
					end
				end
			end
		end
	end
end

function LeaderboardService:Start()
	task.wait(10)
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			self:SubmitPlayer(player)
		end
		task.wait(5)
		self:Refresh()
		task.wait(175)
	end
end

return LeaderboardService
