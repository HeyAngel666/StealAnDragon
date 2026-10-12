-- Controla velocidade/pulo dos jogadores juntando todos os efeitos
-- (carregando dragão, congelado, bobinas, passe de velocidade, capa).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MovementService = {}
local state = {} -- [player] = { FrozenUntil, SpeedCoil, GravityCoil, InvisibleUntil, IceBlock }

local function get(player)
	local s = state[player]
	if not s then
		s = { FrozenUntil = 0, InvisibleUntil = 0 }
		state[player] = s
	end
	return s
end

function MovementService:Recompute(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local s = get(player)
	local now = workspace:GetServerTimeNow()
	local S = self.Services

	local speed = Config.WalkSpeed
	local jump = 7.2
	if S.MonetizationService:HasPass(player, "Speed") then
		speed += Config.SpeedPassBonus
	end
	local carrying = S.StealService:IsCarrying(player)
	if carrying then
		speed = Config.CarrySpeed + (S.MonetizationService:HasPass(player, "Speed") and 2 or 0)
	else
		if s.SpeedCoil then
			speed += Config.SpeedCoilBonus
		end
		if s.GravityCoil then
			jump = 16
		end
		if now < s.InvisibleUntil then
			speed += 8
		end
	end
	if now < s.FrozenUntil then
		speed = 0
		jump = 0
	end
	humanoid.UseJumpPower = false
	humanoid.WalkSpeed = speed
	humanoid.JumpHeight = jump
end

function MovementService:SetCoil(player: Player, kind: string, active: boolean)
	local s = get(player)
	if kind == "SpeedCoil" then
		s.SpeedCoil = active
	elseif kind == "GravityCoil" then
		s.GravityCoil = active
	end
	self:Recompute(player)
end

function MovementService:IsFrozen(player: Player): boolean
	return workspace:GetServerTimeNow() < get(player).FrozenUntil
end

-- Congela/atordoa. visual = "Ice" | "Web" | nil
function MovementService:Freeze(player: Player, seconds: number, visual: string?)
	local s = get(player)
	local untilTime = workspace:GetServerTimeNow() + seconds
	s.FrozenUntil = math.max(s.FrozenUntil, untilTime)
	self:Recompute(player)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and visual then
		if s.IceBlock then
			s.IceBlock:Destroy()
		end
		local block = Instance.new("Part")
		block.Name = "FreezeVisual"
		block.Size = Vector3.new(5, 7, 5)
		block.CanCollide = false
		block.CanQuery = false
		block.CanTouch = false
		block.Massless = true
		block.CFrame = root.CFrame
		if visual == "Web" then
			block.Shape = Enum.PartType.Ball
			block.Size = Vector3.new(7, 7, 7)
			block.Material = Enum.Material.ForceField
			block.Color = Color3.fromRGB(255, 255, 255)
		else
			block.Material = Enum.Material.Ice
			block.Color = Color3.fromRGB(150, 220, 255)
			block.Transparency = 0.4
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = block
		weld.Parent = block
		block.Parent = character
		s.IceBlock = block
		task.delay(seconds, function()
			if s.IceBlock == block then
				block:Destroy()
				s.IceBlock = nil
			end
		end)
	end
	self.Services.ActionService:Effect(player, "Frozen", { Duration = seconds })
	task.delay(seconds + 0.05, function()
		if player.Parent then
			self:Recompute(player)
		end
	end)
end

function MovementService:SetInvisible(player: Player, seconds: number)
	local s = get(player)
	s.InvisibleUntil = workspace:GetServerTimeNow() + seconds
	local character = player.Character
	if not character then
		return
	end
	local saved = {}
	for _, d in ipairs(character:GetDescendants()) do
		if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
			saved[d] = d.Transparency
			d.Transparency = 1
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	s.InvisibleSaved = saved
	self:Recompute(player)
	task.delay(seconds, function()
		self:ClearInvisible(player)
	end)
end

function MovementService:ClearInvisible(player: Player)
	local s = get(player)
	s.InvisibleUntil = 0
	if s.InvisibleSaved then
		for inst, t in pairs(s.InvisibleSaved) do
			if inst.Parent then
				inst.Transparency = t
			end
		end
		s.InvisibleSaved = nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
	self:Recompute(player)
end

function MovementService:IsInvisible(player: Player): boolean
	return workspace:GetServerTimeNow() < get(player).InvisibleUntil
end

function MovementService:OnCharacter(player: Player)
	local s = get(player)
	s.FrozenUntil = 0
	s.InvisibleUntil = 0
	s.InvisibleSaved = nil
	s.SpeedCoil = false
	s.GravityCoil = false
	s.IceBlock = nil
	self:Recompute(player)
end

function MovementService:Start()
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)
end

return MovementService
