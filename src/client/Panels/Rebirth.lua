-- Janela: Rebirth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rebirths = require(Shared.Rebirths)
local Rarities = require(Shared.Rarities)
local Gear = require(Shared.Gear)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local UI = require(script.Parent.Parent.Controllers.UI)

local Rebirth = {}

function Rebirth:Build(App, content)
	self.App = App
	self.Current = UI.label({ Text = "Rebirth atual: 0", Size = UDim2.new(1, 0, 0, 36), Parent = content, TextColor3 = UI.Colors.Gold })
	self.Need = UI.label({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 44), MaxText = 24, Parent = content })

	local barBack = UI.frame({ Size = UDim2.new(0.8, 0, 0, 30), Position = UDim2.new(0.1, 0, 0, 80), BackgroundColor3 = Color3.fromRGB(20, 15, 30), Parent = content })
	self.Bar = UI.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.Colors.Green, NoStroke = true, Parent = barBack })
	self.BarText = UI.label({ Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 3, MaxText = 20, Parent = barBack })

	self.Rarity = UI.label({ Text = "", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 118), MaxText = 20, Parent = content })

	local rewards = UI.frame({ Size = UDim2.new(1, -20, 0, 140), Position = UDim2.fromOffset(10, 154), BackgroundColor3 = UI.Colors.PanelLight, Parent = content })
	UI.label({ Text = "🎁 RECOMPENSAS", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), TextColor3 = UI.Colors.Gold, Parent = rewards })
	self.Rewards = UI.label({ Text = "", Size = UDim2.new(1, -20, 0, 96), Position = UDim2.fromOffset(10, 38), TextWrapped = true, MaxText = 20,
		TextYAlignment = Enum.TextYAlignment.Top, Parent = rewards })

	UI.label({ Text = "⚠️ Você perde: dinheiro, dragões e itens comprados com dinheiro.", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 302),
		TextColor3 = Color3.fromRGB(255, 150, 130), MaxText = 18, Parent = content })

	self.Button = UI.button({ Text = "REBIRTH!", Color = UI.Colors.Purple, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(260, 56) , Parent = content }, function()
		App:Send("Rebirth")
	end)
end

function Rebirth:Update(state)
	local nextEntry = Rebirths.List[state.Rebirths + 1]
	self.Current.Text = "Rebirth atual: " .. state.Rebirths .. "  (renda x" .. Rebirths.MultiplierFor(state.Rebirths) .. ")"
	if not nextEntry then
		self.Need.Text = "Você chegou ao Rebirth máximo! 👑"
		self.Bar.Size = UDim2.fromScale(1, 1)
		self.BarText.Text = "MÁXIMO"
		self.Rarity.Text = ""
		self.Rewards.Text = ""
		self.Button.Visible = false
		return
	end
	self.Button.Visible = true
	self.Need.Text = "Próximo: Rebirth " .. (state.Rebirths + 1)
	local progress = math.clamp(state.Cash / nextEntry.Cash, 0, 1)
	self.Bar.Size = UDim2.fromScale(progress, 1)
	self.BarText.Text = Format.Cash(state.Cash) .. " / " .. Format.Cash(nextEntry.Cash)
	if nextEntry.NeedRarity then
		local r = Rarities.Get(nextEntry.NeedRarity)
		self.Rarity.Text = "Precisa de 1 dragão " .. r.Name .. " ou melhor na base"
		self.Rarity.TextColor3 = r.Color
	else
		self.Rarity.Text = ""
	end
	local lines = {
		"💰 Renda x" .. nextEntry.Multiplier,
		"🐉 +" .. Config.SlotsPerRebirth .. " espaço na base",
		"🔒 Trava +" .. Config.LockPerRebirth .. "s",
	}
	if nextEntry.Unlocks then
		table.insert(lines, "🛠️ Libera: " .. Gear.Get(nextEntry.Unlocks).Name)
	end
	self.Rewards.Text = table.concat(lines, "\n")
	UI.setButtonColor(self.Button, progress >= 1 and UI.Colors.Purple or UI.Colors.Gray)
end

return Rebirth
