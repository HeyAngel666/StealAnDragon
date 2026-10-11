-- Salva e carrega os dados dos jogadores (DataStore), com trava de sessão
-- para evitar perda/duplicação quando o jogador troca de servidor.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}
DataService.Profiles = {} -- [player] = { Data = {...}, CanSave = bool }

local SESSION_TIMEOUT = 300

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponível (ative 'Enable Studio Access to API Services'):", result)
	end
end

local function defaultData()
	return {
		Version = 1,
		Cash = Config.StartingCash,
		Rebirths = 0,
		TotalEarned = 0,
		TotalSteals = 0,
		Dragons = {}, -- [uid] = { Id, Mut, Slot, Stored }
		Gear = {}, -- [gearId] = true
		Index = {}, -- [dragonId] = true
		Codes = {}, -- [code] = true
		Purchases = {}, -- últimos PurchaseIds processados
		TestPasses = {}, -- gamepasses simulados no Studio
		DailyStreak = 0,
		LastDaily = 0,
		LastOnline = 0,
		TutorialDone = false,
		Settings = { Music = true, Sfx = true },
	}
end

local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			if type(v) == "table" then
				data[k] = table.clone(v)
			else
				data[k] = v
			end
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

function DataService:NewUid(): string
	return HttpService:GenerateGUID(false)
end

function DataService:Load(player: Player)
	local key = "Player_" .. player.UserId
	local data
	local canSave = store ~= nil

	if store then
		for attempt = 1, 6 do
			local locked = false
			local ok, err = pcall(function()
				store:UpdateAsync(key, function(old)
					old = old or defaultData()
					local session = old.Session
					local now = os.time()
					if session and session.JobId ~= game.JobId and now - (session.Time or 0) < SESSION_TIMEOUT and attempt < 6 then
						locked = true
						return nil
					end
					old.Session = { JobId = game.JobId, Time = now }
					data = old
					return old
				end)
			end)
			if ok and not locked and data then
				break
			end
			if not ok then
				warn("[DataService] Erro ao carregar", player.Name, err)
			end
			data = nil
			if not player.Parent then
				return nil
			end
			task.wait(locked and 5 or 2)
		end
		if not data then
			warn("[DataService] Não foi possível carregar os dados de", player.Name, "- usando dados temporários")
			canSave = false
		end
	end

	data = data or defaultData()
	reconcile(data, defaultData())

	local profile = { Data = data, CanSave = canSave }
	if not player.Parent then
		-- saiu enquanto carregava: libera a trava de sessão
		self.Profiles[player] = profile
		self:Release(player)
		return nil
	end
	self.Profiles[player] = profile
	return profile
end

function DataService:Get(player: Player)
	local profile = self.Profiles[player]
	return profile and profile.Data
end

function DataService:Save(player: Player, release: boolean?)
	local profile = self.Profiles[player]
	if not profile or not profile.CanSave or not store then
		return
	end
	local data = profile.Data
	data.LastOnline = os.time()
	local key = "Player_" .. player.UserId
	for _ = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				if old and old.Session and old.Session.JobId ~= game.JobId then
					-- outro servidor assumiu esses dados; não sobrescrever
					return nil
				end
				data.Session = (not release) and { JobId = game.JobId, Time = os.time() } or nil
				return data
			end)
		end)
		if ok then
			return
		end
		warn("[DataService] Erro ao salvar", player.Name, err)
		task.wait(1)
	end
end

function DataService:Release(player: Player)
	self:Save(player, true)
	self.Profiles[player] = nil
end

function DataService:Start()
	-- salvamento automático
	task.spawn(function()
		while true do
			task.wait(Config.AutoSaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				if self.Profiles[player] then
					task.spawn(self.Save, self, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if self.Profiles[player] then
				pending += 1
				task.spawn(function()
					self.Services.PlayerService:BeforeSave(player)
					self:Save(player, true)
					pending -= 1
				end)
			end
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
