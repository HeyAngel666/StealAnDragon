-- Interface fixa: dinheiro, renda, botões do menu, evento atual, status da base.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Config = require(Shared.Config)
local UI = require(script.Parent.UI)

local HudController = {}

local MENU = {
	{ Panel = "Shop", Icon = "🛒", Text = "Loja", Color = UI.Colors.Red },
	{ Panel = "Robux", Icon = "💎", Text = "VIP", Color = UI.Colors.Gold },
	{ Panel = "Rebirth", Icon = "🌟", Text = "Rebirth", Color = UI.Colors.Purple },
	{ Panel = "Index", Icon = "📖", Text = "Índice", Color = UI.Colors.Blue },
	{ Panel = "Rewards", Icon = "🎁", Text = "Presentes", Color = UI.Colors.Green },
	{ Panel = "Codes", Icon = "🎟️", Text = "Códigos", Color = Color3.fromRGB(60, 180, 200) },
	{ Panel = "Settings", Icon = "⚙️", Text = "Config", Color = UI.Colors.Gray },
}

function HudController:Init(App)
	self.App = App
	local gui = App.Gui

	-- Dinheiro (topo)
	local cashFrame = UI.frame({
		Name = "Cash",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(300, 64),
		BackgroundColor3 = Color3.fromRGB(40, 120, 50),
		Parent = gui,
	})
	UI.gradient(Color3.fromRGB(90, 220, 100), Color3.fromRGB(30, 130, 50)).Parent = cashFrame
	self.CashLabel = UI.label({ Text = "$0", Size = UDim2.new(1, -10, 0.65, 0), Position = UDim2.fromOffset(5, 2), MaxText = 40, Parent = cashFrame })
	self.IncomeLabel = UI.label({ Text = "+$0/s", Size = UDim2.new(1, -10, 0.32, 0), Position = UDim2.new(0, 5, 0.64, 0), MaxText = 20,
		TextColor3 = Color3.fromRGB(230, 255, 200), Parent = cashFrame })

	self.BaseLabel = UI.label({
		Name = "BaseStatus",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(360, 26),
		Text = "",
		MaxText = 22,
		Parent = gui,
	})

	-- Menu lateral
	local menu = UI.new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(170, 470),
		Parent = gui,
	})
	local grid = UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(78, 78),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	local _ = grid
	self.MenuButtons = {}
	for i, item in ipairs(MENU) do
		local b = UI.button({ Text = "", Color = item.Color, LayoutOrder = i, Parent = menu }, function()
			App.Controllers.PanelController:Open(item.Panel)
		end)
		UI.label({ Text = item.Icon, Size = UDim2.new(1, 0, 0.62, 0), MaxText = 36, Parent = b })
		UI.label({ Text = item.Text, Size = UDim2.new(1, 0, 0.36, 0), Position = UDim2.fromScale(0, 0.64), MaxText = 16, Parent = b })
		local badge = UI.frame({ Name = "Badge", Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -18, 0, -8), BackgroundColor3 = UI.Colors.Red, Visible = false, Radius = 12, Parent = b })
		UI.label({ Text = "!", Size = UDim2.fromScale(1, 1), Parent = badge })
		self.MenuButtons[item.Panel] = b
	end
	self.AdminButton = UI.button({ Text = "", Color = UI.Colors.Red, LayoutOrder = 99, Parent = menu }, function()
		App.Controllers.PanelController:Open("Admin")
	end)
	UI.label({ Text = "🛠️", Size = UDim2.new(1, 0, 0.62, 0), MaxText = 36, Parent = self.AdminButton })
	UI.label({ Text = "Admin", Size = UDim2.new(1, 0, 0.36, 0), Position = UDim2.fromScale(0, 0.64), MaxText = 16, Parent = self.AdminButton })
	self.AdminButton.Visible = false

	-- Evento (direita, topo)
	self.EventFrame = UI.frame({
		Name = "Event",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(300, 70),
		BackgroundColor3 = Color3.fromRGB(150, 60, 220),
		Visible = false,
		Parent = gui,
	})
	self.EventName = UI.label({ Text = "", Size = UDim2.new(1, -10, 0.5, 0), Position = UDim2.fromOffset(5, 3), MaxText = 24, Parent = self.EventFrame })
	self.EventTimer = UI.label({ Text = "", Size = UDim2.new(1, -10, 0.4, 0), Position = UDim2.new(0, 5, 0.55, 0), MaxText = 18, Parent = self.EventFrame })

	self.LuckLabel = UI.label({
		Name = "Luck",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 84),
		Size = UDim2.fromOffset(300, 26),
		Text = "",
		TextColor3 = Color3.fromRGB(120, 255, 120),
		MaxText = 20,
		Parent = gui,
	})

	-- Botão coletar tudo
	self.CollectButton = UI.button({
		Text = "💰 Coletar tudo",
		Color = UI.Colors.Green,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -90),
		Size = UDim2.fromOffset(190, 52),
		Parent = gui,
	}, function()
		App:Send("CollectAll")
	end)

	-- Aviso de carregamento do dragão
	self.CarryLabel = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(520, 40),
		Text = "🐉 Leve o dragão até a SUA BASE!",
		TextColor3 = Color3.fromRGB(255, 230, 90),
		Visible = false,
		MaxText = 30,
		Parent = gui,
	})

	-- Recarga dos itens
	self.CooldownLabel = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(300, 26),
		Text = "",
		MaxText = 20,
		Parent = gui,
	})
	self.Cooldowns = {}
