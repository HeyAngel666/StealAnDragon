-- Janela: Índice de dragões (coleção). Completar uma raridade dá +5% de renda.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dragons = require(Shared.Dragons)
local Rarities = require(Shared.Rarities)
local Format = require(Shared.Format)
local Config = require(Shared.Config)
local DragonBuilder = require(Shared.DragonBuilder)
local UI = require(script.Parent.Parent.Controllers.UI)

local Index = {}
local cards = {}
local built = false

function Index:Build(App, content)
	self.App = App
	self.Summary = UI.label({ Text = "", Size = UDim2.new(1, 0, 0, 28), MaxText = 20, Parent = content })
	local scroll = UI.scroll({ Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34), Parent = content })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 190), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = scroll })
	UI.padding(4).Parent = scroll
	self.Scroll = scroll
end

function Index:BuildCards()
	if built then
		return
	end
	built = true
	for i, def in ipairs(Dragons.List) do
		local rarity = Rarities.Get(def.Rarity)
		local card = UI.frame({ Size = UDim2.fromOffset(160, 190), BackgroundColor3 = rarity.Color:Lerp(Color3.new(0, 0, 0), 0.6), LayoutOrder = i, Parent = self.Scroll })
		card:FindFirstChildOfClass("UIStroke").Color = rarity.Color
		local vp = UI.new("ViewportFrame", { Size = UDim2.new(1, -12, 0, 110), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(200, 200, 200), LightColor = Color3.new(1, 1, 1), Parent = card })
		local model = DragonBuilder.Build(def.Id, "Normal", { NoEffects = true })
		model:PivotTo(CFrame.Angles(0, math.rad(150), 0))
		model.Parent = vp
		local camera = Instance.new("Camera")
		local size = model:GetExtentsSize()
		local center = model:GetBoundingBox().Position
		local dist = math.max(size.X, size.Y, size.Z) * 1.25
		camera.CFrame = CFrame.lookAt(center + Vector3.new(dist * 0.6, dist * 0.35, -dist * 0.8), center)
		camera.FieldOfView = 50
		camera.Parent = vp
		vp.CurrentCamera = camera
		local name = UI.label({ Text = def.Name, Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 118), MaxText = 16, Parent = card })
		UI.label({ Text = rarity.Name, Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 142), TextColor3 = rarity.Color, MaxText = 15, Parent = card })
		local income = UI.label({ Text = Format.Cash(def.Income) .. "/s", Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 164),
			TextColor3 = Color3.fromRGB(120, 255, 120), MaxText = 15, Parent = card })
		cards[def.Id] = { Viewport = vp, Name = name, Income = income, Def = def }
	end
end

function Index:OnOpen()
	self:BuildCards()
end

function Index:Update(state)
	if not built then
		return
	end
	local found, total = 0, #Dragons.List
	for id, c in pairs(cards) do
		local known = state.Index[id] == true
		if known then
			found += 1
		end
		c.Viewport.ImageColor3 = known and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		c.Name.Text = known and c.Def.Name or "???"
		c.Income.Visible = known
	end
	local completed = 0
	for _, rarity in ipairs(Rarities.List) do
		local all = true
		for _, def in ipairs(Dragons.ByRarity[rarity.Id] or {}) do
			if not state.Index[def.Id] then
				all = false
			end
		end
		if all then
			completed += 1
		end
	end
	self.Summary.Text = string.format("Descobertos: %d/%d  •  Raridades completas: %d (bônus +%d%% de renda)", found, total, completed,
		math.floor(completed * Config.IndexBonusPerRarity * 100))
end

return Index
