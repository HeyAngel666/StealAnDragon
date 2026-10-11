-- Bases dos jogadores: dono, espaços, trava (laser), escudo e placas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Format = require(Shared.Format)

local BaseService = {}
BaseService.Bases = {}
local baseOf = {} -- [player] = base

local function now()
	return workspace:GetServerTimeNow()
end

function BaseService:Init()
	local MapService = self.Services.MapService
	for i, cf in ipairs(Layout.Bases) do
		local model = MapService:GetBaseModel(i)
		local base = {
			Index = i,
			CFrame = cf,
			Model = model,
			Owner = nil,
			LockedUntil = 0,
			ShieldUntil = 0,
			ForcedOpenUntil = 0,
			Slots = {}, -- [slotIndex] = { Uid, Record, Model, Stealing }
			Reserved = {}, -- [slotIndex] = true (dragão voando para o espaço)
		}
		self.Bases[i] = base

		model.LockButton.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and player == base.Owner then
				self:Lock(base)
			end
		end)

		model.Barrier.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and player ~= base.Owner and self:IsLocked(base) then
				self:PushOut(base, player)
			end
		end)

		for _, slot in ipairs(model.Slots:GetChildren()) do
			local slotIndex = slot:GetAttribute("Index")
			slot.Collect.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player and player == base.Owner then
					self.Services.DragonService:Collect(player, slotIndex)
				end
			end)
		end
		self:RefreshVisuals(base)
	end
end

function BaseService:Assign(player: Player)
	for _, base in ipairs(self.Bases) do
		if not base.Owner then
			base.Owner = player
			base.Slots = {}
			base.Reserved = {}
			base.LockedUntil = now() + Config.JoinLockDuration
			base.ShieldUntil = 0
			base.ForcedOpenUntil = 0
			baseOf[player] = base
			base.Model:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("BaseIndex", base.Index)
			for _, text in ipairs(base.Model.Sign:GetDescendants()) do
				if text.Name == "OwnerText" then
					text.Text = "BASE DE " .. string.upper(player.DisplayName)
				end
			end
			player.RespawnLocation = base.Model.Spawn
			self:RefreshSlots(player)
			self:RefreshVisuals(base)
			return base
		end
	end
	return nil
end

function BaseService:Free(player: Player)
	local base = baseOf[player]
	if not base then
		return
	end
	baseOf[player] = nil
	base.Owner = nil
	base.Slots = {}
	base.Reserved = {}
	base.LockedUntil = 0
	base.ShieldUntil = 0
	base.Model:SetAttribute("OwnerUserId", nil)
	for _, text in ipairs(base.Model.Sign:GetDescendants()) do
		if text.Name == "OwnerText" then
			text.Text = "BASE LIVRE"
		end
	end
	self:RefreshSlotsFor(base, 0)
	self:RefreshVisuals(base)
end

function BaseService:GetBaseOf(player: Player)
	return baseOf[player]
end

function BaseService:GetBaseAt(position: Vector3)
	for _, base in ipairs(self.Bases) do
		if Layout.IsInsideBase(base.CFrame, position) then
			return base
		end
	end
	return nil
end

