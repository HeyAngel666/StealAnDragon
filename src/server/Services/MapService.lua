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

local function buildPine(parent: Instance, pos: Vector3, scale: number)
	P({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4 * scale, 1.4 * scale, 1.4 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, 2 * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(100, 70, 45), Material = Enum.Material.Wood, Parent = parent })
	local green = Color3.fromRGB(40, rng:NextInteger(110, 140), 70)
	for i = 0, 3 do
		local w = (9 - i * 2) * scale
		P({ Name = "PineLayer", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6 * scale, w, w),
			CFrame = CFrame.new(pos + Vector3.new(0, (4 + i * 2.6) * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = green, Material = Enum.Material.Grass, Parent = parent })
	end
end

local function buildRock(parent: Instance, pos: Vector3, size: number)
	for _ = 1, 3 do
		local s = size * rng:NextNumber(0.5, 1)
		P({ Name = "Rock", Size = Vector3.new(s, s * 0.7, s * 0.9),
			CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1) * size * 0.4, s * 0.25, rng:NextNumber(-1, 1) * size * 0.4))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
			Color = Color3.fromRGB(125, 120, 115), Material = Enum.Material.Slate, Parent = parent })
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

local function buildTerrain()
	Terrain:Clear()
	pcall(function()
		Terrain.Decoration = true -- grama animada
	end)
	Terrain.WaterColor = Color3.fromRGB(40, 150, 200)
	Terrain.WaterTransparency = 0.4
	Terrain.WaterWaveSize = 0.2
	-- chão de grama
	Terrain:FillBlock(CFrame.new(20, -8, 0), Vector3.new(840, 16, 680), Enum.Material.Grass)
	-- rios atrás das bases (além do limite do mapa) com areia nas margens
	for _, z in ipairs({ -142, 142 }) do
		Terrain:FillBlock(CFrame.new(20, -2, z), Vector3.new(840, 4, 36), Enum.Material.Sand)
		Terrain:FillBlock(CFrame.new(20, -4, z), Vector3.new(840, 8, 24), Enum.Material.Air)
		Terrain:FillBlock(CFrame.new(20, -5, z), Vector3.new(840, 6, 24), Enum.Material.Water)
	end
	-- montanhas com neve em volta
	for i = 0, 15 do
		local x = -360 + i * 50 + rng:NextNumber(-10, 10)
		for _, side in ipairs({ -1, 1 }) do
			local z = side * rng:NextNumber(230, 280)
			local r = rng:NextNumber(45, 75)
			Terrain:FillBall(Vector3.new(x, -10, z), r, Enum.Material.Rock)
			Terrain:FillBall(Vector3.new(x, r * 0.55, z), r * 0.45, Enum.Material.Snow)
			Terrain:FillBall(Vector3.new(x + rng:NextNumber(-40, 40), -14, side * rng:NextNumber(185, 205)), rng:NextNumber(20, 32), Enum.Material.Grass)
		end
	end
	for _, x in ipairs({ -420, 470 }) do
		for z = -260, 260, 70 do
			local r = rng:NextNumber(50, 80)
			Terrain:FillBall(Vector3.new(x, -10, z), r, Enum.Material.Rock)
			Terrain:FillBall(Vector3.new(x, r * 0.55, z), r * 0.45, Enum.Material.Snow)
		end
	end
end

