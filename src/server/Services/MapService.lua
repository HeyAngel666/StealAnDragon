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

local Terrain = workspace.Terrain

local function buildTree(parent: Instance, pos: Vector3, scale: number)
	local trunkH = 8 * scale
	P({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(trunkH, 1.8 * scale, 1.8 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood, Parent = parent })
	local hue = rng:NextNumber(0.24, 0.33)
	local top = pos + Vector3.new(0, trunkH, 0)
	-- copa arredondada com várias bolas
	local offsets = { Vector3.new(0, 1.5, 0), Vector3.new(2.2, 0, 0.6), Vector3.new(-2, 0.3, -0.8), Vector3.new(0.4, 0.2, 2.2), Vector3.new(-0.6, 0, -2.2), Vector3.new(0, 3.4, 0) }
	for i, o in ipairs(offsets) do
		local d = (i == #offsets and 4.5 or 6) * scale * rng:NextNumber(0.85, 1.1)
		P({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), Position = top + o * scale,
			Color = Color3.fromHSV(hue, 0.6, rng:NextNumber(0.55, 0.75)), Material = Enum.Material.Grass, Parent = parent })
	end
end

local FLOWER_COLORS = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 60), Color3.fromRGB(150, 110, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(90, 180, 255) }

local function buildFlowers(parent: Instance, center: Vector3, radius: number, count: number)
	for _ = 1, count do
		local pos = center + Vector3.new(rng:NextNumber(-radius, radius), 0, rng:NextNumber(-radius, radius))
		P({ Name = "Stem", Size = Vector3.new(0.2, 1, 0.2), Position = pos + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(60, 150, 60), CanCollide = false, Parent = parent })
		P({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Position = pos + Vector3.new(0, 1.1, 0),
			Color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = parent })
	end
end

local GRASS = Color3.fromRGB(95, 200, 70)

local function buildTerrain(parent: Instance)
	Terrain:Clear()
	-- chão verde liso, estilo clássico
	P({ Name = "Ground", Size = Vector3.new(1000, 4, 800), Position = Vector3.new(20, -2, 0), Color = GRASS, Material = Enum.Material.SmoothPlastic, Parent = parent })
	-- faixas de grama um pouco mais clara (efeito de gramado cortado)
	for i = -9, 9 do
		if i % 2 == 0 then
			P({ Name = "GrassStripe", Size = Vector3.new(1000, 0.05, 20), Position = Vector3.new(20, 0.025, i * 40), Color = GRASS:Lerp(Color3.new(1, 1, 1), 0.08),
				Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = parent })
		end
	end
end

-- ===================== Esteira, caverna e portal =====================

local function buildConveyor(map: Instance)
	local folder = Instance.new("Model")
	folder.Name = "Conveyor"
	folder.Parent = map

	local startX, endX = Layout.ConveyorStart.X, Layout.ConveyorEnd.X
	local length = endX - startX
	local width = Layout.ConveyorWidth
	-- tapete vermelho (onde os dragões andam)
	P({ Name = "Belt", Size = Vector3.new(length, 1, width), Position = Vector3.new((startX + endX) / 2, 0.5, 0),
		Color = Color3.fromRGB(205, 35, 35), Material = Enum.Material.SmoothPlastic, Parent = folder })
	P({ Name = "BeltCenter", Size = Vector3.new(length, 0.05, width - 4), Position = Vector3.new((startX + endX) / 2, 1.03, 0),
		Color = Color3.fromRGB(225, 50, 50), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = folder })
	for _, side in ipairs({ -1, 1 }) do
		P({ Name = "Edge", Size = Vector3.new(length, 1.4, 1), Position = Vector3.new((startX + endX) / 2, 0.7, side * (width / 2 + 0.5)),
			Color = Color3.fromRGB(245, 245, 245), Material = Enum.Material.SmoothPlastic, Parent = folder })
	end
	-- calçada cinza clara dos dois lados do tapete
	for _, side in ipairs({ -1, 1 }) do
		P({ Name = "Sidewalk", Size = Vector3.new(length + 60, 0.4, 10), Position = Vector3.new((startX + endX) / 2 + 20, 0.2, side * (width / 2 + 6)),
			Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.SmoothPlastic, Parent = folder })
	end

	-- Caverna (onde os dragões nascem)
	local cave = Instance.new("Model")
	cave.Name = "Cave"
	cave.Parent = map
	local cx = startX - 8
	local rockColor = Color3.fromRGB(150, 145, 140)
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

