-- Coisas do mundo no cliente: quais botões (E/F) aparecem, barreira de laser,
-- asas batendo, dragões arco-íris, iluminação dos eventos e a seta guia.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Layout)

local WorldController = {}
local player = Players.LocalPlayer

-- ============ Botões de roubar/vender ============

local function setupPrompt(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	local prompt = instance :: ProximityPrompt
	local kind = prompt:GetAttribute("PromptType")
	local owner = prompt:GetAttribute("OwnerUserId")
	if kind == "Steal" then
		prompt.Enabled = owner ~= player.UserId
	elseif kind == "Sell" then
		prompt.Enabled = owner == player.UserId
	end
end

-- ============ Barreiras ============

local function setupBarrier(barrier: BasePart)
	local function update()
		local locked = barrier:GetAttribute("Locked") == true
		local owner = barrier:GetAttribute("OwnerUserId")
		barrier.CanCollide = locked and owner ~= player.UserId
	end
	barrier:GetAttributeChangedSignal("Locked"):Connect(update)
	barrier:GetAttributeChangedSignal("OwnerUserId"):Connect(update)
	update()
end

-- ============ Animação dos dragões ============

local animated = {} -- [model] = { welds = {{weld, base, side}}, phase, rainbowParts, glitch }

local function registerDragon(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local info = { Welds = {}, Phase = math.random() * math.pi * 2, Colored = {} }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Weld") and d.Name == "WingJoint" then
			table.insert(info.Welds, { Weld = d, Base = d.C0, Side = d:GetAttribute("Side") or 1 })
		elseif d:IsA("BasePart") then
			local role = d:GetAttribute("Role")
			if role == "Body" or role == "Wing" or role == "Belly" then
				table.insert(info.Colored, d)
			end
		end
	end
	info.Rainbow = CollectionService:HasTag(model, "Rainbow")
	info.Glitch = CollectionService:HasTag(model, "Glitch")
	animated[model] = info
end

-- ============ Seta guia ============

function WorldController:PointTo(kind: string, value)
	self:ClearPointer()
	local target
	if kind == "Base" then
		local cf = Layout.Bases[value]
		if not cf then
			return
		end
		target = (cf * CFrame.new(0, 3, 0)).Position
	elseif kind == "Position" then
		target = value
	end
	if not target then
		return
	end
	local part = Instance.new("Part")
	part.Name = "GuideTarget"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = target
	part.Parent = workspace
	local a1 = Instance.new("Attachment")
	a1.Parent = part
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 80)
	gui.AlwaysOnTop = true
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	gui.Parent = part
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Text = "⬇️"
	arrow.TextScaled = true
	arrow.Parent = gui
	self.Pointer = part
	self:AttachBeam()
end

function WorldController:AttachBeam()
	if not self.Pointer then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local a0 = root:FindFirstChild("GuideAttachment") or Instance.new("Attachment")
	a0.Name = "GuideAttachment"
	a0.Parent = root
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = self.Pointer:FindFirstChildOfClass("Attachment")
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60))
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.3)
	beam.Segments = 1
	beam.Parent = self.Pointer
end

function WorldController:ClearPointer()
	if self.Pointer then
		self.Pointer:Destroy()
		self.Pointer = nil
	end
end

-- ============ Iluminação dos eventos ============

local EVENT_LOOK = {
	[""] = { ClockTime = 14.5, Tint = Color3.new(1, 1, 1), Saturation = 0 },
	ChuvaDeOuro = { ClockTime = 17.2, Tint = Color3.fromRGB(255, 235, 180), Saturation = 0.2 },
	NoiteDeLava = { ClockTime = 0.5, Tint = Color3.fromRGB(255, 170, 140), Saturation = 0.2 },
	HoraLendaria = { ClockTime = 19, Tint = Color3.fromRGB(230, 200, 255), Saturation = 0.25 },
	TempestadeArcoIris = { ClockTime = 12, Tint = Color3.fromRGB(255, 230, 255), Saturation = 0.6 },
	Frenesi = { ClockTime = 13, Tint = Color3.fromRGB(220, 255, 220), Saturation = 0.3 },
}

