-- Cores em degradê para os textos de raridade (placas e interface).
-- Gradientes marcados com a tag "SpinGradient" giram no cliente (Divino/Secreto).

local CollectionService = game:GetService("CollectionService")

local RarityStyle = {}

local function seq(...)
	local colors = { ... }
	local points = {}
	for i, c in ipairs(colors) do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(points)
end

local rgb = Color3.fromRGB

RarityStyle.Gradients = {
	Comum = seq(rgb(255, 255, 255), rgb(180, 180, 190)),
	Incomum = seq(rgb(170, 255, 140), rgb(50, 200, 80)),
	Raro = seq(rgb(140, 220, 255), rgb(40, 110, 255)),
	Epico = seq(rgb(240, 150, 255), rgb(140, 50, 255)),
	Lendario = seq(rgb(255, 250, 150), rgb(255, 170, 20), rgb(255, 250, 150)),
	Mitico = seq(rgb(255, 140, 170), rgb(255, 30, 70), rgb(255, 140, 170)),
	Divino = seq(rgb(255, 255, 255), rgb(255, 230, 120), rgb(255, 255, 255), rgb(255, 230, 120)),
	Secreto = seq(rgb(255, 60, 60), rgb(255, 200, 40), rgb(60, 255, 120), rgb(60, 160, 255), rgb(200, 60, 255), rgb(255, 60, 60)),
}

RarityStyle.Spin = { Lendario = true, Mitico = true, Divino = true, Secreto = true }

-- Aplica o degradê da raridade num TextLabel
function RarityStyle.Apply(label: TextLabel, rarityId: string)
	local old = label:FindFirstChild("RarityGradient")
	if old then
		old:Destroy()
	end
	local gradient = Instance.new("UIGradient")
	gradient.Name = "RarityGradient"
	gradient.Color = RarityStyle.Gradients[rarityId] or RarityStyle.Gradients.Comum
	gradient.Rotation = 90
	gradient.Parent = label
	label.TextColor3 = Color3.new(1, 1, 1)
	if RarityStyle.Spin[rarityId] then
		CollectionService:AddTag(gradient, "SpinGradient")
	end
	return gradient
end

return RarityStyle
