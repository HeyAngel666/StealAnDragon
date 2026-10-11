-- Janela: resgatar códigos.

local UI = require(script.Parent.Parent.Controllers.UI)

local Codes = {}

function Codes:Build(App, content)
	UI.label({ Text = "Digite um código para ganhar prêmios!", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 30), Parent = content })
	local box = UI.new("TextBox", {
		Size = UDim2.new(0.7, 0, 0, 56),
		Position = UDim2.new(0.15, 0, 0, 100),
		BackgroundColor3 = Color3.fromRGB(20, 15, 30),
		TextColor3 = Color3.new(1, 1, 1),
		PlaceholderText = "CÓDIGO AQUI",
		PlaceholderColor3 = Color3.fromRGB(140, 140, 150),
		Font = UI.Font,
		TextScaled = true,
		Text = "",
		ClearTextOnFocus = false,
		Parent = content,
	})
	UI.corner(12).Parent = box
	UI.stroke(3).Parent = box
	UI.padding(8).Parent = box
	UI.button({ Text = "RESGATAR", Size = UDim2.fromOffset(240, 56), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 180), Parent = content }, function()
		if #box.Text > 0 then
			App:Send("RedeemCode", box.Text)
			box.Text = ""
		end
	end)
	UI.label({ Text = "👍 Curta e favorite o jogo! Novos códigos a cada atualização.", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 270),
		TextColor3 = UI.Colors.Gold, MaxText = 20, Parent = content })
end

return Codes
