-- Equipamentos: loja (dinheiro do jogo), criação das ferramentas e seus efeitos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Gear = require(Shared.Gear)
local Format = require(Shared.Format)

local GearService = {}
local cooldowns = {} -- [player] = { [gearId] = time }
local traps = {} -- [player] = { parts }

local function now()
	return workspace:GetServerTimeNow()
end

-- ============ Visual das ferramentas ============

local function makeHandle(item)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.Massless = true
	handle.Color = item.Color
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	local kind = item.Kind
	if kind == "Slap" then
		handle.Size = Vector3.new(1.4, 1.8, 0.6)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = handle
		if item.Id == "TapaBuracoNegro" then
			handle.Material = Enum.Material.Neon
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(Color3.fromRGB(150, 60, 255))
			e.LightEmission = 1
			e.Rate = 20
			e.Speed = NumberRange.new(0.5, 1)
			e.Lifetime = NumberRange.new(0.4, 0.8)
			e.Parent = handle
		elseif item.Id == "TapaEsmeralda" then
			handle.Material = Enum.Material.Glass
		elseif item.Id == "TapaFerro" then
			handle.Material = Enum.Material.Metal
		end
	elseif kind == "SpeedCoil" or kind == "GravityCoil" then
		handle.Shape = Enum.PartType.Cylinder
		handle.Size = Vector3.new(1.6, 0.9, 0.9)
		handle.Material = Enum.Material.Neon
	elseif kind == "Trap" then
		handle.Size = Vector3.new(1.6, 0.4, 1.6)
		handle.Material = Enum.Material.Metal
	elseif kind == "Freeze" then
		handle.Size = Vector3.new(0.5, 0.5, 2.2)
		handle.Material = Enum.Material.Neon
	elseif kind == "Invisible" then
		handle.Size = Vector3.new(1.6, 2, 0.2)
		handle.Material = Enum.Material.Fabric
		handle.Transparency = 0.3
	elseif kind == "Ban" then
		handle.Size = Vector3.new(0.5, 3.2, 0.5)
		handle.Material = Enum.Material.Wood
		local head = Instance.new("Part")
		head.Name = "HammerHead"
		head.Size = Vector3.new(2.2, 1.2, 1.2)
		head.Color = item.Color
		head.Material = Enum.Material.Neon
		head.CanCollide = false
		head.Massless = true
		head.CFrame = handle.CFrame * CFrame.new(0, 1.6, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = head
		weld.Parent = head
		head.Parent = handle
	else
		handle.Size = Vector3.new(1, 1, 1)
	end
	return handle
end

function GearService:CreateTool(item)
	local tool = Instance.new("Tool")
	tool.Name = item.Name
	tool.ToolTip = item.Description
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("GearId", item.Id)
	local handle = makeHandle(item)
	handle.Parent = tool
	if item.Kind == "Ban" then
		tool.GripPos = Vector3.new(0, -1, 0)
	end
	tool.Equipped:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if player then
			self:OnEquipped(player, item, true)
		end
	end)
	tool.Unequipped:Connect(function()
		local player = tool:FindFirstAncestorOfClass("Player")
		if player then
			self:OnEquipped(player, item, false)
		end
	end)
	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if player then
			self:Activate(player, item)
		end
	end)
	return tool
end

-- ============ Inventário ============

function GearService:OwnedGear(player: Player)
	local S = self.Services
	local data = S.DataService:Get(player)
	local owned = {}
	if not data then
		return owned
	end
	for _, item in ipairs(Gear.List) do
		if item.Pass then
			if S.MonetizationService:HasPass(player, item.Pass) then
				table.insert(owned, item)
			end
		elseif data.Gear[item.Id] then
			table.insert(owned, item)
		end
	end
	return owned
end

