-- Janela: painel de admin (só aparece para o dono do jogo/admins).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dragons = require(Shared.Dragons)
local Mutations = require(Shared.Mutations)
local UI = require(script.Parent.Parent.Controllers.UI)

local Admin = {}

local EVENTS = {
	{ "ChuvaDeOuro", "🌟 Chuva de Ouro" },
	{ "NoiteDeLava", "🌋 Noite de Lava" },
	{ "HoraLendaria", "🐉 Hora Lendária" },
	{ "TempestadeArcoIris", "🌈 Arco-Íris" },
	{ "Frenesi", "💰 Frenesi" },
	{ "Stop", "⛔ Parar evento" },
}

function Admin:Build(App, content)
	local scroll = UI.scroll({ Size = UDim2.fromScale(1, 1), Parent = content })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(215, 50), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = scroll })
	UI.padding(4).Parent = scroll
	local order = 0
	local function add(text, color, fn)
		order += 1
		UI.button({ Text = text, Color = color, LayoutOrder = order, MaxText = 20, Parent = scroll }, fn)
	end
	for _, e in ipairs(EVENTS) do
		add(e[2], UI.Colors.Purple, function()
			App:Send("Admin", "Event", e[1])
		end)
	end
	add("🍀 Sorte servidor 10min", UI.Colors.Green, function()
		App:Send("Admin", "ServerLuck")
	end)
	add("☄️ Meteoros", UI.Colors.Red, function()
		App:Send("Admin", "Meteor")
	end)
	add("🧊 Congelar todos", UI.Colors.Blue, function()
		App:Send("Admin", "FreezeAll")
	end)
	add("🔓 Abrir bases", UI.Colors.Red, function()
		App:Send("Admin", "UnlockAll")
	end)
	add("💰 +1M (você)", UI.Colors.Gold, function()
		App:Send("Admin", "Cash", 1e6)
	end)
	add("💰 +1B (você)", UI.Colors.Gold, function()
		App:Send("Admin", "Cash", 1e9)
	end)

	-- escolher dragão e mutação para soltar na esteira / dar a todos
	local dragonIndex, mutationIndex = #Dragons.List, 1
	order += 1
	local dragonButton = UI.button({ Text = "", Color = UI.Colors.Blue, LayoutOrder = order, MaxText = 18, Parent = scroll })
	order += 1
	local mutationButton = UI.button({ Text = "", Color = UI.Colors.Blue, LayoutOrder = order, MaxText = 18, Parent = scroll })
	local function refresh()
		dragonButton.Text = "🐉 " .. Dragons.List[dragonIndex].Name
		local m = Mutations.List[mutationIndex]
		mutationButton.Text = "✨ Mutação: " .. (m.Name ~= "" and m.Name or "Normal")
	end
	dragonButton.Activated:Connect(function()
		dragonIndex = dragonIndex % #Dragons.List + 1
		refresh()
	end)
	mutationButton.Activated:Connect(function()
		mutationIndex = mutationIndex % #Mutations.List + 1
		refresh()
	end)
	refresh()
	add("➡️ Soltar na esteira", UI.Colors.Green, function()
		App:Send("Admin", "SpawnDragon", Dragons.List[dragonIndex].Id, Mutations.List[mutationIndex].Id)
	end)
	add("🎁 Dar a TODOS", UI.Colors.Gold, function()
		App:Send("Admin", "GiveAllDragon", Dragons.List[dragonIndex].Id)
	end)

	order += 1
	local box = UI.new("TextBox", { Size = UDim2.fromOffset(215, 50), BackgroundColor3 = Color3.fromRGB(20, 15, 30), TextColor3 = Color3.new(1, 1, 1),
		PlaceholderText = "Aviso para todos...", Font = UI.Font, TextScaled = true, Text = "", ClearTextOnFocus = false, LayoutOrder = order, Parent = scroll })
	UI.corner(10).Parent = box
	add("📢 Enviar aviso", UI.Colors.Purple, function()
		if #box.Text > 0 then
			App:Send("Admin", "Announce", box.Text)
			box.Text = ""
		end
	end)
end

return Admin
