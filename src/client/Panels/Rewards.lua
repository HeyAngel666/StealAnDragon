-- Janela: Presentes por tempo jogado + prêmio diário.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rarities = require(Shared.Rarities)
local Format = require(Shared.Format)
local UI = require(script.Parent.Parent.Controllers.UI)

local Rewards = {}
local slots = {}

function Rewards:Build(App, content)
	self.App = App
	local daily = UI.frame({ Size = UDim2.new(1, -10, 0, 70), Position = UDim2.fromOffset(5, 0), BackgroundColor3 = UI.Colors.PanelLight, Parent = content })
	self.DailyText = UI.label({ Text = "📅 Prêmio diário", Size = UDim2.new(1, -230, 1, -16), Position = UDim2.fromOffset(12, 8), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22, Parent = daily })
	self.DailyButton = UI.button({ Text = "Pegar!", Size = UDim2.fromOffset(200, 52), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Parent = daily }, function()
		App:Send("ClaimDaily")
	end)

	UI.label({ Text = "🎁 Presentes por tempo jogado (reinicia ao entrar de novo)", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 78), MaxText = 18, Parent = content })
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -110), Position = UDim2.fromOffset(0, 108), Parent = content })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 150), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
	for i, reward in ipairs(Config.PlaytimeRewards) do
		local f = UI.frame({ BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = i, Parent = grid })
		local text
		if reward.Kind == "Cash" then
			text = "💰 " .. Format.Cash(reward.Amount) .. "+"
		else
			local r = Rarities.Get(reward.Rarity)
			text = "🐉 Dragão " .. r.Name
		end
		UI.label({ Text = text, Size = UDim2.new(1, -10, 0, 40), Position = UDim2.fromOffset(5, 8), TextWrapped = true, MaxText = 20, Parent = f })
		local timer = UI.label({ Text = "", Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 52), MaxText = 20, TextColor3 = UI.Colors.Gold, Parent = f })
		local b = UI.button({ Text = "Pegar", Size = UDim2.new(1, -20, 0, 44), Position = UDim2.new(0, 10, 1, -52), Parent = f }, function()
			App:Send("ClaimPlaytime", i)
		end)
		slots[i] = { Timer = timer, Button = b }
	end

	RunService.Heartbeat:Connect(function()
		if content.Parent.Visible then
			self:Refresh()
		end
	end)
end

function Rewards:Refresh()
	local state = self.App.State
	if not state or not state.Playtime then
		return
	end
	local elapsed = workspace:GetServerTimeNow() - state.Playtime.JoinTime
	for i, reward in ipairs(Config.PlaytimeRewards) do
		local s = slots[i]
		local claimed = state.Playtime.Claimed[tostring(i)]
		local left = reward.Minutes * 60 - elapsed
		if claimed then
			s.Timer.Text = "✔ Pego"
			s.Button.Visible = false
		elseif left > 0 then
			s.Timer.Text = "⏳ " .. Format.Time(left)
			s.Button.Visible = false
		else
			s.Timer.Text = "PRONTO!"
			s.Button.Visible = true
		end
	end
	local daily = state.Daily
	if daily then
		local day = (daily.Streak % #Config.DailyRewards) + 1
		self.DailyText.Text = "📅 Prêmio diário - Dia " .. day .. " (sequência: " .. daily.Streak .. ")"
		self.DailyButton.Text = daily.CanClaim and "Pegar!" or "Volte amanhã"
		UI.setButtonColor(self.DailyButton, daily.CanClaim and UI.Colors.Green or UI.Colors.Gray)
	end
end

function Rewards:Update()
	self:Refresh()
end

return Rewards
