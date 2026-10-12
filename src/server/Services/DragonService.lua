-- Dragões nas bases: colocar, render dinheiro, coletar, vender e transferir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Dragons = require(Shared.Dragons)
local Rarities = require(Shared.Rarities)
local Mutations = require(Shared.Mutations)
local Rebirths = require(Shared.Rebirths)
local Format = require(Shared.Format)
local DragonBuilder = require(Shared.DragonBuilder)
local RarityStyle = require(Shared.RarityStyle)

local DragonService = {}
local friendCache = {} -- [player] = { [userId] = bool }

-- ============ Valores ============

function DragonService:BaseIncome(record): number
	local def = Dragons.Get(record.Id)
	if not def then
		return 0
	end
	return def.Income * Mutations.Get(record.Mut).Multiplier
end

function DragonService:SellValue(record): number
	local def = Dragons.Get(record.Id)
	if not def then
		return 0
	end
	return math.floor(def.Price * Mutations.Get(record.Mut).Multiplier * Config.SellRefund)
end

function DragonService:GetFriendBoost(player: Player): number
	local cache = friendCache[player]
	if not cache then
		return 0
	end
	local count = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and cache[other.UserId] then
			count += 1
		end
	end
	return math.min(count * Config.FriendBoostPer, Config.FriendBoostMax)
end

function DragonService:GetIndexBonus(player: Player): number
	local data = self.Services.DataService:Get(player)
	if not data then
		return 0
	end
	local bonus = 0
	for _, rarity in ipairs(Rarities.List) do
		local list = Dragons.ByRarity[rarity.Id]
		local complete = list ~= nil
		for _, def in ipairs(list or {}) do
			if not data.Index[def.Id] then
				complete = false
				break
			end
		end
		if complete then
			bonus += Config.IndexBonusPerRarity
		end
	end
	return bonus
end

function DragonService:GetMultiplier(player: Player): number
	local S = self.Services
	local data = S.DataService:Get(player)
	if not data then
		return 1
	end
	local mult = Rebirths.MultiplierFor(data.Rebirths)
	if S.MonetizationService:HasPass(player, "DoubleCash") then
		mult *= 2
	end
	if S.MonetizationService:HasPass(player, "VIP") then
		mult *= 1.5
	end
	mult *= 1 + self:GetFriendBoost(player) + self:GetIndexBonus(player)
	mult *= S.EventService:GetCashMultiplier()
	return mult
end

function DragonService:GetIncomePerSecond(player: Player): number
	local base = self.Services.BaseService:GetBaseOf(player)
	if not base then
		return 0
	end
	local total = 0
	for _, entry in pairs(base.Slots) do
		if not entry.Stealing then
			total += self:BaseIncome(entry.Record)
		end
	end
	return total * self:GetMultiplier(player)
end

-- ============ Modelo no pedestal ============

local function makePrompt(parent: Instance, actionText: string, objectText: string, hold: number, key: Enum.KeyCode, kind: string, ownerId: number)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold
	prompt.KeyboardKeyCode = key
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PromptType", kind)
	prompt:SetAttribute("OwnerUserId", ownerId)
	prompt.Parent = parent
	return prompt
end

function DragonService:UpdateInfo(base, slotIndex: number)
	local slot = base.Model.Slots:FindFirstChild("Slot" .. slotIndex)
	if not slot then
		return
	end
	local info = slot.Collect.Info
	local entry = base.Slots[slotIndex]
	if not entry then
		info.Enabled = false
		return
	end
	local def = Dragons.Get(entry.Record.Id)
	local rarity = Rarities.Get(def.Rarity)
	local mutation = Mutations.Get(entry.Record.Mut)
	local frame = info.Frame
	info.Enabled = true
	frame.Mutation.Text = mutation.Id ~= "Normal" and mutation.Name or ""
	frame.Mutation.TextColor3 = mutation.Color or Color3.new(1, 1, 1)
	frame.DragonName.Text = def.Name
	frame.Rarity.Text = rarity.Name
	if frame.Rarity:GetAttribute("RarityId") ~= rarity.Id then
		frame.Rarity:SetAttribute("RarityId", rarity.Id)
		RarityStyle.Apply(frame.Rarity, rarity.Id)
		frame.Stroke.Color = rarity.Color
	end
	frame.Income.Text = Format.Cash(self:BaseIncome(entry.Record) * self:GetMultiplier(base.Owner)) .. "/s"
	if entry.Stealing then
		frame.Stored.Text = "⚠️ SENDO ROUBADO!"
	else
		frame.Stored.Text = "Coletar: " .. Format.Cash(entry.Record.Stored or 0)
	end