function BaseService:IsInOwnBase(player: Player): boolean
	local base = baseOf[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return base ~= nil and root ~= nil and Layout.IsInsideBase(base.CFrame, root.Position)
end

-- ============ Espaços ============

function BaseService:GetCapacity(player: Player): number
	local data = self.Services.DataService:Get(player)
	if not data then
		return Config.StartSlots
	end
	local slots = Config.StartSlots + data.Rebirths * Config.SlotsPerRebirth
	if self.Services.MonetizationService:HasPass(player, "ExtraSlots") then
		slots += Config.ExtraSlotsPass
	end
	return math.min(slots, Config.MaxSlots)
end

function BaseService:CountDragons(player: Player): number
	local base = baseOf[player]
	if not base then
		return 0
	end
	local n = 0
	for _ in pairs(base.Slots) do
		n += 1
	end
	for _ in pairs(base.Reserved) do
		n += 1
	end
	return n
end

function BaseService:FindFreeSlot(player: Player): number?
	local base = baseOf[player]
	if not base then
		return nil
	end
	local capacity = self:GetCapacity(player)
	for i = 1, capacity do
		if not base.Slots[i] and not base.Reserved[i] then
			return i
		end
	end
	return nil
end

function BaseService:RefreshSlots(player: Player)
	local base = baseOf[player]
	if base then
		self:RefreshSlotsFor(base, self:GetCapacity(player))
	end
end

function BaseService:RefreshSlotsFor(base, capacity: number)
	for _, slot in ipairs(base.Model.Slots:GetChildren()) do
		local i = slot:GetAttribute("Index")
		local unlocked = i <= capacity
		slot.Pedestal.Transparency = unlocked and 0 or 0.75
		slot.Pedestal.Color = unlocked and Color3.fromRGB(235, 235, 240) or Color3.fromRGB(90, 90, 95)
		slot.Collect.Transparency = unlocked and 0 or 1
		slot.Collect.CanTouch = unlocked
	end
end

-- ============ Trava ============

function BaseService:IsLocked(base): boolean
	local t = now()
	if t < base.ForcedOpenUntil then
		return false
	end
	return t < base.LockedUntil or t < base.ShieldUntil
end

function BaseService:Lock(base)
	if not base.Owner or self:IsLocked(base) or now() < base.ForcedOpenUntil then
		return
	end
	local data = self.Services.DataService:Get(base.Owner)
	local rebirths = data and data.Rebirths or 0
	base.LockedUntil = now() + Config.LockDuration + rebirths * Config.LockPerRebirth
	self.Services.ActionService:Effect(base.Owner, "Sound", { Name = "Lock" })
	self.Services.ActionService:Notify(base.Owner, "🔒 Base trancada!", "success")
	self:RefreshVisuals(base)
	self.Services.StateService:MarkDirty(base.Owner)
end

function BaseService:AddShield(player: Player, seconds: number)
	local base = baseOf[player]
	if not base then
		return
	end
	base.ShieldUntil = math.max(base.ShieldUntil, now()) + seconds
	self:RefreshVisuals(base)
end

function BaseService:ForceOpenAll(exceptPlayer: Player?, seconds: number)
	for _, base in ipairs(self.Bases) do
		if base.Owner and base.Owner ~= exceptPlayer then
			base.ForcedOpenUntil = now() + seconds
			self:RefreshVisuals(base)
		end
	end
end

function BaseService:PushOut(base, player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root then
		return
	end
	local entrance = base.CFrame * CFrame.new(0, 3, Layout.BaseSize / 2 + 6)
	local localPos = base.CFrame:PointToObjectSpace(root.Position)
	if localPos.Z < Layout.BaseSize / 2 - 2 then
		-- já está dentro: manda pra fora
		character:PivotTo(CFrame.new(entrance.Position))
	else
		local dir = (entrance.Position - base.CFrame.Position) * Vector3.new(1, 0, 1)
		self.Services.ActionService:Effect(player, "Knockback", { Velocity = dir.Unit * 60 + Vector3.new(0, 25, 0) })
	end
end

function BaseService:RefreshVisuals(base)
	local model = base.Model
	local locked = self:IsLocked(base)
	local t = now()
	model.Barrier.Transparency = locked and 0.35 or 1
	model.Barrier:SetAttribute("Locked", locked)
	model.Barrier:SetAttribute("OwnerUserId", base.Owner and base.Owner.UserId or 0)
	model:SetAttribute("Locked", locked)

	local lockText = model.LockButton.LockGui.Text
	local statusText = model.Sign.StatusGui.Text
	if not base.Owner then
		lockText.Text = ""
		statusText.Text = ""
		model.LockButton.Color = Color3.fromRGB(120, 120, 120)
		return
	end
	if t < base.ForcedOpenUntil then
		lockText.Text = "⚠️ BASES ABERTAS " .. math.ceil(base.ForcedOpenUntil - t) .. "s"
		statusText.Text = "🔓 ABERTA À FORÇA!"
		model.LockButton.Color = Color3.fromRGB(255, 150, 0)
	elseif locked then
		local remaining = math.max(base.LockedUntil, base.ShieldUntil) - t
		lockText.Text = "🔒 " .. Format.Time(remaining)
		statusText.Text = (t < base.ShieldUntil and "🛡️ " or "🔒 ") .. Format.Time(remaining)
		model.LockButton.Color = Color3.fromRGB(220, 60, 60)
	else
		lockText.Text = "🔓 PISE PARA TRANCAR"
		statusText.Text = ""
		model.LockButton.Color = Color3.fromRGB(60, 220, 90)
	end
end

function BaseService:Start()
	local wasLocked = {}
	while true do
		task.wait(0.5)
		for _, base in ipairs(self.Bases) do
			if base.Owner then
				local locked = self:IsLocked(base)
				if wasLocked[base] and not locked then
					self.Services.ActionService:Effect(base.Owner, "Sound", { Name = "Unlock" })
					self.Services.ActionService:Notify(base.Owner, "🔓 Sua base destrancou! Volte e tranque de novo.", "warning")
				end
				wasLocked[base] = locked
				self:RefreshVisuals(base)
			else
				wasLocked[base] = nil
			end
		end
	end
end

return BaseService
