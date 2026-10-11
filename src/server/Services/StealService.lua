-- Roubo: segurar E no dragão de outra base, carregar na cabeça e levar até a sua base.
-- Se levar um tapa, ficar preso ou morrer, o dragão volta para o dono.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Dragons = require(Shared.Dragons)
local DragonBuilder = require(Shared.DragonBuilder)

local StealService = {}
local carrying = {} -- [thief] = { Owner, Base, SlotIndex, Uid, Carry, Started }

function StealService:IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

local function ownerOfPrompt(prompt: ProximityPrompt)
	local userId = prompt:GetAttribute("OwnerUserId")
	return userId and Players:GetPlayerByUserId(userId)
end

function StealService:TryStart(thief: Player, prompt: ProximityPrompt)
	local S = self.Services
	local owner = ownerOfPrompt(prompt)
	if not owner or owner == thief then
		return
	end
	local model = prompt:FindFirstAncestorOfClass("Model")
	local uid = model and model:GetAttribute("Uid")
	if not uid then
		return
	end
	local entry, slotIndex, base = S.DragonService:FindEntryByUid(owner, uid)
	if not entry or entry.Stealing then
		return
	end
	local function fail(msg)
		S.ActionService:Notify(thief, msg, "error")
		S.ActionService:Effect(thief, "Sound", { Name = "Error" })
	end
	if carrying[thief] then
		return fail("Você já está carregando um dragão!")
	end
	if S.BaseService:IsLocked(base) then
		return fail("Essa base está trancada! 🔒")
	end
	if S.MovementService:IsFrozen(thief) then
		return
	end
	local thiefBase = S.BaseService:GetBaseOf(thief)
	if not thiefBase then
		return
	end
	local slot = S.BaseService:FindFreeSlot(thief)
	if not slot then
		return fail("Sua base está cheia! Venda um dragão primeiro.")
	end
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or not head then
		return
	end

	-- reserva o espaço do ladrão e marca o dragão como "sendo roubado"
	thiefBase.Reserved[slot] = true
	entry.Stealing = thief
	entry.Model.Parent = ServerStorage

	S.MovementService:ClearInvisible(thief)
	humanoid:UnequipTools()

	local carry = DragonBuilder.Build(entry.Record.Id, entry.Record.Mut, { Scale = 0.55, Anchored = false })
	carry.Name = "CarriedDragon"
	carry:PivotTo(head.CFrame * CFrame.new(0, 2.2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = carry.Root
	weld.Parent = carry.Root
	carry.Parent = character

	carrying[thief] = {
		Owner = owner,
		Base = base,
		SlotIndex = slotIndex,
		ReservedSlot = slot,
		Uid = uid,
		Carry = carry,
		Started = os.clock(),
	}
	thief:SetAttribute("Carrying", true)
	S.MovementService:Recompute(thief)
	S.DragonService:UpdateInfo(base, slotIndex)

	local def = Dragons.Get(entry.Record.Id)
	S.ActionService:Alert(owner, "⚠️ " .. thief.DisplayName .. " ESTÁ ROUBANDO SEU " .. string.upper(def.Name) .. "!", Color3.fromRGB(255, 60, 60))
	S.ActionService:Effect(owner, "Sound", { Name = "Alarm" })
	S.ActionService:Effect(owner, "StealAlert", { Thief = thief.UserId })
	S.ActionService:Notify(thief, "Leve o dragão até a SUA base!", "info")
	S.ActionService:Effect(thief, "Sound", { Name = "Steal" })
	S.ActionService:Effect(thief, "CarryStart", { BaseIndex = thiefBase.Index })
end

function StealService:Finish(thief: Player)
	local S = self.Services
	local c = carrying[thief]
	if not c then
		return
	end
	carrying[thief] = nil
	thief:SetAttribute("Carrying", nil)
	local thiefBase = S.BaseService:GetBaseOf(thief)
	if thiefBase then
		thiefBase.Reserved[c.ReservedSlot] = nil
	end
	if c.Carry then
		c.Carry:Destroy()
	end

	local record = S.DragonService:Remove(c.Owner, c.Uid)
	if record then
		local uid = S.DragonService:Give(thief, record.Id, record.Mut)
		if uid then
			local data = S.DataService:Get(thief)
			data.TotalSteals += 1
			local def = Dragons.Get(record.Id)
			S.ActionService:Alert(thief, "🐉 VOCÊ ROUBOU " .. string.upper(def.Name) .. "!", Color3.fromRGB(90, 255, 120))
			S.ActionService:Effect(thief, "Sound", { Name = "Roar" })
			S.ActionService:Effect(thief, "Confetti", {})
			S.ActionService:Notify(c.Owner, "😭 " .. thief.DisplayName .. " roubou seu " .. def.Name .. "!", "error")
			S.RewardService:OnTutorialEvent(thief, "Stole")
		end
	end
	S.MovementService:Recompute(thief)
	S.StateService:MarkDirty(thief)
	S.StateService:MarkDirty(c.Owner)
	S.ActionService:Effect(thief, "CarryEnd", {})
end

-- Cancela o roubo e devolve o dragão ao dono
function StealService:Interrupt(thief: Player, reason: string?)
	local S = self.Services
	local c = carrying[thief]
	if not c then
		return
	end
	carrying[thief] = nil
	thief:SetAttribute("Carrying", nil)
	local thiefBase = S.BaseService:GetBaseOf(thief)
	if thiefBase then
		thiefBase.Reserved[c.ReservedSlot] = nil
	end
	if c.Carry then
		c.Carry:Destroy()
	end
	local entry = c.Base.Slots[c.SlotIndex]
	if entry and entry.Uid == c.Uid then
		entry.Stealing = nil
		if entry.Model then
			entry.Model.Parent = workspace.Dragons
		end
		S.DragonService:UpdateInfo(c.Base, c.SlotIndex)
	end
	if thief.Parent then
		S.ActionService:Notify(thief, reason or "Você perdeu o dragão!", "error")
		S.ActionService:Effect(thief, "CarryEnd", {})
		S.MovementService:Recompute(thief)
		S.StateService:MarkDirty(thief)
	end
	if c.Owner.Parent then
		S.ActionService:Notify(c.Owner, "✅ Seu dragão voltou para a base!", "success")
		S.StateService:MarkDirty(c.Owner)
	end
end

-- Quando um jogador sai, cancela roubos dele e contra ele
function StealService:OnPlayerRemoving(player: Player)
	if carrying[player] then
		self:Interrupt(player, nil)
	end
	for thief, c in pairs(carrying) do
		if c.Owner == player then
			self:Interrupt(thief, "O dono saiu do jogo, o dragão sumiu!")
		end
	end
end

function StealService:Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local kind = prompt:GetAttribute("PromptType")
		if kind == "Steal" then
			self:TryStart(player, prompt)
		elseif kind == "Sell" then
			local owner = ownerOfPrompt(prompt)
			local model = prompt:FindFirstAncestorOfClass("Model")
			if owner == player and model then
				self.Services.DragonService:Sell(player, model:GetAttribute("Uid"))
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		for thief, c in pairs(carrying) do
			local character = thief.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or humanoid.Health <= 0 or not c.Carry.Parent then
				self:Interrupt(thief, "Você caiu e o dragão voltou!")
			elseif os.clock() - c.Started > Config.StealTimeout then
				self:Interrupt(thief, "Demorou demais! O dragão voltou.")
			else
				local base = self.Services.BaseService:GetBaseOf(thief)
				if base and Layout.IsInsideBase(base.CFrame, root.Position) then
					self:Finish(thief)
				end
			end
		end
	end)
end

return StealService
