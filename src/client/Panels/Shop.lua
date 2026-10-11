-- Janela: Loja de Equipamentos (dinheiro do jogo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gear = require(Shared.Gear)
local Format = require(Shared.Format)
local UI = require(script.Parent.Parent.Controllers.UI)

local Shop = {}
local rows = {}

function Shop:Build(App, content)
	self.App = App
	local scroll = UI.scroll({ Size = UDim2.fromScale(1, 1), Parent = content })
	UI.list(scroll, 8)
	UI.padding(4).Parent = scroll
	for i, item in ipairs(Gear.List) do
		local row = UI.frame({ Size = UDim2.new(1, -16, 0, 74), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = i, Parent = scroll })
		local icon = UI.frame({ Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = item.Color, Parent = row })
		UI.label({ Text = item.Pass and "💎" or "🛠️", Size = UDim2.fromScale(1, 1), Parent = icon })
		UI.label({ Text = item.Name, Size = UDim2.new(1, -280, 0, 30), Position = UDim2.fromOffset(76, 6), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24, Parent = row })
		UI.label({ Text = item.Description, Size = UDim2.new(1, -280, 0, 30), Position = UDim2.fromOffset(76, 38), TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(210, 210, 220), TextWrapped = true, MaxText = 15, Parent = row })
		local button = UI.button({ Text = "", Size = UDim2.fromOffset(180, 52), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Parent = row }, function()
			if item.Pass then
				App:Send("PromptPass", item.Pass)
			else
				App:Send("BuyGear", item.Id)
			end
		end)
		rows[item.Id] = button
	end
end

function Shop:Update(state)
	for _, item in ipairs(Gear.List) do
		local button = rows[item.Id]
		if item.Pass then
			local owned = state.Passes[item.Pass]
			button.Text = owned and "✔ Seu" or "💎 Robux"
			UI.setButtonColor(button, owned and UI.Colors.Gray or UI.Colors.Gold)
		elseif state.Gear[item.Id] then
			button.Text = "✔ Comprado"
			UI.setButtonColor(button, UI.Colors.Gray)
		elseif state.Rebirths < item.Rebirth then
			button.Text = "🔒 Rebirth " .. item.Rebirth
			UI.setButtonColor(button, UI.Colors.Purple)
		else
			button.Text = Format.Cash(item.Price)
			UI.setButtonColor(button, state.Cash >= item.Price and UI.Colors.Green or UI.Colors.Red)
		end
	end
end

return Shop
