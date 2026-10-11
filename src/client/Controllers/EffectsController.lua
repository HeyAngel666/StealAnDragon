-- Efeitos visuais vindos do servidor: dinheiro flutuando, empurrões, confete,
-- raios, tremor de câmera, aviso de meteoro, alerta de roubo, etc.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Gear = require(Shared.Gear)
local UI = require(script.Parent.UI)

local EffectsController = {}
local player = Players.LocalPlayer
local handlers = {}

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart"), character and character:FindFirstChildOfClass("Humanoid")
end

function handlers.Sound(self, data)
	self.App.Controllers.SoundController:Play(data.Name, data.Position)
end

function handlers.Collect(self, data)
	self.App.Controllers.SoundController:Play("Coin")
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = data.Position + Vector3.new(0, 3, 0)
	holder.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.AlwaysOnTop = true
	gui.Parent = holder
	local l = UI.label({ Text = "+" .. Format.Cash(data.Amount), Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(120, 255, 120), Parent = gui })
	TweenService:Create(holder, TweenInfo.new(1.2), { Position = holder.Position + Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
	Debris:AddItem(holder, 1.3)
	self.App.Controllers.TutorialController:OnEvent("Collected")
end

function handlers.Knockback(_, data)
	local root, humanoid = getRoot()
	if not root or not humanoid then
		return
	end
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = data.Velocity
	root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-4, 4), math.random(-8, 8))
	task.delay(data.Ragdoll or 0.6, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function handlers.Swing()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool then
		-- o script de animação padrão do Roblox toca o golpe com isso
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		Debris:AddItem(anim, 1)
	end
end

function handlers.Cooldown(self, data)
	local item = Gear.Get(data.Gear)
	if item then
		self.App.Controllers.HudController:SetCooldown(item.Name, data.Duration)
	end
end

function handlers.Confetti(self)
	local colors = { UI.Colors.Gold, UI.Colors.Red, UI.Colors.Green, UI.Colors.Blue, UI.Colors.Purple }
	for _ = 1, 70 do
		local piece = UI.new("Frame", {
			BackgroundColor3 = colors[math.random(1, #colors)],
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)),
			Position = UDim2.new(math.random(), 0, -0.05, 0),
			Rotation = math.random(0, 360),
			ZIndex = 30,
			Parent = self.App.Gui,
		})
		local duration = math.random(18, 30) / 10
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.1, 0),
			Rotation = piece.Rotation + math.random(-360, 360),
		}):Play()
		Debris:AddItem(piece, duration)
	end
end

function handlers.Beam(_, data)
	local from, to = data.From, data.To
	local dist = (to - from).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = data.Color or Color3.new(1, 1, 1)
	beam.Size = Vector3.new(0.5, 0.5, dist)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(0.1, 0.1, dist) }):Play()
	Debris:AddItem(beam, 0.45)
end

function handlers.Shake(_, data)
	local root = getRoot()
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return
	end
	local dist = (root.Position - data.Position).Magnitude
	local strength = (data.Strength or 1) * math.clamp(1 - dist / 80, 0, 1)
	if strength <= 0 then
		return
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 0.4 then
			conn:Disconnect()
			return
		end
		local s = strength * (1 - t / 0.4) * 0.6
		camera.CFrame = camera.CFrame * CFrame.new(math.random(-10, 10) / 10 * s, math.random(-10, 10) / 10 * s, 0)
	end)
end

function handlers.MeteorWarning(_, data)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 22, 22)
	ring.CFrame = CFrame.new(data.Position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Color = Color3.fromRGB(255, 40, 40)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.6
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(data.Time or 1.2), { Transparency = 0.2 }):Play()
	Debris:AddItem(ring, data.Time or 1.2)
end

function handlers.Frozen(self, data)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = Color3.fromRGB(170, 220, 255)
	cc.Parent = Lighting
	Debris:AddItem(cc, data.Duration or 3)
	self.App.Controllers.SoundController:Play("Freeze")
end

function handlers.StealAlert(self, data)
	local thief = Players:GetPlayerByUserId(data.Thief)
	if thief and thief.Character then
		local h = Instance.new("Highlight")
		h.FillColor = Color3.fromRGB(255, 40, 40)
		h.OutlineColor = Color3.fromRGB(255, 255, 255)
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = thief.Character
		Debris:AddItem(h, 10)
	end
	-- tela pisca vermelho
	local flash = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 0, 0), BackgroundTransparency = 0.6, Size = UDim2.fromScale(1, 1), ZIndex = 25, Parent = self.App.Gui })
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(flash, 0.8)
end

function handlers.CarryStart(self, data)
	self.App.Controllers.HudController:SetCarrying(true)
	self.App.Controllers.WorldController:PointTo("Base", data.BaseIndex)
end

function handlers.CarryEnd(self)
	self.App.Controllers.HudController:SetCarrying(false)
	self.App.Controllers.WorldController:ClearPointer()
end

function handlers.Tutorial(self, data)
	self.App.Controllers.TutorialController:OnEvent(data.Event)
end

function handlers.Offline(self, data)
	local frame = UI.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 250),
		ZIndex = 40,
		Parent = self.App.Gui,
	})
	UI.gradient(UI.Colors.PanelLight, UI.Colors.Panel).Parent = frame
	UI.label({ Text = "👋 BEM-VINDO DE VOLTA!", Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 10), TextColor3 = UI.Colors.Gold, Parent = frame })
	UI.label({ Text = "Seus dragões renderam enquanto você estava fora (" .. Format.Time(data.Seconds) .. "):", Size = UDim2.new(1, -30, 0, 50),
		Position = UDim2.fromOffset(15, 60), TextWrapped = true, MaxText = 20, Parent = frame })
	UI.label({ Text = "+" .. Format.Cash(data.Amount), Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 112), TextColor3 = Color3.fromRGB(120, 255, 120), MaxText = 44, Parent = frame })
	local state = self.App.State
	if state and not (state.Passes and state.Passes.VIP) then
		UI.label({ Text = "VIP guarda até 3 horas de renda offline!", Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 162), TextColor3 = UI.Colors.Gold, MaxText = 16, Parent = frame })
	end
	UI.button({ Text = "OBA!", Color = UI.Colors.Green, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(160, 46), Parent = frame }, function()
		frame:Destroy()
	end)
	UI.pop(frame)
	self.App.Controllers.SoundController:Play("Reward")
end

function EffectsController:Init(App)
	self.App = App
end

function EffectsController:Start(App)
	App.Remotes.Effect.OnClientEvent:Connect(function(name, data)
		local handler = handlers[name]
		if handler then
			handler(self, data or {})
		end
	end)
end

return EffectsController
