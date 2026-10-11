-- Monta os modelos 3D dos dragões usando peças (sem precisar de malhas externas).
-- O dragão olha para -Z (LookVector), com os pés em Y = 0.

local CollectionService = game:GetService("CollectionService")

local Dragons = require(script.Parent.Dragons)
local Rarities = require(script.Parent.Rarities)
local Mutations = require(script.Parent.Mutations)

local DragonBuilder = {}

local BASE_SCALE = 0.8

local function ellipsoid(size: Vector3, cf: CFrame, color: Color3, role: string, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p:SetAttribute("Role", role)
	return p
end

local function block(size: Vector3, cf: CFrame, color: Color3, role: string, material: Enum.Material?, className: string?)
	local p = Instance.new(className or "Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Role", role)
	return p
end

local function ball(diameter: number, cf: CFrame, color: Color3, role: string, material: Enum.Material?)
	local p = block(Vector3.new(diameter, diameter, diameter), cf, color, role, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function addParticles(parent: Instance, color: Color3, props)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = props.LightEmission or 1
	e.Rate = props.Rate or 8
	e.Lifetime = props.Lifetime or NumberRange.new(0.8, 1.4)
	e.Speed = props.Speed or NumberRange.new(1, 3)
	e.SpreadAngle = props.SpreadAngle or Vector2.new(180, 180)
	e.Size = props.Size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = props.Transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	if props.Acceleration then
		e.Acceleration = props.Acceleration
	end
	e.Parent = parent
	return e
end

--[[
	Build(dragonId, mutationId, options)
	options.Scale     multiplicador extra de tamanho
	options.Anchored  se a raiz fica ancorada (padrão true)
	options.NoEffects sem partículas/luzes (para miniaturas)
]]
function DragonBuilder.Build(dragonId: string, mutationId: string?, options)
	options = options or {}
	local def = Dragons.Get(dragonId)
	assert(def, "Dragão desconhecido: " .. tostring(dragonId))
	local rarity = Rarities.Get(def.Rarity)
	local mutation = Mutations.Get(mutationId)
	local s = BASE_SCALE * rarity.Scale * (options.Scale or 1)
	local style = def.Style or "Basic"

	local model = Instance.new("Model")
	model.Name = def.Name
	model:SetAttribute("DragonId", def.Id)
	model:SetAttribute("Mutation", mutation.Id)

	local parts = {}
	local function add(p)
		table.insert(parts, p)
		p.Parent = model
		return p
	end

	local material = def.Material and Enum.Material[def.Material] or Enum.Material.SmoothPlastic
	local bodyColor, bellyColor, wingColor = def.Body, def.Belly, def.Wing
	local hornColor = def.Horn or bellyColor:Lerp(Color3.new(1, 1, 1), 0.4)

	local function V(x, y, z)
		return Vector3.new(x, y, z) * s
	end
	local function C(x, y, z)
		return CFrame.new(x * s, y * s, z * s)
	end

	-- Raiz invisível (pivô do modelo)
	local root = block(Vector3.new(1, 1, 1), CFrame.new(), Color3.new(1, 1, 1), "Root")
	root.Name = "Root"
	root.Transparency = 1
	add(root)

	-- Proporções por estilo
	local bodySize = V(2.6, 2.4, 3.6)
	local legLen = 1.4
	local wingScale = 1
	local tailSegments = 4
	local neckLen = 1
	if style == "Chunky" then
		bodySize = V(3.3, 2.9, 3.9)
		legLen = 1.1
		wingScale = 0.75
	elseif style == "Serpent" then
		bodySize = V(2.1, 2.0, 4.2)
		tailSegments = 7
		neckLen = 1.4
		wingScale = 0.85
	elseif style == "Skeleton" then
		bodySize = V(2.2, 2.1, 3.6)
	end

	local bodyY = (legLen + 0.9)
	local body = add(ellipsoid(bodySize, C(0, bodyY, 0), bodyColor, "Body", material))
	body.Name = "Body"
	if style == "Skeleton" then
		body.Transparency = 0.35
		-- costelas
		for i = -1, 1 do
			add(block(V(2.5, 0.25, 0.3), C(0, bodyY + 0.2, i * 0.9) * CFrame.Angles(0, 0, 0), bellyColor, "Belly", Enum.Material.SmoothPlastic))
			add(block(V(0.25, 2.2, 0.3), C(1.1, bodyY, i * 0.9), bellyColor, "Belly", Enum.Material.SmoothPlastic))
			add(block(V(0.25, 2.2, 0.3), C(-1.1, bodyY, i * 0.9), bellyColor, "Belly", Enum.Material.SmoothPlastic))
		end
	else
		add(ellipsoid(bodySize * Vector3.new(0.82, 0.8, 0.82), C(0, bodyY - 0.28, -0.3), bellyColor, "Belly", material))
	end

	-- Pescoço + cabeça (a Hidra tem três)
	local headOffsets = { 0 }
	if style == "Hydra" then
		headOffsets = { -0.45, 0, 0.45 }
	end
	local headParts = {}
	for _, yaw in ipairs(headOffsets) do
		local base = CFrame.new(0, bodyY * s, 0) * CFrame.Angles(0, yaw, 0)
		local neckCF = base * C(0, 1.1 * neckLen, -1.4) * CFrame.Angles(-0.55, 0, 0)
		add(ellipsoid(V(1.25, 2.0 * neckLen, 1.25), neckCF, bodyColor, "Body", material))
		local headCF = base * C(0, 2.2 * neckLen, -2.1 - 0.3 * neckLen)
		local head = add(ellipsoid(V(1.9, 1.6, 2.0), headCF, bodyColor, "Body", material))
		head.Name = "Head"
		table.insert(headParts, head)
		add(ellipsoid(V(1.35, 1.0, 1.5), headCF * C(0, -0.25, -0.95), bodyColor, "Body", material))
		add(ellipsoid(V(1.15, 0.45, 1.3), headCF * C(0, -0.6, -0.8), bellyColor, "Belly", material))
		-- olhos
		for _, side in ipairs({ -1, 1 }) do
			add(ball(0.5 * s, headCF * C(side * 0.55, 0.3, -0.7), def.Eye, "Eye", Enum.Material.Neon))
			add(ball(0.24 * s, headCF * C(side * 0.62, 0.32, -0.92), Color3.new(0.05, 0.05, 0.05), "Pupil"))
			-- chifres
			local horn = block(V(0.35, 1.2, 0.7), headCF * C(side * 0.5, 1.0, 0.4) * CFrame.Angles(0.6, 0, side * -0.2), hornColor, "Horn", Enum.Material.SmoothPlastic, "WedgePart")
			add(horn)
			if style == "Spiky" or style == "Crystal" then
				add(block(V(0.25, 0.8, 0.5), headCF * C(side * 0.85, 0.55, 0.6) * CFrame.Angles(0.8, 0, side * -0.6), hornColor, "Horn", Enum.Material.SmoothPlastic, "WedgePart"))
			end
		end
	end

	-- Pernas
	if style ~= "Serpent" then
		for _, side in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1.0, 1.1 }) do
				add(ellipsoid(V(0.8, legLen + 0.4, 0.85), C(side * 0.9, (legLen + 0.4) / 2 + 0.2, z), bodyColor, "Body", material))
				add(ellipsoid(V(0.95, 0.45, 1.2), C(side * 0.9, 0.22, z - 0.15), bellyColor, "Belly", material))
			end
		end
	else
		for _, side in ipairs({ -1, 1 }) do
			add(ellipsoid(V(0.6, 1.0, 0.7), C(side * 0.8, 0.6, -0.9), bodyColor, "Body", material))
			add(ellipsoid(V(0.6, 1.0, 0.7), C(side * 0.8, 0.6, 1.2), bodyColor, "Body", material))
		end
	end

	-- Cauda
	local tailSize = 1.2
	local z = bodySize.Z / s / 2 - 0.3
	local y = bodyY - 0.3
	local lastCF = C(0, y, z)
	for i = 1, tailSegments do
		local segLen = 1.5
		z += segLen * 0.75
		y += (style == "Serpent") and math.sin(i * 0.9) * 0.35 or -0.12
		lastCF = C(0, y, z)
		add(ellipsoid(V(tailSize, tailSize * 0.9, segLen), lastCF, bodyColor, "Body", material))
		tailSize *= 0.8
	end
	local tip = add(block(V(0.2, 1.1, 1.1), lastCF * C(0, 0.1, 0.8) * CFrame.Angles(math.rad(45), 0, 0), hornColor, "Horn"))
	tip.Name = "TailTip"

	-- Espinhos nas costas
	if style == "Spiky" or style == "Crystal" or style == "Chunky" or style == "Hydra" then
		for i = 0, 3 do
			local spikeMat = style == "Crystal" and Enum.Material.Neon or Enum.Material.SmoothPlastic
			local spikeColor = style == "Crystal" and bellyColor or hornColor
			add(block(V(0.25, 0.9 - i * 0.1, 0.8), C(0, bodyY + bodySize.Y / s / 2 - 0.05, -0.9 + i * 0.75), spikeColor, "Horn", spikeMat, "WedgePart"))
		end
	end
	if style == "Crystal" then
		for _, side in ipairs({ -1, 1 }) do
			local crystal = block(V(0.5, 1.4, 0.5), C(side * 0.9, bodyY + 1.0, 0.4) * CFrame.Angles(0.3, 0.6, side * 0.5), bellyColor, "Belly", Enum.Material.Neon)
			crystal.Transparency = 0.2
			add(crystal)
		end
	end

	-- Asas (articuladas para bater)
	local wingWelds = {}
	for _, side in ipairs({ -1, 1 }) do
		local wingSize = V(2.6 * wingScale, 0.12, 2.0 * wingScale)
		local shoulder = C(side * bodySize.X / s * 0.38, bodyY + 0.75, -0.2) * CFrame.Angles(0, side * -0.25, side * math.rad(35))
		local half = wingSize.X / 2
		local wingCF = shoulder * CFrame.new(side * half, 0, 0)
		local wing = add(block(wingSize, wingCF, wingColor, "Wing", Enum.Material.SmoothPlastic))
		wing.Name = side < 0 and "WingL" or "WingR"
		local outer = add(block(V(1.9 * wingScale, 0.1, 1.5 * wingScale), wingCF * CFrame.new(side * (half + 0.85 * s * wingScale), 0.25 * s, 0.25 * s) * CFrame.Angles(0, 0, side * 0.35), wingColor, "Wing"))
		local bone = add(block(V(2.6 * wingScale, 0.22, 0.22), wingCF * C(0, 0.05, -1.0 * wingScale), bodyColor, "Body", material))
		local weld = Instance.new("Weld")
		weld.Name = "WingJoint"
		weld.Part0 = body
		weld.Part1 = wing
		weld.C0 = body.CFrame:ToObjectSpace(shoulder)
		weld.C1 = CFrame.new(-side * half, 0, 0)
		weld:SetAttribute("Side", side)
		weld.Parent = wing
		for _, extra in ipairs({ outer, bone }) do
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = wing
			wc.Part1 = extra
			wc.Parent = extra
		end
		table.insert(wingWelds, weld)
	end

	-- Efeitos
	local effects = {}
	for _, e in ipairs(def.Effects or {}) do
		effects[e] = true
	end
	local head = headParts[1]

	if effects.Crown then
		local crownCF = head.CFrame * C(0, 0.95, 0.1)
		add(block(V(1.1, 0.35, 1.1), crownCF, Color3.fromRGB(255, 205, 40), "Crown", Enum.Material.Metal))
		for i = 0, 3 do
			local a = i * math.pi / 2
			add(block(V(0.2, 0.5, 0.4), crownCF * CFrame.Angles(0, a, 0) * C(0, 0.4, -0.45), Color3.fromRGB(255, 205, 40), "Crown", Enum.Material.Metal, "WedgePart"))
		end
	end
	if effects.Halo then
		local haloCF = head.CFrame * C(0, 1.7, 0.2)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			add(ball(0.32 * s, haloCF * C(math.cos(a) * 0.8, 0, math.sin(a) * 0.8), Color3.fromRGB(255, 240, 150), "Halo", Enum.Material.Neon))
		end
	end

	if not options.NoEffects then
		if effects.Fire then
			local fire = Instance.new("Fire")
			fire.Size = 3 * s
			fire.Heat = 6
			fire.Color = bellyColor
			fire.SecondaryColor = bodyColor
			fire.Parent = tip
			local fire2 = Instance.new("Fire")
			fire2.Size = 2 * s
			fire2.Heat = 3
			fire2.Parent = head
		end
		if effects.Sparkles then
			local sp = Instance.new("Sparkles")
			sp.SparkleColor = bellyColor
			sp.Parent = body
		end
		if effects.Smoke then
			local sm = Instance.new("Smoke")
			sm.Color = bodyColor
			sm.Opacity = 0.08
			sm.RiseVelocity = 1
			sm.Size = 1.5 * s
			sm.Parent = body
		end
		if effects.Lightning then
			addParticles(body, Color3.fromRGB(255, 250, 120), { Rate = 10, Lifetime = NumberRange.new(0.1, 0.25), Speed = NumberRange.new(6, 10) })
		end
		if effects.Aura then
			addParticles(body, rarity.Color, { Rate = 15, Speed = NumberRange.new(0.5, 1.5),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * s), NumberSequenceKeypoint.new(1, 0) }) })
		end
		if effects.Stars then
			addParticles(body, Color3.new(1, 1, 1), { Rate = 12, Speed = NumberRange.new(0.5, 2),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }) })
		end
		if effects.Bubbles then
			addParticles(body, Color3.fromRGB(150, 230, 255), { Rate = 6, Speed = NumberRange.new(1, 2), Acceleration = Vector3.new(0, 4, 0), LightEmission = 0.3 })
		end
		if rarity.Order >= 5 then
			local light = Instance.new("PointLight")
			light.Color = rarity.Color
			light.Range = 10 * s
			light.Brightness = 1.5
			light.Parent = body
		end
	end
	if effects.Rainbow then
		CollectionService:AddTag(model, "Rainbow")
	end
	if effects.Glitch then
		CollectionService:AddTag(model, "Glitch")
	end

	-- Mutação
	if mutation.Id ~= "Normal" then
		for _, p in ipairs(parts) do
			local role = p:GetAttribute("Role")
			if role == "Body" or role == "Wing" or role == "Belly" then
				if mutation.Id == "Ouro" then
					p.Color = role == "Belly" and Color3.fromRGB(255, 230, 120) or Color3.fromRGB(255, 190, 30)
					p.Material = Enum.Material.Metal
					p.Reflectance = 0.15
				elseif mutation.Id == "Diamante" then
					p.Color = role == "Belly" and Color3.fromRGB(220, 255, 255) or Color3.fromRGB(110, 220, 255)
					p.Material = Enum.Material.Glass
					p.Reflectance = 0.25
				elseif mutation.Id == "Lava" then
					if role == "Belly" then
						p.Color = Color3.fromRGB(255, 100, 0)
						p.Material = Enum.Material.Neon
					else
						p.Color = Color3.fromRGB(40, 30, 30)
						p.Material = Enum.Material.Basalt
					end
				end
			end
		end
		if not options.NoEffects then
			if mutation.Id == "Ouro" or mutation.Id == "Diamante" then
				local sp = Instance.new("Sparkles")
				sp.SparkleColor = mutation.Color
				sp.Parent = body
			elseif mutation.Id == "Lava" then
				local fire = Instance.new("Fire")
				fire.Size = 4 * s
				fire.Color = Color3.fromRGB(255, 120, 0)
				fire.SecondaryColor = Color3.fromRGB(255, 40, 0)
				fire.Parent = body
			end
		end
		if mutation.Id == "ArcoIris" then
			CollectionService:AddTag(model, "Rainbow")
		end
	end

	-- Juntar tudo na raiz
	local anchored = options.Anchored ~= false
	for _, p in ipairs(parts) do
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = p == root or p == body
		p.Massless = true
		p.CastShadow = p ~= root
		if p == root then
			p.Anchored = anchored
		else
			p.Anchored = false
			if not p:FindFirstChildWhichIsA("Weld") and not p:FindFirstChildWhichIsA("WeldConstraint") then
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = root
				wc.Part1 = p
				wc.Parent = p
			end
		end
	end

	local promptAttachment = Instance.new("Attachment")
	promptAttachment.Name = "PromptAttachment"
	promptAttachment.Position = Vector3.new(0, bodyY * s + 1.5 * s, 0)
	promptAttachment.Parent = root

	local topAttachment = Instance.new("Attachment")
	topAttachment.Name = "TopAttachment"
	topAttachment.Position = Vector3.new(0, (bodyY + 2.2 * neckLen + 2.2) * s, 0)
	topAttachment.Parent = root

	model.PrimaryPart = root
	model:SetAttribute("Height", (bodyY + 2.2 * neckLen + 1.5) * s)
	CollectionService:AddTag(model, "Dragon")
	return model
end

return DragonBuilder