end

function DragonService:SpawnModel(player: Player, base, slotIndex: number, uid: string, record, flyFrom: CFrame?)
	local slot = base.Model.Slots["Slot" .. slotIndex]
	local stand = slot.Stand.Value
	local def = Dragons.Get(record.Id)
	local model = DragonBuilder.Build(record.Id, record.Mut)
	model.Name = uid
	model:SetAttribute("Uid", uid)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("SlotIndex", slotIndex)

	local attachment = model.Root.PromptAttachment
	local mutation = Mutations.Get(record.Mut)
	local title = (mutation.Id ~= "Normal" and (mutation.Name .. " ") or "") .. def.Name
	makePrompt(attachment, "Roubar", title, Config.StealHoldTime, Enum.KeyCode.E, "Steal", player.UserId)
	makePrompt(attachment, "Vender " .. Format.Cash(self:SellValue(record)), title, 1, Enum.KeyCode.F, "Sell", player.UserId)

	if flyFrom then
		model:PivotTo(flyFrom)
		model.Parent = workspace.Dragons
		-- voa em arco até o pedestal
		local startPos = flyFrom.Position
		local endPos = stand.Position
		local duration = 1.6
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not model.Parent then
				conn:Disconnect()
				return
			end
			local a = math.clamp((os.clock() - t0) / duration, 0, 1)
			local pos = startPos:Lerp(endPos, a) + Vector3.new(0, math.sin(a * math.pi) * 25, 0)
			local look = (endPos - startPos) * Vector3.new(1, 0, 1)
			local cf = look.Magnitude > 0.1 and CFrame.lookAt(pos, pos + look) or CFrame.new(pos)
			if a >= 1 then
				conn:Disconnect()
				model:PivotTo(stand)
			else
				model:PivotTo(cf)
			end
		end)
	else
		model:PivotTo(stand)
		model.Parent = workspace.Dragons
	end
	return model
end

-- Coloca um dragão (já salvo em data.Dragons) no espaço indicado
function DragonService:Place(player: Player, uid: string, record, flyFrom: CFrame?)
	local base = self.Services.BaseService:GetBaseOf(player)
	if not base then
		return
	end
	local slotIndex = record.Slot
	local entry = { Uid = uid, Record = record, Model = nil, Stealing = nil }
	base.Slots[slotIndex] = entry
	entry.Model = self:SpawnModel(player, base, slotIndex, uid, record, flyFrom)
	self:UpdateInfo(base, slotIndex)
end

-- Dá um dragão novo ao jogador. Retorna uid ou nil (base cheia)
function DragonService:Give(player: Player, dragonId: string, mutationId: string?, flyFrom: CFrame?)
	local S = self.Services
	local data = S.DataService:Get(player)
	local slotIndex = S.BaseService:FindFreeSlot(player)
	if not data or not slotIndex then
		return nil
	end
	local uid = S.DataService:NewUid()
	local record = { Id = dragonId, Mut = mutationId or "Normal", Slot = slotIndex, Stored = 0 }
	data.Dragons[uid] = record
	local isNew = not data.Index[dragonId]
	data.Index[dragonId] = true
	self:Place(player, uid, record, flyFrom)
	if isNew then
		local def = Dragons.Get(dragonId)
		S.ActionService:Notify(player, "📖 Novo dragão no Índice: " .. def.Name .. "!", "success")
	end
	local def = Dragons.Get(dragonId)
	if Rarities.Get(def.Rarity).Order >= 5 then
		local mutation = Mutations.Get(mutationId)
		S.ActionService:NotifyAll(string.format("🐉 %s conseguiu %s%s (%s)!", player.DisplayName,
			mutation.Id ~= "Normal" and (mutation.Name .. " ") or "", def.Name, Rarities.Get(def.Rarity).Name), "rare")
	end
	S.StateService:MarkDirty(player)
	return uid
end

function DragonService:Remove(player: Player, uid: string)
	local S = self.Services
	local data = S.DataService:Get(player)
	local base = S.BaseService:GetBaseOf(player)
	if not data or not base then
		return nil
	end
	local record = data.Dragons[uid]
	if not record then
		return nil
	end
	data.Dragons[uid] = nil
	local entry = base.Slots[record.Slot]
	if entry and entry.Uid == uid then
		if entry.Model then
			entry.Model:Destroy()
		end
		base.Slots[record.Slot] = nil
	end
	self:UpdateInfo(base, record.Slot)
	S.StateService:MarkDirty(player)
	return record
end

