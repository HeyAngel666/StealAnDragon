-- Suporte a controle (Xbox / PlayStation / controle no PC).
--   Y (Triângulo) = abrir o menu lateral (navegue com o direcional e aperte A)
--   B (Bola)      = fechar a janela / sair do menu
--   Direcional ↓  = coletar tudo (dentro da sua base)
-- Andar, pular, usar itens (R2) e trocar itens (L1/R1) já funcionam pelo Roblox.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)

local GamepadController = {}

local function menuSelected(hud): boolean
	local selected = GuiService.SelectedObject
	return selected ~= nil and selected:IsDescendantOf(hud.MenuButtons.Shop.Parent)
end

function GamepadController:Init(App)
	self.App = App
	self.Hint = UI.label({
		Name = "GamepadHint",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(460, 28),
		Text = "Ⓨ Menu   Ⓑ Fechar   ⬇ Coletar tudo   ⓧ Comprar/Roubar",
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxText = 20,
		Visible = false,
		Parent = App.Gui,
	})
end

function GamepadController:Start(App)
	local hud = App.Controllers.HudController
	local panels = App.Controllers.PanelController

	local function updateHint()
		local last = UserInputService:GetLastInputType()
		self.Hint.Visible = UserInputService.GamepadEnabled and last.Name:find("Gamepad") ~= nil
	end
	updateHint()
	UserInputService.LastInputTypeChanged:Connect(updateHint)
	UserInputService.GamepadConnected:Connect(updateHint)
	UserInputService.GamepadDisconnected:Connect(updateHint)

	-- Y: abre/fecha a seleção do menu lateral
	ContextActionService:BindAction("GamepadMenu", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if panels:GetOpen() then
			panels:Close()
		end
		if menuSelected(hud) then
			GuiService.SelectedObject = nil
		else
			GuiService.SelectedObject = hud.MenuButtons.Shop
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonY)

	-- B: fecha janela ou sai do menu
	ContextActionService:BindAction("GamepadBack", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if panels:GetOpen() then
			panels:Close()
			return Enum.ContextActionResult.Sink
		end
		if GuiService.SelectedObject then
			GuiService.SelectedObject = nil
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB)

	-- Direcional para baixo: coletar tudo (só quando não está navegando na interface)
	ContextActionService:BindAction("GamepadCollect", function(_, state)
		if state ~= Enum.UserInputState.Begin or GuiService.SelectedObject then
			return Enum.ContextActionResult.Pass
		end
		App:Send("CollectAll")
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.DPadDown)
end

return GamepadController
