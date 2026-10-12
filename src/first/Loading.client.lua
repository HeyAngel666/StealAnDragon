-- Tela de carregamento (aparece antes de tudo).

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function new(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local bg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = gui })
local bgGradient = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 20, 110)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(190, 50, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 40)),
	}),
	Rotation = 60,
	Parent = bg,
})

local dragon = new("TextLabel", {
	Text = "🐉",
	TextScaled = true,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.32),
	Size = UDim2.fromScale(0.22, 0.22),
	Parent = bg,
})
new("UIAspectRatioConstraint", { Parent = dragon })

local title = new("TextLabel", {
	Text = "STEAL A DRAGON",
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.8, 0.12),
	Parent = bg,
})
new("UIStroke", { Thickness = 5, Color = Color3.fromRGB(40, 10, 20), Parent = title })
new("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 250, 170), Color3.fromRGB(255, 170, 30)),
	Rotation = 90,
	Parent = title,
})

local subtitle = new("TextLabel", {
	Text = "Compre • Roube • Proteja",
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.62),
	Size = UDim2.fromScale(0.6, 0.05),
	Parent = bg,
})
new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(40, 10, 20), Parent = subtitle })

local barBack = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.75),
	Size = UDim2.fromScale(0.5, 0.035),
	BackgroundColor3 = Color3.fromRGB(30, 15, 40),
	BorderSizePixel = 0,
	Parent = bg,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barBack })
new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(20, 5, 15), Parent = barBack })
local bar = new("Frame", { Size = UDim2.fromScale(0.05, 1), BackgroundColor3 = Color3.fromRGB(110, 230, 90), BorderSizePixel = 0, Parent = barBack })
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })

local TIPS = {
	"Dica: tranque sua base pisando no botão verde da entrada!",
	"Dica: dragões raros rendem muito mais dinheiro por segundo.",
	"Dica: um tapa faz o ladrão soltar o seu dragão!",
	"Dica: eventos a cada 9 minutos trazem dragões de Ouro e Lava.",
	"Dica: complete o Índice para ganhar bônus de renda.",
	"Dica: jogue com amigos e ganhe +10% de dinheiro por amigo!",
}
local tip = new("TextLabel", {
	Text = TIPS[math.random(1, #TIPS)],
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 240, 220),
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.82),
	Size = UDim2.fromScale(0.7, 0.04),
	Parent = bg,
})
new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(40, 10, 20), Parent = tip })

-- animação
local t0 = os.clock()
local conn = RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	dragon.Position = UDim2.fromScale(0.5, 0.32 + math.sin(t * 2.5) * 0.015)
	dragon.Rotation = math.sin(t * 1.5) * 8
	bgGradient.Rotation = 60 + math.sin(t * 0.5) * 20
end)

task.spawn(function()
	while gui.Parent do
		task.wait(3.5)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)

-- espera o jogo carregar (no máximo ~15s)
local progress = 0.05
local function setProgress(p)
	progress = math.max(progress, p)
	TweenService:Create(bar, TweenInfo.new(0.3), { Size = UDim2.fromScale(progress, 1) }):Play()
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end
setProgress(0.4)
local start = os.clock()
while os.clock() - start < 15 do
	local mainGui = player.PlayerGui:FindFirstChild("MainGui")
	local queue = ContentProvider.RequestQueueSize
	setProgress(0.4 + 0.5 * (1 - math.clamp(queue / 50, 0, 1)) * math.clamp((os.clock() - start) / 3, 0, 1))
	if mainGui and player.Character and queue < 10 and os.clock() - start > 1.5 then
		break
	end
	task.wait(0.2)
end
setProgress(1)
task.wait(0.4)

-- some aos poucos
for _, d in ipairs(gui:GetDescendants()) do
	if d:IsA("TextLabel") then
		TweenService:Create(d, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	end
end
task.wait(0.7)
conn:Disconnect()
gui:Destroy()
