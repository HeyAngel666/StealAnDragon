-- Constrói o mapa inteiro por código: chão, esteira, caverna, portal, 8 bases,
-- praça com lojas e rankings, decoração e iluminação.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Layout)
local DragonBuilder = require(Shared.DragonBuilder)

local MapService = {}

local FLOOR_TOP = 1

local BASE_COLORS = {
	Color3.fromRGB(220, 80, 80),
	Color3.fromRGB(80, 140, 230),
	Color3.fromRGB(90, 200, 110),
	Color3.fromRGB(240, 190, 60),
	Color3.fromRGB(170, 100, 230),
	Color3.fromRGB(240, 130, 50),
	Color3.fromRGB(70, 200, 210),
	Color3.fromRGB(240, 110, 180),
}

local rng = Random.new(1234)

local function P(props)
	local className = props.ClassName or "Part"
	local p = Instance.new(className)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "ClassName" and k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function label(parent: Instance, text: string, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Text = text
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	t.Parent = parent
	return t
end

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local t = label(gui, text, { TextColor3 = color or Color3.new(1, 1, 1) })
	return gui, t
end

-- ===================== Terreno e decoração =====================

local function buildTree(parent: Instance, pos: Vector3, scale: number)
	local trunkH = 8 * scale
	P({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(trunkH, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood, Parent = parent })
	local green = Color3.fromRGB(60 + rng:NextInteger(-10, 20), 150 + rng:NextInteger(-20, 20), 60)
	for i = 1, 3 do
		local d = (7 - i) * scale
		P({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d),
			Position = pos + Vector3.new(rng:NextNumber(-1, 1) * scale, trunkH + (i - 1) * 2.2 * scale, rng:NextNumber(-1, 1) * scale),
			Color = green, Material = Enum.Material.Grass, Parent = parent })
	end
end

local function buildRock(parent: Instance, pos: Vector3, size: number)
	P({ Name = "Rock", Size = Vector3.new(size, size * 0.7, size * 0.9), CFrame = CFrame.new(pos + Vector3.new(0, size * 0.25, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
		Color = Color3.fromRGB(120, 115, 110), Material = Enum.Material.Slate, Parent = parent })
end

local function buildMountain(parent: Instance, pos: Vector3, size: Vector3, color: Color3)
	local half = size.X / 2
	for _, side in ipairs({ -1, 1 }) do
		P({ ClassName = "WedgePart", Size = Vector3.new(size.Z, size.Y, half),
			CFrame = CFrame.new(pos + Vector3.new(side * half / 2, size.Y / 2, 0)) * CFrame.Angles(0, side * math.pi / 2, 0),
			Color = color, Material = Enum.Material.Rock, Parent = parent })
	end
end

local function buildVolcano(parent: Instance, pos: Vector3)
	local folder = Instance.new("Model")
	folder.Name = "Volcano"
	folder.Parent = parent
	for i = 0, 5 do
		local w = 140 - i * 22
		P({ Size = Vector3.new(w, 18, w), CFrame = CFrame.new(pos + Vector3.new(0, 9 + i * 18, 0)) * CFrame.Angles(0, i * 0.4, 0),
			Color = Color3.fromRGB(70 - i * 5, 55 - i * 4, 50 - i * 4), Material = Enum.Material.Basalt, Parent = folder })
	end
	local lava = P({ Size = Vector3.new(20, 2, 20), Position = pos + Vector3.new(0, 6 * 18 + 1, 0), Color = Color3.fromRGB(255, 90, 10),
		Material = Enum.Material.Neon, Parent = folder })
	local smoke = Instance.new("Smoke")
	smoke.Size = 30
	smoke.RiseVelocity = 12
	smoke.Opacity = 0.25
	smoke.Color = Color3.fromRGB(60, 60, 60)
	smoke.Parent = lava
	local fire = Instance.new("Fire")
	fire.Size = 25
	fire.Heat = 25
	fire.Parent = lava
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 120, 30)
	light.Parent = lava
end

local function buildLamp(parent: Instance, pos: Vector3)
	P({ Name = "LampPost", Size = Vector3.new(0.8, 12, 0.8), Position = pos + Vector3.new(0, 6, 0), Color = Color3.fromRGB(50, 45, 45), Material = Enum.Material.Metal, Parent = parent })
	local bulb = P({ Name = "LampBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = pos + Vector3.new(0, 12.6, 0), Color = Color3.fromRGB(255, 200, 120),
		Material = Enum.Material.Neon, Parent = parent })
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Parent = bulb
end

-- ===================== Esteira, caverna e portal =====================

local function buildConveyor(map: Instance)
	local folder = Instance.new("Model")
	folder.Name = "Conveyor"
	folder.Parent = map

	local startX, endX = Layout.ConveyorStart.X, Layout.ConveyorEnd.X
	local length = endX - startX
	local width = Layout.ConveyorWidth
	P({ Name = "Belt", Size = Vector3.new(length, 1, width), Position = Vector3.new((startX + endX) / 2, 0.5, 0),
		Color = Color3.fromRGB(150, 30, 30), Material = Enum.Material.Fabric, Parent = folder })
	for _, side in ipairs({ -1, 1 }) do
		P({ Name = "Edge", Size = Vector3.new(length, 1.3, 0.8), Position = Vector3.new((startX + endX) / 2, 0.65, side * (width / 2 + 0.4)),
			Color = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Neon, Parent = folder })
	end
	-- setas indicando a direção
	for x = startX + 10, endX - 10, 16 do
		local arrow = P({ ClassName = "WedgePart", Name = "Arrow", Size = Vector3.new(4, 0.15, 3), CanCollide = false,
			CFrame = CFrame.new(x, 1.08, 0) * CFrame.Angles(0, -math.pi / 2, 0), Color = Color3.fromRGB(255, 210, 120),
			Material = Enum.Material.Neon, Transparency = 0.3, Parent = folder })
		arrow.CastShadow = false
	end

	-- Caverna (onde os dragões nascem)
	local cave = Instance.new("Model")
	cave.Name = "Cave"
	cave.Parent = map
	local cx = startX - 8
	local rockColor = Color3.fromRGB(85, 75, 70)
	P({ Size = Vector3.new(26, 30, 12), Position = Vector3.new(cx - 6, 15, -19), Color = rockColor, Material = Enum.Material.Slate, Parent = cave })
	P({ Size = Vector3.new(26, 30, 12), Position = Vector3.new(cx - 6, 15, 19), Color = rockColor, Material = Enum.Material.Slate, Parent = cave })
	P({ Size = Vector3.new(26, 12, 50), Position = Vector3.new(cx - 6, 24, 0), Color = rockColor, Material = Enum.Material.Slate, Parent = cave })
	P({ Size = Vector3.new(4, 20, 30), Position = Vector3.new(cx - 18, 10, 0), Color = Color3.fromRGB(10, 5, 5), Material = Enum.Material.Slate, Parent = cave })
	local glow = P({ Size = Vector3.new(1, 16, 22), Position = Vector3.new(cx - 15, 9, 0), Color = Color3.fromRGB(255, 80, 20), Material = Enum.Material.Neon,
		Transparency = 0.5, CanCollide = false, Parent = cave })
	local caveLight = Instance.new("PointLight")
	caveLight.Range = 30
	caveLight.Color = Color3.fromRGB(255, 100, 40)
	caveLight.Brightness = 2
	caveLight.Parent = glow
	local sign = P({ Size = Vector3.new(30, 6, 1), Position = Vector3.new(cx + 7.5, 33, 0), Color = Color3.fromRGB(60, 35, 25), Material = Enum.Material.Wood,
		CFrame = CFrame.new(cx + 7.5, 33, 0) * CFrame.Angles(0, math.pi / 2, 0), Parent = cave })
	surfaceText(sign, Enum.NormalId.Back, "NINHO DOS DRAGÕES", Color3.fromRGB(255, 200, 80))
	surfaceText(sign, Enum.NormalId.Front, "NINHO DOS DRAGÕES", Color3.fromRGB(255, 200, 80))

	-- Portal (onde os dragões vão embora)
	local portal = Instance.new("Model")
	portal.Name = "Portal"
	portal.Parent = map
	local px = endX + 4
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		P({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Position = Vector3.new(px, 10 + math.sin(a) * 9, math.cos(a) * 9),
			Color = Color3.fromRGB(170, 80, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = portal })
	end
	local core = P({ Size = Vector3.new(0.5, 16, 16), Position = Vector3.new(px, 10, 0), Color = Color3.fromRGB(120, 40, 220), Material = Enum.Material.Neon,
		Transparency = 0.55, CanCollide = false, Parent = portal })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(200, 120, 255))
	pe.LightEmission = 1
	pe.Rate = 25
	pe.Speed = NumberRange.new(2, 5)
	pe.Lifetime = NumberRange.new(1, 2)
	pe.Parent = core
end

-- ===================== Bases =====================

local function buildBase(map: Instance, index: number, baseCF: CFrame)
	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model:SetAttribute("Index", index)
	model.Parent = map

	local color = BASE_COLORS[index]
	local wallColor = color:Lerp(Color3.new(0.2, 0.2, 0.2), 0.45)
	local half = Layout.BaseSize / 2
	local h = Layout.BaseWallHeight
	local function at(x, y, z)
		return baseCF * CFrame.new(x, y, z)
	end

	local floor = P({ Name = "Floor", Size = Vector3.new(Layout.BaseSize, 1, Layout.BaseSize), CFrame = at(0, 0.5, 0),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.55), Material = Enum.Material.WoodPlanks, Parent = model })
	floor:SetAttribute("BaseIndex", index)
	-- tapete do corredor central
	P({ Name = "Aisle", Size = Vector3.new(14, 0.1, Layout.BaseSize - 4), CFrame = at(0, FLOOR_TOP + 0.05, 0), Color = color,
		Material = Enum.Material.Fabric, CanCollide = false, Parent = model })

	-- paredes
	local wallT = 2
	P({ Name = "Wall", Size = Vector3.new(Layout.BaseSize, h, wallT), CFrame = at(0, FLOOR_TOP + h / 2, -half + wallT / 2), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		P({ Name = "Wall", Size = Vector3.new(wallT, h, Layout.BaseSize), CFrame = at(side * (half - wallT / 2), FLOOR_TOP + h / 2, 0), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
		local segW = half - Layout.EntranceWidth / 2
		P({ Name = "Wall", Size = Vector3.new(segW, h, wallT), CFrame = at(side * (Layout.EntranceWidth / 2 + segW / 2), FLOOR_TOP + h / 2, half - wallT / 2), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
		-- torres na frente
		P({ Name = "Tower", Size = Vector3.new(5, h + 6, 5), CFrame = at(side * (Layout.EntranceWidth / 2 + 2.5), FLOOR_TOP + (h + 6) / 2, half - 2), Color = wallColor:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.Brick, Parent = model })
		P({ Name = "TowerTop", ClassName = "WedgePart", Size = Vector3.new(5.5, 4, 5.5), CFrame = at(side * (Layout.EntranceWidth / 2 + 2.5), FLOOR_TOP + h + 8, half - 2), Color = color, Material = Enum.Material.SmoothPlastic, Parent = model })
	end
	-- ameias no topo da parede de trás
	for x = -half + 3, half - 3, 6 do
		P({ Name = "Merlon", Size = Vector3.new(3, 2, wallT), CFrame = at(x, FLOOR_TOP + h + 1, -half + wallT / 2), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
	end

	-- barreira de laser na entrada
	local barrier = P({ Name = "Barrier", Size = Vector3.new(Layout.EntranceWidth, h + 6, 0.6), CFrame = at(0, FLOOR_TOP + (h + 6) / 2, half - 1),
		Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.ForceField, Transparency = 1, CanCollide = false, Parent = model })
	barrier.CastShadow = false

	-- botão de trancar
	local lock = P({ Name = "LockButton", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6, 6), CFrame = at(Layout.LockButton.X, FLOOR_TOP + 0.3, Layout.LockButton.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(60, 220, 90), Material = Enum.Material.Neon, Parent = model })
	local lockGui = Instance.new("BillboardGui")
	lockGui.Name = "LockGui"
	lockGui.Size = UDim2.fromOffset(200, 60)
	lockGui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	lockGui.MaxDistance = 80
	lockGui.AlwaysOnTop = false
	lockGui.Parent = lock
	label(lockGui, "🔓 PISE PARA TRANCAR", { Name = "Text" })

	-- placa com o nome do dono
	local sign = P({ Name = "Sign", Size = Vector3.new(Layout.EntranceWidth + 10, 5, 1), CFrame = at(0, FLOOR_TOP + h + 3.5, half - 1), Color = Color3.fromRGB(45, 30, 25), Material = Enum.Material.Wood, Parent = model })
	local _, signFront = surfaceText(sign, Enum.NormalId.Back, "BASE LIVRE")
	signFront.Name = "OwnerText"
	local _, signBack = surfaceText(sign, Enum.NormalId.Front, "BASE LIVRE")
	signBack.Name = "OwnerText"

	-- placar acima da entrada (cadeado/timer)
	local statusGui = Instance.new("BillboardGui")
	statusGui.Name = "StatusGui"
	statusGui.Size = UDim2.fromOffset(260, 50)
	statusGui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	statusGui.MaxDistance = 200
	statusGui.Parent = sign
	label(statusGui, "", { Name = "Text", TextColor3 = Color3.fromRGB(255, 90, 90) })

	-- espaços (pedestais)
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = model
	for i, pos in ipairs(Layout.Slots) do
		local slot = Instance.new("Model")
		slot.Name = "Slot" .. i
		slot:SetAttribute("Index", i)
		slot.Parent = slots
		local pedestal = P({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 7, 7),
			CFrame = at(pos.X, FLOOR_TOP + 0.6, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(235, 235, 240), Material = Enum.Material.Marble, Parent = slot })
		slot.PrimaryPart = pedestal
		local towardAisle = pos.X < 0 and 1 or -1
		local collect = P({ Name = "Collect", Size = Vector3.new(2.6, 0.3, 4), CFrame = at(pos.X + towardAisle * 5, FLOOR_TOP + 0.15, pos.Z),
			Color = Color3.fromRGB(70, 230, 100), Material = Enum.Material.Neon, Parent = slot })
		collect:SetAttribute("SlotIndex", i)
		-- ponto onde o dragão fica, olhando para o corredor
		local standLocal = CFrame.lookAt(Vector3.new(pos.X, FLOOR_TOP + 1.2, pos.Z), Vector3.new(pos.X + towardAisle, FLOOR_TOP + 1.2, pos.Z))
		local stand = Instance.new("CFrameValue")
		stand.Name = "Stand"
		stand.Value = baseCF * standLocal
		stand.Parent = slot

		local info = Instance.new("BillboardGui")
		info.Name = "Info"
		info.Size = UDim2.fromOffset(220, 90)
		info.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		info.MaxDistance = 70
		info.Enabled = false
		info.Parent = collect
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = info
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = frame
		label(frame, "", { Name = "Mutation", LayoutOrder = 1, Size = UDim2.new(1, 0, 0.2, 0) })
		label(frame, "", { Name = "DragonName", LayoutOrder = 2, Size = UDim2.new(1, 0, 0.25, 0) })
		label(frame, "", { Name = "Rarity", LayoutOrder = 3, Size = UDim2.new(1, 0, 0.2, 0) })
		label(frame, "", { Name = "Income", LayoutOrder = 4, Size = UDim2.new(1, 0, 0.17, 0), TextColor3 = Color3.fromRGB(120, 255, 120) })
		label(frame, "", { Name = "Stored", LayoutOrder = 5, Size = UDim2.new(1, 0, 0.18, 0), TextColor3 = Color3.fromRGB(255, 230, 90) })
	end

	-- ponto de nascimento do dono
	local spawn = P({ ClassName = "SpawnLocation", Name = "Spawn", Size = Vector3.new(6, 0.2, 6), CFrame = at(Layout.SpawnPoint.X, FLOOR_TOP + 0.1, Layout.SpawnPoint.Z) * CFrame.Angles(0, math.pi, 0),
		Transparency = 1, CanCollide = false, Neutral = true, Duration = 0, Parent = model })
	spawn.CanTouch = false

	-- luz central
	local light = P({ Name = "BaseLight", Size = Vector3.new(1, 1, 1), CFrame = at(0, FLOOR_TOP + h - 1, -half + 3), Transparency = 1, CanCollide = false, Parent = model })
	local pl = Instance.new("PointLight")
	pl.Range = 40
	pl.Brightness = 0.8
	pl.Color = color
	pl.Parent = light

	return model
end

-- ===================== Praça (lojas e rankings) =====================

local function buildStall(parent: Instance, cf: CFrame, title: string, panel: string, color: Color3, dragonId: string)
	local stall = Instance.new("Model")
	stall.Name = "Stall_" .. panel
	stall.Parent = parent
	local counter = P({ Name = "Counter", Size = Vector3.new(14, 4, 4), CFrame = cf * CFrame.new(0, 2, 0), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.WoodPlanks, Parent = stall })
	for _, side in ipairs({ -1, 1 }) do
		P({ Size = Vector3.new(1, 12, 1), CFrame = cf * CFrame.new(side * 6.5, 6, 2), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood, Parent = stall })
		P({ Size = Vector3.new(1, 12, 1), CFrame = cf * CFrame.new(side * 6.5, 6, -4), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood, Parent = stall })
	end
	P({ ClassName = "WedgePart", Size = Vector3.new(16, 3, 9), CFrame = cf * CFrame.new(0, 13.5, -1), Color = color, Material = Enum.Material.Fabric, Parent = stall })
	local sign = P({ Name = "Sign", Size = Vector3.new(14, 3, 0.5), CFrame = cf * CFrame.new(0, 10, 2.3), Color = Color3.fromRGB(40, 25, 20), Material = Enum.Material.Wood, Parent = stall })
	surfaceText(sign, Enum.NormalId.Front, title, Color3.fromRGB(255, 220, 120))
	surfaceText(sign, Enum.NormalId.Back, title, Color3.fromRGB(255, 220, 120))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir"
	prompt.ObjectText = title
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenPanel", panel)
	prompt.Parent = counter

	-- dragão decorativo em cima do balcão
	local deco = DragonBuilder.Build(dragonId, "Normal", { Scale = 0.8 })
	deco:PivotTo(cf * CFrame.new(0, 4, -1) * CFrame.Angles(0, math.pi, 0))
	deco.Parent = stall
end

local function buildLeaderboard(parent: Instance, cf: CFrame, name: string, title: string)
	local board = P({ Name = name, Size = Vector3.new(16, 20, 1), CFrame = cf * CFrame.new(0, 12, 0), Color = Color3.fromRGB(35, 30, 45), Material = Enum.Material.SmoothPlastic, Parent = parent })
	for _, side in ipairs({ -1, 1 }) do
		P({ Size = Vector3.new(1, 22, 1), CFrame = cf * CFrame.new(side * 8.5, 11, 0), Color = Color3.fromRGB(255, 190, 60), Material = Enum.Material.Metal, Parent = parent })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	label(gui, title, { Name = "Title", Size = UDim2.new(1, 0, 0.12, 0), TextColor3 = Color3.fromRGB(255, 210, 80) })
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.04, 0.14)
	list.Size = UDim2.fromScale(0.92, 0.84)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for i = 1, 10 do
		label(list, i .. ". ---", { Name = "Row" .. i, LayoutOrder = i, Size = UDim2.new(1, 0, 0.1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	end
	return board
end

local function buildPlaza(map: Instance)
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	plaza.Parent = map
	local c = Layout.PlazaCenter
	P({ Name = "PlazaFloor", Size = Vector3.new(70, 0.4, 90), Position = c + Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(215, 205, 190), Material = Enum.Material.Marble, Parent = plaza })
	-- fonte no meio
	P({ Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 16, 16), CFrame = CFrame.new(c + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(180, 175, 170), Material = Enum.Material.Marble, Parent = plaza })
	local water = P({ Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 14, 14), CFrame = CFrame.new(c + Vector3.new(0, 2.05, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(60, 160, 255), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, Parent = plaza })
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(180, 230, 255))
	spray.Rate = 30
	spray.Speed = NumberRange.new(10, 14)
	spray.SpreadAngle = Vector2.new(12, 12)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Lifetime = NumberRange.new(0.8, 1.1)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = water
	local statue = DragonBuilder.Build("Bahamut", "Ouro", { Scale = 0.9, NoEffects = true })
	statue:PivotTo(CFrame.new(c + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, math.pi / 2, 0))
	statue.Parent = plaza

	-- a frente da barraca (+Z) fica virada para a fonte
	local function facingCenter(offset: Vector3)
		local pos = c + offset + Vector3.new(0, 0.4, 0)
		local center = c + Vector3.new(0, 0.4, 0)
		return CFrame.lookAt(pos, pos + (pos - center))
	end
	buildStall(plaza, facingCenter(Vector3.new(12, 0, -30)), "LOJA DE EQUIPAMENTOS", "Shop", Color3.fromRGB(220, 60, 60), "Wyvern")
	buildStall(plaza, facingCenter(Vector3.new(12, 0, 30)), "LOJA VIP", "Robux", Color3.fromRGB(255, 190, 40), "Celestial")
	buildStall(plaza, facingCenter(Vector3.new(-16, 0, -32)), "REBIRTH", "Rebirth", Color3.fromRGB(150, 70, 255), "Fenix")
	buildStall(plaza, facingCenter(Vector3.new(-16, 0, 32)), "ÍNDICE DE DRAGÕES", "Index", Color3.fromRGB(60, 170, 255), "Gelo")

	buildLeaderboard(plaza, CFrame.new(c + Vector3.new(30, 0.4, -14)) * CFrame.Angles(0, math.pi / 2, 0), "TopMoney", "💰 MAIS RICOS")
	buildLeaderboard(plaza, CFrame.new(c + Vector3.new(30, 0.4, 14)) * CFrame.Angles(0, math.pi / 2, 0), "TopSteals", "🐉 MAIS ROUBOS")
end

-- ===================== Iluminação =====================

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(255, 220, 200)
	atmosphere.Decay = Color3.fromRGB(150, 100, 120)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting

	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.Parent = Lighting
	end

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local cc = Lighting:FindFirstChild("BaseColor") or Instance.new("ColorCorrectionEffect")
	cc.Name = "BaseColor"
	cc.Saturation = 0.15
	cc.Contrast = 0.05
	cc.Parent = Lighting

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Parent = Lighting

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.5
	clouds.Parent = workspace.Terrain
end

-- ===================== Construção =====================

function MapService:Init()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	self.Map = map

	local env = Instance.new("Folder")
	env.Name = "Environment"
	env.Parent = map

	-- chão
	P({ Name = "Ground", Size = Vector3.new(760, 4, 560), Position = Vector3.new(20, -2, 0), Color = Color3.fromRGB(95, 165, 75), Material = Enum.Material.Grass, Parent = env })
	P({ Name = "Path", Size = Vector3.new(420, 0.1, 40), Position = Vector3.new(10, 0.05, 0), Color = Color3.fromRGB(170, 160, 145), Material = Enum.Material.Cobblestone, Parent = env })
	for _, z in ipairs({ -1, 1 }) do
		for x = -170, 170, 40 do
			buildLamp(env, Vector3.new(x, 0, z * 22))
		end
	end

	buildConveyor(map)

	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = map
	self.Bases = {}
	for i, cf in ipairs(Layout.Bases) do
		self.Bases[i] = buildBase(bases, i, cf)
	end

	buildPlaza(map)

	-- árvores e pedras em volta da área de jogo
	for _ = 1, 70 do
		local x = rng:NextNumber(-300, 330)
		local z = rng:NextNumber(-250, 250)
		local insidePlay = math.abs(z) < 112 and x > -215 and x < 275
		if not insidePlay then
			if rng:NextNumber() < 0.7 then
				buildTree(env, Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.6))
			else
				buildRock(env, Vector3.new(x, 0, z), rng:NextNumber(3, 8))
			end
		end
	end
	-- árvores entre as bases
	for _, x in ipairs({ -160, -80, 0, 80, 160 }) do
		for _, z in ipairs({ -72, 72 }) do
			buildTree(env, Vector3.new(x, 0, z), 1.1)
		end
	end

	-- montanhas ao redor e vulcão
	for i = 0, 11 do
		local x = -330 + i * 60
		buildMountain(env, Vector3.new(x, 0, -275), Vector3.new(90, rng:NextNumber(60, 110), 40), Color3.fromRGB(110, 100, 95))
		buildMountain(env, Vector3.new(x, 0, 275), Vector3.new(90, rng:NextNumber(60, 110), 40), Color3.fromRGB(110, 100, 95))
	end
	buildVolcano(env, Vector3.new(-40, 0, -420))

	-- paredes invisíveis (limite do mapa)
	local limits = Instance.new("Folder")
	limits.Name = "Limits"
	limits.Parent = map
	local function wall(size, pos)
		P({ Name = "Limit", Size = size, Position = pos, Transparency = 1, CanCollide = true, Parent = limits })
	end
	wall(Vector3.new(4, 200, 300), Vector3.new(-222, 100, 0))
	wall(Vector3.new(4, 200, 300), Vector3.new(268, 100, 0))
	wall(Vector3.new(500, 200, 4), Vector3.new(23, 100, -118))
	wall(Vector3.new(500, 200, 4), Vector3.new(23, 100, 118))

	setupLighting()
end

function MapService:GetBaseModel(index: number)
	return self.Bases[index]
end

return MapService