function DragonService:FindEntryByUid(player: Player, uid: string)
	local base = self.Services.BaseService:GetBaseOf(player)
	if not base then
		return nil
	end
	for slotIndex, entry in pairs(base.Slots) do
		if entry.Uid == uid then
			return entry, slotIndex, base
		end
	end
	return nil
end

-- ============ Ações ============

function DragonService:Collect(player: Player, slotIndex: number)
	local S = self.Services
	local base = S.BaseService:GetBaseOf(player)
	local data = S.DataService:Get(player)
	if not base or not data then
		return
	end
	local entry = base.Slots[slotIndex]
	if not entry or entry.Stealing then
		return
	end
	local amount = math.floor(entry.Record.Stored or 0)
	if amount <= 0 then
		return
	end
	entry.Record.Stored = 0
	data.Cash += amount
	self:UpdateInfo(base, slotIndex)
	local slot = base.Model.Slots["Slot" .. slotIndex]
	S.ActionService:Effect(player, "Collect", { Amount = amount, Position = slot.Collect.Position })
	S.StateService:MarkDirty(player)
end

function DragonService:CollectAll(player: Player)
	local base = self.Services.BaseService:GetBaseOf(player)
	if not base then
		return
	end
	for slotIndex in pairs(base.Slots) do
		self:Collect(player, slotIndex)
	end
end

function DragonService:Sell(player: Player, uid: string)
	local S = self.Services
	local entry = self:FindEntryByUid(player, uid)
	if not entry or entry.Stealing then
		return
	end
	local data = S.DataService:Get(player)
	local value = self:SellValue(entry.Record) + math.floor(entry.Record.Stored or 0)
	self:Remove(player, uid)
	data.Cash += value
	S.ActionService:Effect(player, "Sound", { Name = "Coin" })
	S.ActionService:Notify(player, "Vendido por " .. Format.Cash(value), "success")
	S.StateService:MarkDirty(player)
end

-- Carrega todos os dragões salvos ao entrar
function DragonService:LoadAll(player: Player)
	local S = self.Services
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	local used = {}
	local toFix = {}
	for uid, record in pairs(data.Dragons) do
		if not Dragons.Get(record.Id) then
			data.Dragons[uid] = nil
		elseif type(record.Slot) ~= "number" or record.Slot < 1 or record.Slot > Config.MaxSlots or used[record.Slot] then
			table.insert(toFix, uid)
		else
			used[record.Slot] = true
		end
	end
	for _, uid in ipairs(toFix) do
		local free
		for i = 1, Config.MaxSlots do
			if not used[i] then
				free = i
				break
			end
		end
		if free then
			used[free] = true
			data.Dragons[uid].Slot = free
		else
			data.Dragons[uid] = nil
		end
	end
	for uid, record in pairs(data.Dragons) do
		self:Place(player, uid, record)
	end
end

function DragonService:ClearModels(player: Player)
	local base = self.Services.BaseService:GetBaseOf(player)
	if not base then
		return
	end
	for slotIndex, entry in pairs(base.Slots) do
		if entry.Model then
			entry.Model:Destroy()
		end
		base.Slots[slotIndex] = nil
		self:UpdateInfo(base, slotIndex)
	end
end

function DragonService:OnPlayerAdded(player: Player)
	friendCache[player] = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			task.spawn(function()
				local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
				if ok and isFriend then
					friendCache[player][other.UserId] = true
					if friendCache[other] then
						friendCache[other][player.UserId] = true
					end
					self.Services.ActionService:Notify(player, "👥 Bônus de amigo! " .. other.DisplayName .. " está no servidor.", "success")
				end
			end)
		end
	end
end

function DragonService:Init()
	local folder = Instance.new("Folder")
	folder.Name = "Dragons"
	folder.Parent = workspace
end

function DragonService:Start()
	Players.PlayerRemoving:Connect(function(player)
		friendCache[player] = nil
	end)

	-- Loop de renda
	while true do
		task.wait(Config.IncomeTick)
		local S = self.Services
		for _, player in ipairs(Players:GetPlayers()) do
			local data = S.DataService:Get(player)
			local base = S.BaseService:GetBaseOf(player)
			if data and base then
				local mult = self:GetMultiplier(player)
				local auto = S.MonetizationService:HasPass(player, "AutoCollect")
				local earned = 0
				for slotIndex, entry in pairs(base.Slots) do
					if not entry.Stealing then
						local income = self:BaseIncome(entry.Record) * mult * Config.IncomeTick
						earned += income
						if auto then
							data.Cash += income
						else
							entry.Record.Stored = (entry.Record.Stored or 0) + income
						end
						self:UpdateInfo(base, slotIndex)
					end
				end
				data.TotalEarned += earned
			end
		end
	end
end

return DragonService