local BASE_RED = Color3.fromRGB(200, 40, 35)
local BASE_RED_DARK = Color3.fromRGB(160, 28, 25)
local TRIM = Color3.fromRGB(250, 250, 250)
local FLOOR_COLOR = Color3.fromRGB(235, 232, 225)

local function buildBase(map: Instance, index: number, baseCF: CFrame)
	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model:SetAttribute("Index", index)
	model.Parent = map

	local accent = BASE_COLORS[index]
	local half = Layout.BaseSize / 2
	local h = Layout.BaseWallHeight
	local up = Layout.UpperFloorY
	local stairsW = Layout.StairsWidth
	local function at(x, y, z)
		return baseCF * CFrame.new(x, y, z)
	end
	local function box(name, size, cf, color, extra)
		local props = { Name = name, Size = size, CFrame = cf, Color = color, Material = Enum.Material.SmoothPlastic, Parent = model }
		for k, v in pairs(extra or {}) do
			props[k] = v
		end
		return P(props)
	end

	-- piso do térreo
	local floor = box("Floor", Vector3.new(Layout.BaseSize, 1, Layout.BaseSize), at(0, 0.5, 0), FLOOR_COLOR)
	floor:SetAttribute("BaseIndex", index)
	box("Aisle", Vector3.new(14, 0.1, Layout.BaseSize - 6), at(0, FLOOR_TOP + 0.05, 0), BASE_RED, { CanCollide = false })

	-- paredes vermelhas (fundo e laterais, altura dos 2 andares)
	local wallT = 2
	local totalH = up + 1 + 9
	box("Wall", Vector3.new(Layout.BaseSize, totalH, wallT), at(0, FLOOR_TOP + totalH / 2, -half + wallT / 2), BASE_RED)
	for _, side in ipairs({ -1, 1 }) do
		box("Wall", Vector3.new(wallT, totalH, Layout.BaseSize), at(side * (half - wallT / 2), FLOOR_TOP + totalH / 2, 0), BASE_RED)
		local segW = half - Layout.EntranceWidth / 2
		if segW > 0.5 then
			box("Wall", Vector3.new(segW, h, wallT), at(side * (Layout.EntranceWidth / 2 + segW / 2), FLOOR_TOP + h / 2, half - wallT / 2), BASE_RED)
		end
	end

	-- faixas brancas horizontais (base, meio e topo) por fora
	for _, y in ipairs({ FLOOR_TOP + 0.75, FLOOR_TOP + up, FLOOR_TOP + totalH - 0.6 }) do
		box("Trim", Vector3.new(Layout.BaseSize + 0.6, 1.5, 0.6), at(0, y, -half - 0.1), TRIM)
		for _, side in ipairs({ -1, 1 }) do
			box("Trim", Vector3.new(0.6, 1.5, Layout.BaseSize + 0.6), at(side * (half + 0.1), y, 0), TRIM)
		end
		box("Trim", Vector3.new(Layout.BaseSize + 0.6, 1.5, 0.6), at(0, y, half + 0.1), TRIM)
	end
	-- colunas brancas nos cantos e ao lado da entrada
	for _, x in ipairs({ -half, half, -Layout.EntranceWidth / 2 - 0.6, Layout.EntranceWidth / 2 + 0.6 }) do
		box("Post", Vector3.new(1.4, totalH, 1.4), at(x, FLOOR_TOP + totalH / 2, half), TRIM)
	end
	for _, x in ipairs({ -half, half }) do
		box("Post", Vector3.new(1.4, totalH, 1.4), at(x, FLOOR_TOP + totalH / 2, -half), TRIM)
	end
	-- "prateleiras" brancas na parede de fundo (detalhe da casinha)
	for _, y in ipairs({ FLOOR_TOP + 6, FLOOR_TOP + up + 5 }) do
		box("Shelf", Vector3.new(Layout.BaseSize - 6, 0.6, 1.2), at(0, y, -half + wallT + 0.6), TRIM)
	end

	-- 2º andar (com buraco sobre a escada)
	local slabY = FLOOR_TOP + up - 0.5
	local inner = Layout.BaseSize - 2 * wallT
	local sideW = inner / 2 - stairsW / 2
	for _, side in ipairs({ -1, 1 }) do
		box("UpperFloor", Vector3.new(sideW, 1, inner), at(side * (stairsW / 2 + sideW / 2), slabY, 0), FLOOR_COLOR)
	end
	local holeBack, holeFront = -half + wallT + 2, -2
	box("UpperFloor", Vector3.new(stairsW, 1, 2), at(0, slabY, holeBack - 1), FLOOR_COLOR)
	box("UpperFloor", Vector3.new(stairsW, 1, half - wallT - holeFront), at(0, slabY, (holeFront + half - wallT) / 2), FLOOR_COLOR)
	-- borda branca do 2º andar na frente + vidro
	local railH = 8
	box("FloorEdge", Vector3.new(inner, 1.2, 1), at(0, slabY, half - wallT / 2), TRIM)
	box("GlassRail", Vector3.new(inner, railH, 0.4), at(0, slabY + 0.5 + railH / 2, half - wallT / 2), Color3.fromRGB(190, 235, 255),
		{ Material = Enum.Material.Glass, Transparency = 0.6 })
	box("RailTop", Vector3.new(inner, 0.6, 0.8), at(0, slabY + 0.5 + railH, half - wallT / 2), TRIM)
	for _, side in ipairs({ -1, 1 }) do
		box("StairRail", Vector3.new(0.3, 3, holeFront - holeBack), at(side * (stairsW / 2 + 0.2), slabY + 2, (holeBack + holeFront) / 2), Color3.fromRGB(190, 235, 255),
			{ Material = Enum.Material.Glass, Transparency = 0.5 })
	end
	-- teto
	box("Roof", Vector3.new(Layout.BaseSize + 1, 1, Layout.BaseSize + 1), at(0, FLOOR_TOP + totalH + 0.5, 0), BASE_RED_DARK)
	box("RoofTrim", Vector3.new(Layout.BaseSize + 2, 0.8, Layout.BaseSize + 2), at(0, FLOOR_TOP + totalH + 1.3, 0), TRIM)
	-- pilares
	for _, x in ipairs({ -stairsW / 2 - 1, stairsW / 2 + 1 }) do
		for _, z in ipairs({ 6, 20 }) do
			box("Pillar", Vector3.new(1.4, up - 1, 1.4), at(x, FLOOR_TOP + (up - 1) / 2, z), TRIM)
		end
	end
	-- escada (sobe para o fundo)
	local steps = 15
	local run = holeFront - holeBack
	for i = 1, steps do
		local depth = run / steps
		local z = holeFront - (i - 0.5) * depth
		local topY = FLOOR_TOP + i * (up / steps)
		box("Step", Vector3.new(stairsW, topY - FLOOR_TOP, depth), at(0, FLOOR_TOP + (topY - FLOOR_TOP) / 2, z), i % 2 == 0 and TRIM or FLOOR_COLOR)
	end

	-- barreira de laser na entrada
	local barrier = box("Barrier", Vector3.new(Layout.EntranceWidth, h, 0.6), at(0, FLOOR_TOP + h / 2, half - 1), Color3.fromRGB(255, 40, 40),
		{ Material = Enum.Material.ForceField, Transparency = 1, CanCollide = false })
	barrier.CastShadow = false
	for _, side in ipairs({ -1, 1 }) do
		box("LaserLight", Vector3.new(0.5, h - 1, 0.5), at(side * (Layout.EntranceWidth / 2 - 0.3), FLOOR_TOP + h / 2, half - 0.3), Color3.fromRGB(255, 60, 60),
			{ Material = Enum.Material.Neon, CanCollide = false })
	end

	-- botão de trancar
	local lock = P({ Name = "LockButton", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6, 6), CFrame = at(Layout.LockButton.X, FLOOR_TOP + 0.3, Layout.LockButton.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(60, 220, 90), Material = Enum.Material.Neon, Parent = model })
	P({ Name = "LockRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 7.4, 7.4), CFrame = at(Layout.LockButton.X, FLOOR_TOP + 0.2, Layout.LockButton.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = TRIM, Material = Enum.Material.SmoothPlastic, Parent = model })
	local lockGui = Instance.new("BillboardGui")
	lockGui.Name = "LockGui"
	lockGui.Size = UDim2.fromOffset(220, 60)
	lockGui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	lockGui.MaxDistance = 80
	lockGui.Parent = lock
	label(lockGui, "🔓 PISE PARA TRANCAR", { Name = "Text" })

	-- placa com o nome do dono em cima do telhado, virada para a esteira
	local signY = FLOOR_TOP + totalH + 5.5
	box("SignFrame", Vector3.new(Layout.BaseSize - 6, 8, 0.8), at(0, signY, half - 2), TRIM)
	local sign = box("Sign", Vector3.new(Layout.BaseSize - 8, 6, 0.6), at(0, signY, half - 1.5), BASE_RED)
	local _, signFront = surfaceText(sign, Enum.NormalId.Back, "BASE LIVRE")
	signFront.Name = "OwnerText"
	local _, signBack = surfaceText(sign, Enum.NormalId.Front, "BASE LIVRE")
	signBack.Name = "OwnerText"
	-- faixa colorida do jogador acima da entrada
	box("Accent", Vector3.new(Layout.EntranceWidth + 2, 1.2, 0.8), at(0, FLOOR_TOP + h - 0.2, half + 0.3), accent, { Material = Enum.Material.Neon })

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
		local y = FLOOR_TOP + pos.Y
		local pedestal = P({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 7.5, 7.5),
			CFrame = at(pos.X, y + 0.6, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = TRIM, Material = Enum.Material.SmoothPlastic, Parent = slot })
		P({ Name = "PedestalBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 8.6, 8.6),
			CFrame = at(pos.X, y + 0.25, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = BASE_RED, Material = Enum.Material.SmoothPlastic, Parent = slot })
		slot.PrimaryPart = pedestal
		local towardAisle = pos.X < 0 and 1 or -1
		local collect = P({ Name = "Collect", Size = Vector3.new(2.6, 0.3, 4.4), CFrame = at(pos.X + towardAisle * 6.2, y + 0.15, pos.Z),
			Color = Color3.fromRGB(70, 230, 100), Material = Enum.Material.Neon, Parent = slot })
		collect:SetAttribute("SlotIndex", i)
		local standLocal = CFrame.lookAt(Vector3.new(pos.X, y + 1.2, pos.Z), Vector3.new(pos.X + towardAisle, y + 1.2, pos.Z))
		local stand = Instance.new("CFrameValue")
		stand.Name = "Stand"
		stand.Value = baseCF * standLocal
		stand.Parent = slot

		local info = Instance.new("BillboardGui")
		info.Name = "Info"
		info.Size = UDim2.fromOffset(240, 100)
		info.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		info.MaxDistance = 70
		info.Enabled = false
		info.Parent = collect
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
		frame.BackgroundTransparency = 0.35
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = info
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Thickness = 2
		stroke.Color = accent
		stroke.Parent = frame
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 3)
		pad.PaddingBottom = UDim.new(0, 3)
		pad.Parent = frame
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = frame
		label(frame, "", { Name = "Mutation", LayoutOrder = 1, Size = UDim2.new(1, 0, 0.18, 0) })
		label(frame, "", { Name = "DragonName", LayoutOrder = 2, Size = UDim2.new(1, 0, 0.24, 0) })
		label(frame, "", { Name = "Rarity", LayoutOrder = 3, Size = UDim2.new(1, 0, 0.18, 0) })
		label(frame, "", { Name = "Income", LayoutOrder = 4, Size = UDim2.new(1, 0, 0.22, 0), TextColor3 = Color3.fromRGB(255, 240, 60) })
		label(frame, "", { Name = "Stored", LayoutOrder = 5, Size = UDim2.new(1, 0, 0.16, 0), TextColor3 = Color3.fromRGB(140, 255, 140) })
	end

	-- ponto de nascimento do dono
	local spawn = P({ ClassName = "SpawnLocation", Name = "Spawn", Size = Vector3.new(6, 0.2, 6), CFrame = at(Layout.SpawnPoint.X, FLOOR_TOP + 0.1, Layout.SpawnPoint.Z),
		Transparency = 1, CanCollide = false, Neutral = true, Duration = 0, Parent = model })
	spawn.CanTouch = false

	-- luzes internas
	for _, y in ipairs({ FLOOR_TOP + up - 2, FLOOR_TOP + up + 7 }) do
		local bulb = box("BaseLight", Vector3.new(1, 1, 1), at(0, y, 0), TRIM, { Transparency = 1, CanCollide = false })
		local pl = Instance.new("PointLight")
		pl.Range = 45
		pl.Brightness = 0.8
		pl.Color = Color3.fromRGB(255, 245, 230)
		pl.Parent = bulb
	end

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
	Lighting.Brightness = 3
	Lighting.ShadowSoftness = 0.35
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 220)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 150)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(255, 220, 200)
	atmosphere.Decay = Color3.fromRGB(150, 100, 120)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting

	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.Parent = Lighting
	end

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local cc = Lighting:FindFirstChild("BaseColor") or Instance.new("ColorCorrectionEffect")
	cc.Name = "BaseColor"
	cc.Saturation = 0.22
	cc.Contrast = 0.08
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

	-- chão de terreno (grama, rios, montanhas)
	buildTerrain(env)

	buildConveyor(map)

	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = map
	self.Bases = {}
	for i, cf in ipairs(Layout.Bases) do
		self.Bases[i] = buildBase(bases, i, cf)
	end

	buildPlaza(map)

	-- árvores, pinheiros, pedras e flores em volta da área de jogo
	for _ = 1, 140 do
		local x = rng:NextNumber(-330, 380)
		local z = rng:NextNumber(-215, 215)
		local insidePlay = math.abs(z) < 112 and x > -215 and x < 275
		if not insidePlay then
			local roll = rng:NextNumber()
			if roll < 0.75 then
				buildTree(env, Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.6))
			else
				buildFlowers(env, Vector3.new(x, 0, z), 5, 8)
			end
		end
	end
	-- árvores e flores entre as bases e nas calçadas
	for _, x in ipairs({ -160, -80, 0, 80, 160 }) do
		for _, z in ipairs({ -72, 72 }) do
			buildTree(env, Vector3.new(x, 0, z), 1.1)
			buildFlowers(env, Vector3.new(x, 0, z), 6, 10)
		end
	end
	for x = -180, 180, 45 do
		for _, z in ipairs({ -30, 30 }) do
			buildFlowers(env, Vector3.new(x + 20, 0, z), 4, 6)
		end
	end


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