end

function HudController:SetCarrying(active: boolean)
	self.CarryLabel.Visible = active
end

function HudController:SetCooldown(gearName: string, duration: number)
	self.Cooldowns[gearName] = os.clock() + duration
end

function HudController:Start(App)
	local displayedCash = 0
	App.StateChanged.Event:Connect(function(state)
		self.IncomeLabel.Text = "+" .. Format.Cash(state.Income) .. "/s"
		self.AdminButton.Visible = state.IsAdmin == true
		-- badge de presentes disponíveis
		local canClaim = state.Daily and state.Daily.CanClaim
		if state.Playtime then
			local elapsed = state.ServerTime - state.Playtime.JoinTime
			for i, reward in ipairs(Config.PlaytimeRewards) do
				if not state.Playtime.Claimed[i] and not state.Playtime.Claimed[tostring(i)] and elapsed >= reward.Minutes * 60 then
					canClaim = true
				end
			end
		end
		self.MenuButtons.Rewards.Badge.Visible = canClaim == true
	end)

	RunService.RenderStepped:Connect(function(dt)
		local state = App.State
		if not state then
			return
		end
		-- animação do contador de dinheiro
		displayedCash += (state.Cash - displayedCash) * math.min(1, dt * 8)
		if math.abs(state.Cash - displayedCash) < 1 then
			displayedCash = state.Cash
		end
		self.CashLabel.Text = Format.Cash(displayedCash)

		local now = workspace:GetServerTimeNow()
		local lockEnd = math.max(state.LockedUntil or 0, state.ShieldUntil or 0)
		if lockEnd > now then
			self.BaseLabel.Text = ((state.ShieldUntil or 0) > now and "🛡️ Escudo " or "🔒 Base trancada ") .. Format.Time(lockEnd - now)
			self.BaseLabel.TextColor3 = Color3.fromRGB(120, 220, 255)
		else
			self.BaseLabel.Text = "🔓 Base aberta - tranque no botão verde!"
			self.BaseLabel.TextColor3 = Color3.fromRGB(255, 140, 120)
		end

		local eventEnds = workspace:GetAttribute("EventEnds") or 0
		if eventEnds > now then
			self.EventFrame.Visible = true
			self.EventName.Text = workspace:GetAttribute("EventName") or ""
			self.EventTimer.Text = (workspace:GetAttribute("EventDescription") or "") .. "  " .. Format.Time(eventEnds - now)
		else
			self.EventFrame.Visible = false
		end
		local luckEnds = workspace:GetAttribute("ServerLuckEnds") or 0
		self.LuckLabel.Text = luckEnds > now and ("🍀 Sorte x3 do servidor: " .. Format.Time(luckEnds - now)) or ""

		local parts = {}
		for name, t in pairs(self.Cooldowns) do
			local left = t - os.clock()
			if left > 0 then
				table.insert(parts, string.format("⏳ %s %.1fs", name, left))
			else
				self.Cooldowns[name] = nil
			end
		end
		self.CooldownLabel.Text = table.concat(parts, "   ")
	end)
end

return HudController