local function buildVolcano(parent: Instance, pos: Vector3)
	Terrain:FillBall(pos + Vector3.new(0, -30, 0), 110, Enum.Material.Basalt)
	Terrain:FillBall(pos + Vector3.new(0, 40, 0), 60, Enum.Material.Basalt)
	Terrain:FillBall(pos + Vector3.new(0, 95, 0), 24, Enum.Material.CrackedLava)
	local lava = P({ Name = "VolcanoLava", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 30, 30),
		CFrame = CFrame.new(pos + Vector3.new(0, 112, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 100, 20), Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	local smoke = Instance.new("Smoke")
	smoke.Size = 40
	smoke.RiseVelocity = 14
	smoke.Opacity = 0.25
	smoke.Color = Color3.fromRGB(70, 60, 60)
	smoke.Parent = lava
	local fire = Instance.new("Fire")
	fire.Size = 30
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

	-- arcos decorativos sobre a esteira
	for x = startX + 40, endX - 30, 60 do
		for _, side in ipairs({ -1, 1 }) do
			P({ Name = "ArchPillar", Size = Vector3.new(2, 16, 2), Position = Vector3.new(x, 8, side * (width / 2 + 3)),
				Color = Color3.fromRGB(70, 45, 35), Material = Enum.Material.Wood, Parent = folder })
			local torch = P({ Name = "Torch", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Position = Vector3.new(x, 16.8, side * (width / 2 + 3)),
				Color = Color3.fromRGB(255, 160, 40), Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
			local fire = Instance.new("Fire")
			fire.Size = 3
			fire.Heat = 6
			fire.Parent = torch
		end
		local beam = P({ Name = "ArchBeam", Size = Vector3.new(2.5, 2.5, width + 9), Position = Vector3.new(x, 15, 0),
			Color = Color3.fromRGB(150, 30, 30), Material = Enum.Material.Wood, Parent = folder })
		surfaceText(beam, Enum.NormalId.Left, "🐉", Color3.fromRGB(255, 220, 120))
		surfaceText(beam, Enum.NormalId.Right, "🐉", Color3.fromRGB(255, 220, 120))
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
	local wallColor = color:Lerp(Color3.new(0.25, 0.22, 0.2), 0.5)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.6)
	local half = Layout.BaseSize / 2
	local h = Layout.BaseWallHeight
	local up = Layout.UpperFloorY
	local stairsW = Layout.StairsWidth
	local function at(x, y, z)
		return baseCF * CFrame.new(x, y, z)
	end

	-- térreo
	local floor = P({ Name = "Floor", Size = Vector3.new(Layout.BaseSize, 1, Layout.BaseSize), CFrame = at(0, 0.5, 0),
		Color = light, Material = Enum.Material.WoodPlanks, Parent = model })
	floor:SetAttribute("BaseIndex", index)
	P({ Name = "Aisle", Size = Vector3.new(16, 0.1, Layout.BaseSize - 4), CFrame = at(0, FLOOR_TOP + 0.05, 0), Color = color,
		Material = Enum.Material.Fabric, CanCollide = false, Parent = model })
	-- faixas de luz nas bordas do piso
	for _, side in ipairs({ -1, 1 }) do
		P({ Name = "Trim", Size = Vector3.new(0.4, 0.2, Layout.BaseSize - 4), CFrame = at(side * (half - 2.4), FLOOR_TOP + 0.1, 0),
			Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = model })
	end

	-- paredes (térreo + 2º andar)
	local wallT = 2
	local totalH = h + 1 + 8
	P({ Name = "Wall", Size = Vector3.new(Layout.BaseSize, totalH, wallT), CFrame = at(0, FLOOR_TOP + totalH / 2, -half + wallT / 2), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		P({ Name = "Wall", Size = Vector3.new(wallT, totalH, Layout.BaseSize), CFrame = at(side * (half - wallT / 2), FLOOR_TOP + totalH / 2, 0), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
		local segW = half - Layout.EntranceWidth / 2
		P({ Name = "Wall", Size = Vector3.new(segW, h, wallT), CFrame = at(side * (Layout.EntranceWidth / 2 + segW / 2), FLOOR_TOP + h / 2, half - wallT / 2), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
	end
	-- ameias no topo
	for x = -half + 3, half - 3, 6 do
		P({ Name = "Merlon", Size = Vector3.new(3, 2, wallT), CFrame = at(x, FLOOR_TOP + totalH + 1, -half + wallT / 2), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
	end
	for z = -half + 3, half - 3, 6 do
		for _, side in ipairs({ -1, 1 }) do
			P({ Name = "Merlon", Size = Vector3.new(wallT, 2, 3), CFrame = at(side * (half - wallT / 2), FLOOR_TOP + totalH + 1, z), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
		end
	end
	-- torres nos cantos com telhado em camadas e bandeira
	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			local tx, tz = cx * (half - 2), cz * (half - 2)
			local towerH = totalH + 6
			P({ Name = "Tower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(towerH, 7, 7), CFrame = at(tx, FLOOR_TOP + towerH / 2, tz) * CFrame.Angles(0, 0, math.pi / 2),
				Color = wallColor:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Brick, Parent = model })
			for i = 0, 3 do
				local w = 9 - i * 2.2
				P({ Name = "TowerRoof", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, w, w), CFrame = at(tx, FLOOR_TOP + towerH + 0.8 + i * 1.6, tz) * CFrame.Angles(0, 0, math.pi / 2),
					Color = color, Material = Enum.Material.SmoothPlastic, Parent = model })
			end
			P({ Name = "FlagPole", Size = Vector3.new(0.4, 6, 0.4), CFrame = at(tx, FLOOR_TOP + towerH + 9, tz), Color = Color3.fromRGB(60, 50, 40), Parent = model })
			local flag = P({ Name = "Flag", Size = Vector3.new(3.4, 2.2, 0.2), CFrame = at(tx + 1.9, FLOOR_TOP + towerH + 10.8, tz), Color = color, Material = Enum.Material.Fabric, CanCollide = false, Parent = model })
			surfaceText(flag, Enum.NormalId.Front, "🐉")
			surfaceText(flag, Enum.NormalId.Back, "🐉")
		end
	end

	-- 2º andar (com buraco sobre a escada)
	local slabY = FLOOR_TOP + up - 0.5
	local inner = Layout.BaseSize - 2 * wallT
	local sideW = inner / 2 - stairsW / 2
	for _, side in ipairs({ -1, 1 }) do
		P({ Name = "UpperFloor", Size = Vector3.new(sideW, 1, inner), CFrame = at(side * (stairsW / 2 + sideW / 2), slabY, 0), Color = light, Material = Enum.Material.WoodPlanks, Parent = model })
	end
	local holeBack, holeFront = -half + wallT + 2, -2
	P({ Name = "UpperFloor", Size = Vector3.new(stairsW, 1, 2), CFrame = at(0, slabY, holeBack - 1), Color = light, Material = Enum.Material.WoodPlanks, Parent = model })
	P({ Name = "UpperFloor", Size = Vector3.new(stairsW, 1, half - wallT - holeFront), CFrame = at(0, slabY, (holeFront + half - wallT) / 2), Color = light, Material = Enum.Material.WoodPlanks, Parent = model })
	P({ Name = "UpperAisle", Size = Vector3.new(4, 0.1, inner - 4), CFrame = at(-stairsW / 2 - 4, slabY + 0.55, 0), Color = color, Material = Enum.Material.Fabric, CanCollide = false, Parent = model })
	P({ Name = "UpperAisle", Size = Vector3.new(4, 0.1, inner - 4), CFrame = at(stairsW / 2 + 4, slabY + 0.55, 0), Color = color, Material = Enum.Material.Fabric, CanCollide = false, Parent = model })
	-- grade de vidro na frente do 2º andar e em volta do buraco da escada
	local railH = 8
	P({ Name = "GlassRail", Size = Vector3.new(inner, railH, 0.4), CFrame = at(0, slabY + 0.5 + railH / 2, half - wallT / 2), Color = Color3.fromRGB(180, 230, 255),
		Material = Enum.Material.Glass, Transparency = 0.55, Parent = model })
	P({ Name = "RailTop", Size = Vector3.new(inner, 0.4, 0.6), CFrame = at(0, slabY + 0.5 + railH, half - wallT / 2), Color = color, Material = Enum.Material.Neon, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		P({ Name = "StairRail", Size = Vector3.new(0.3, 3, holeFront - holeBack), CFrame = at(side * (stairsW / 2 + 0.2), slabY + 2, (holeBack + holeFront) / 2), Color = Color3.fromRGB(180, 230, 255),
			Material = Enum.Material.Glass, Transparency = 0.5, Parent = model })
	end
	-- pilares segurando o 2º andar
	for _, x in ipairs({ -stairsW / 2 - 1, stairsW / 2 + 1 }) do
		for _, z in ipairs({ 6, 20 }) do
			P({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(up - 1, 1.6, 1.6), CFrame = at(x, FLOOR_TOP + (up - 1) / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(235, 230, 220), Material = Enum.Material.Marble, Parent = model })
		end
	end
	-- escada (sobe para o fundo)
	local steps = 15
	local run = (holeFront - holeBack)
	for i = 1, steps do
		local depth = run / steps
		local z = holeFront - (i - 0.5) * depth
		local topY = FLOOR_TOP + i * (up / steps)
		P({ Name = "Step", Size = Vector3.new(stairsW, topY - FLOOR_TOP, depth), CFrame = at(0, FLOOR_TOP + (topY - FLOOR_TOP) / 2, z),
			Color = i % 2 == 0 and light or light:Lerp(color, 0.25), Material = Enum.Material.WoodPlanks, Parent = model })
	end

	-- barreira de laser na entrada
	local barrier = P({ Name = "Barrier", Size = Vector3.new(Layout.EntranceWidth, h, 0.6), CFrame = at(0, FLOOR_TOP + h / 2, half - 1),
		Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.ForceField, Transparency = 1, CanCollide = false, Parent = model })
	barrier.CastShadow = false
	for _, side in ipairs({ -1, 1 }) do
		P({ Name = "LaserPost", Size = Vector3.new(1.2, h, 1.2), CFrame = at(side * (Layout.EntranceWidth / 2 + 0.6), FLOOR_TOP + h / 2, half - 1),
			Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal, Parent = model })
		P({ Name = "LaserLight", Size = Vector3.new(0.4, h - 1, 0.4), CFrame = at(side * (Layout.EntranceWidth / 2 + 0.6), FLOOR_TOP + h / 2, half - 0.3),
			Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
	end

	-- botão de trancar
	local lock = P({ Name = "LockButton", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6, 6), CFrame = at(Layout.LockButton.X, FLOOR_TOP + 0.3, Layout.LockButton.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(60, 220, 90), Material = Enum.Material.Neon, Parent = model })
	P({ Name = "LockRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 7.4, 7.4), CFrame = at(Layout.LockButton.X, FLOOR_TOP + 0.2, Layout.LockButton.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal, Parent = model })
	local lockGui = Instance.new("BillboardGui")
	lockGui.Name = "LockGui"
	lockGui.Size = UDim2.fromOffset(220, 60)
	lockGui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	lockGui.MaxDistance = 80
	lockGui.Parent = lock
	label(lockGui, "🔓 PISE PARA TRANCAR", { Name = "Text" })

	-- placa com o nome do dono
	local sign = P({ Name = "Sign", Size = Vector3.new(Layout.EntranceWidth + 10, 5, 1), CFrame = at(0, FLOOR_TOP + h + 3, half + 0.6),
		Color = Color3.fromRGB(45, 30, 25), Material = Enum.Material.Wood, Parent = model })
	P({ Name = "SignFrame", Size = Vector3.new(Layout.EntranceWidth + 11, 6, 0.6), CFrame = at(0, FLOOR_TOP + h + 3, half + 0.2), Color = color, Material = Enum.Material.Neon, Parent = model })
	local _, signFront = surfaceText(sign, Enum.NormalId.Back, "BASE LIVRE")
	signFront.Name = "OwnerText"
	local _, signBack = surfaceText(sign, Enum.NormalId.Front, "BASE LIVRE")
	signBack.Name = "OwnerText"

	local statusGui = Instance.new("BillboardGui")
	statusGui.Name = "StatusGui"
	statusGui.Size = UDim2.fromOffset(260, 50)
	statusGui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
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
			CFrame = at(pos.X, y + 0.6, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(240, 238, 245), Material = Enum.Material.Marble, Parent = slot })
		P({ Name = "PedestalBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 8.6, 8.6),
			CFrame = at(pos.X, y + 0.25, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = wallColor, Material = Enum.Material.SmoothPlastic, Parent = slot })
		P({ Name = "PedestalRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 7.8, 7.8),
			CFrame = at(pos.X, y + 1.15, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = slot })
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
		info.Size = UDim2.fromOffset(220, 90)
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
		stroke.Color = color
		stroke.Parent = frame
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 3)
		pad.PaddingBottom = UDim.new(0, 3)
		pad.Parent = frame
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
	local spawn = P({ ClassName = "SpawnLocation", Name = "Spawn", Size = Vector3.new(6, 0.2, 6), CFrame = at(Layout.SpawnPoint.X, FLOOR_TOP + 0.1, Layout.SpawnPoint.Z),
		Transparency = 1, CanCollide = false, Neutral = true, Duration = 0, Parent = model })
	spawn.CanTouch = false

	-- luzes
	for _, y in ipairs({ FLOOR_TOP + up - 2, FLOOR_TOP + up + 7 }) do
		local bulb = P({ Name = "BaseLight", Size = Vector3.new(1, 1, 1), CFrame = at(0, y, 0), Transparency = 1, CanCollide = false, Parent = model })
		local pl = Instance.new("PointLight")
		pl.Range = 45
		pl.Brightness = 0.9
		pl.Color = color:Lerp(Color3.new(1, 1, 1), 0.5)
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
	buildTerrain()
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

	-- árvores, pinheiros, pedras e flores em volta da área de jogo
	for _ = 1, 140 do
		local x = rng:NextNumber(-330, 380)
		local z = rng:NextNumber(-215, 215)
		local insidePlay = math.abs(z) < 112 and x > -215 and x < 275
		local inRiver = math.abs(math.abs(z) - 142) < 20
		if not insidePlay and not inRiver then
			local roll = rng:NextNumber()
			if roll < 0.45 then
				buildTree(env, Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.6))
			elseif roll < 0.8 then
				buildPine(env, Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.5))
			else
				buildRock(env, Vector3.new(x, 0, z), rng:NextNumber(3, 8))
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

	-- vulcão ao fundo
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