local function applyEventLook()
	local id = workspace:GetAttribute("EventId") or ""
	local look = EVENT_LOOK[id] or EVENT_LOOK[""]
	local cc = Lighting:FindFirstChild("EventColor")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "EventColor"
		cc.Parent = Lighting
	end
	TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = look.ClockTime }):Play()
	TweenService:Create(cc, TweenInfo.new(3), { TintColor = look.Tint, Saturation = look.Saturation }):Play()
end

-- ============ Início ============

function WorldController:Init(App)
	self.App = App
end

function WorldController:Start(App)
	local dragonsFolder = workspace:WaitForChild("Dragons")
	for _, d in ipairs(dragonsFolder:GetDescendants()) do
		setupPrompt(d)
	end
	dragonsFolder.DescendantAdded:Connect(setupPrompt)

	local map = workspace:WaitForChild("Map")
	local bases = map:WaitForChild("Bases")
	for _, base in ipairs(bases:GetChildren()) do
		setupBarrier(base:WaitForChild("Barrier"))
	end

	for _, model in ipairs(CollectionService:GetTagged("Dragon")) do
		registerDragon(model)
	end
	CollectionService:GetInstanceAddedSignal("Dragon"):Connect(function(model)
		task.defer(registerDragon, model)
	end)
	CollectionService:GetInstanceRemovedSignal("Dragon"):Connect(function(model)
		animated[model] = nil
	end)

	workspace:GetAttributeChangedSignal("EventId"):Connect(applyEventLook)
	applyEventLook()

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		self:AttachBeam()
	end)

	-- marcador "SUA BASE" visível de longe
	App.StateChanged.Event:Connect(function(state)
		if state.BaseIndex and state.BaseIndex > 0 and self.MarkedBase ~= state.BaseIndex then
			self.MarkedBase = state.BaseIndex
			if self.BaseMarker then
				self.BaseMarker:Destroy()
			end
			local base = bases:FindFirstChild("Base" .. state.BaseIndex)
			if base then
				local gui = Instance.new("BillboardGui")
				gui.Name = "MyBaseMarker"
				gui.Size = UDim2.fromOffset(180, 40)
				gui.StudsOffsetWorldSpace = Vector3.new(0, 16, 0)
				gui.AlwaysOnTop = true
				gui.MaxDistance = 1000
				gui.Adornee = base:WaitForChild("Sign")
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(1, 1)
				label.Font = Enum.Font.FredokaOne
				label.TextScaled = true
				label.TextColor3 = Color3.fromRGB(255, 230, 90)
				label.TextStrokeTransparency = 0
				label.Text = "🏠 SUA BASE"
				label.Parent = gui
				gui.Parent = App.Gui
				self.BaseMarker = gui
			end
		end
	end)

	-- animação (30x por segundo)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		acc = 0
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local camPos = camera and camera.CFrame.Position or Vector3.zero
		for model, info in pairs(animated) do
			if not model.Parent then
				animated[model] = nil
			else
				local root = model.PrimaryPart
				if root and (root.Position - camPos).Magnitude < 220 then
					local flap = math.sin(t * 5 + info.Phase) * 0.45
					for _, w in ipairs(info.Welds) do
						w.Weld.C0 = w.Base * CFrame.Angles(0, 0, w.Side * flap)
					end
					if info.Rainbow then
						local color = Color3.fromHSV((t * 0.25 + info.Phase) % 1, 0.8, 1)
						for _, p in ipairs(info.Colored) do
							p.Color = color
						end
					elseif info.Glitch and math.random() < 0.15 then
						local color = Color3.fromHSV(math.random(), 1, 1)
						for _, p in ipairs(info.Colored) do
							p.Color = color
						end
					end
				end
			end
		end
	end)
end

return WorldController