function GearService:GiveTools(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local have = {}
	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("GearId") then
					have[tool:GetAttribute("GearId")] = tool
				end
			end
		end
	end
	local ownedIds = {}
	for _, item in ipairs(self:OwnedGear(player)) do
		ownedIds[item.Id] = true
		if not have[item.Id] then
			self:CreateTool(item).Parent = backpack
		end
	end
	-- remove ferramentas que o jogador não tem mais (ex.: depois do rebirth)
	for id, tool in pairs(have) do
		if not ownedIds[id] then
			tool:Destroy()
		end
	end
end

function GearService:Buy(player: Player, gearId: string)
	local S = self.Services
	local item = Gear.Get(gearId)
	local data = S.DataService:Get(player)
	if not item or not data or item.Pass then
		return
	end
	if data.Gear[gearId] then
		return S.ActionService:Notify(player, "Você já tem esse item.", "info")
	end
	if data.Rebirths < item.Rebirth then
		return S.ActionService:Notify(player, "Precisa de Rebirth " .. item.Rebirth .. "!", "error")
	end
	if data.Cash < item.Price then
		S.ActionService:Effect(player, "Sound", { Name = "Error" })
		return S.ActionService:Notify(player, "Dinheiro insuficiente! Faltam " .. Format.Cash(item.Price - data.Cash), "error")
	end
	data.Cash -= item.Price
	data.Gear[gearId] = true
	self:GiveTools(player)
	S.ActionService:Effect(player, "Sound", { Name = "Buy" })
	S.ActionService:Notify(player, "Comprou " .. item.Name .. "! Está na sua mochila.", "success")
	S.StateService:MarkDirty(player)
end

-- ============ Efeitos ============

function GearService:OnEquipped(player: Player, item, equipped: boolean)
	local S = self.Services
	if equipped and S.StealService:IsCarrying(player) then
		task.defer(function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		end)
		S.ActionService:Notify(player, "Não dá pra usar itens carregando um dragão!", "error")
		return
	end
	if item.Kind == "SpeedCoil" or item.Kind == "GravityCoil" then
		S.MovementService:SetCoil(player, item.Kind, equipped)
	end
end

local function findTarget(player: Player, range: number, minDot: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestDist = nil, range
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then
			local oroot = other.Character:FindFirstChild("HumanoidRootPart")
			local ohum = other.Character:FindFirstChildOfClass("Humanoid")
			if oroot and ohum and ohum.Health > 0 then
				local offset = oroot.Position - root.Position
				local dist = offset.Magnitude
				if dist < bestDist then
					local dot = dist > 0.1 and root.CFrame.LookVector:Dot(offset.Unit) or 1
					if dot >= minDot then
						best, bestDist = other, dist
					end
				end
			end
		end
	end
	return best
end

function GearService:Activate(player: Player, item)
	local S = self.Services
	if S.StealService:IsCarrying(player) or S.MovementService:IsFrozen(player) then
		return
	end
	cooldowns[player] = cooldowns[player] or {}
	local t = now()
	if (cooldowns[player][item.Id] or 0) > t then
		return
	end
	if item.Cooldown and item.Cooldown > 0 then
		cooldowns[player][item.Id] = t + item.Cooldown
		S.ActionService:Effect(player, "Cooldown", { Gear = item.Id, Duration = item.Cooldown })
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	if item.Kind == "Slap" then
		S.ActionService:EffectAll("Sound", { Name = "Slap", Position = root.Position })
		S.ActionService:Effect(player, "Swing", {})
		local target = findTarget(player, item.Range, 0.2)
		if target then
			self:HitPlayer(player, target, root.CFrame.LookVector * item.Power + Vector3.new(0, item.Power * 0.45, 0), item.Stun)
		end
	elseif item.Kind == "Trap" then
		self:PlaceTrap(player, item, root.Position - Vector3.new(0, 2.8, 0))
	elseif item.Kind == "Freeze" then
		local target = findTarget(player, item.Range, 0.5)
		if target then
			local troot = target.Character.HumanoidRootPart
			S.ActionService:EffectAll("Beam", { From = root.Position, To = troot.Position, Color = item.Color })
			S.ActionService:EffectAll("Sound", { Name = "Freeze", Position = troot.Position })
			S.StealService:Interrupt(target, "Você foi congelado e soltou o dragão!")
			S.MovementService:Freeze(target, item.Duration, item.Visual)
		else
			S.ActionService:Notify(player, "Ninguém na mira!", "info")
			cooldowns[player][item.Id] = t + 1
		end
	elseif item.Kind == "Invisible" then
		S.MovementService:SetInvisible(player, item.Duration)
		S.ActionService:Notify(player, "👻 Você está invisível!", "info")
	elseif item.Kind == "Ban" then
		local target = findTarget(player, item.Range, 0.2)
		S.ActionService:EffectAll("Sound", { Name = "Slap", Position = root.Position })
		S.ActionService:Effect(player, "Swing", {})
		if target then
			S.StealService:Interrupt(target, "BANIDO! 🔨 O dragão voltou.")
			local tbase = S.BaseService:GetBaseOf(target)
			if tbase and target.Character then
				target.Character:PivotTo(tbase.Model.Spawn.CFrame + Vector3.new(0, 4, 0))
			end
			S.MovementService:Freeze(target, 1.5, nil)
			S.ActionService:Alert(target, "🔨 VOCÊ FOI BANIDO por " .. player.DisplayName .. "! (de volta pra base)", Color3.fromRGB(255, 80, 80))
			S.ActionService:NotifyAll("🔨 " .. player.DisplayName .. " baniu " .. target.DisplayName .. " com o Martelo do Banimento!", "rare")
		else
			cooldowns[player][item.Id] = t + 1
		end
	end
end

-- Empurra um jogador e faz ele soltar o dragão
function GearService:HitPlayer(attacker: Player?, target: Player, velocity: Vector3, stun: number?)
	local S = self.Services
	S.StealService:Interrupt(target, attacker and ("Você levou um tapa de " .. attacker.DisplayName .. "!") or "Você foi atingido!")
	S.ActionService:Effect(target, "Knockback", { Velocity = velocity, Ragdoll = (stun or 0) > 0 and stun or 0.6 })
	if stun and stun > 0 then
		S.MovementService:Freeze(target, stun, nil)
	end
end

function GearService:PlaceTrap(player: Player, item, position: Vector3)
	traps[player] = traps[player] or {}
	local list = traps[player]
	if #list >= 2 then
		local old = table.remove(list, 1)
		if old then
			old:Destroy()
		end
	end
	local trap = Instance.new("Part")
	trap.Name = "Trap"
	trap.Anchored = true
	trap.CanCollide = false
	trap.Size = Vector3.new(4, 0.4, 4)
	trap.Shape = Enum.PartType.Cylinder
	trap.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	trap.Size = Vector3.new(0.4, 4, 4)
	trap.Color = Color3.fromRGB(90, 90, 95)
	trap.Material = Enum.Material.DiamondPlate
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local tooth = Instance.new("WedgePart")
		tooth.Size = Vector3.new(0.3, 0.7, 0.5)
		tooth.Anchored = true
		tooth.CanCollide = false
		tooth.CanTouch = false
		tooth.Color = Color3.fromRGB(200, 200, 210)
		tooth.Material = Enum.Material.Metal
		tooth.CFrame = CFrame.new(position + Vector3.new(math.cos(a) * 1.6, 0.5, math.sin(a) * 1.6)) * CFrame.Angles(0, -a, 0)
		tooth.Parent = trap
	end
	trap.Parent = workspace
	table.insert(list, trap)
	local used = false
	trap.Touched:Connect(function(hit)
		if used then
			return
		end
		local victim = Players:GetPlayerFromCharacter(hit.Parent)
		if victim and victim ~= player then
			used = true
			local S = self.Services
			S.StealService:Interrupt(victim, "Você pisou numa armadilha!")
			S.MovementService:Freeze(victim, item.Duration, "Web")
			S.ActionService:EffectAll("Sound", { Name = "Freeze", Position = trap.Position })
			S.ActionService:Notify(player, "🪤 " .. victim.DisplayName .. " caiu na sua armadilha!", "success")
			trap:Destroy()
		end
	end)
	Debris:AddItem(trap, 60)
end

function GearService:Start()
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
		for _, trap in ipairs(traps[player] or {}) do
			trap:Destroy()
		end
		traps[player] = nil
	end)
end

return GearService
