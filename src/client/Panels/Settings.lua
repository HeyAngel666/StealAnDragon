-- Janela: configurações (música e efeitos sonoros).

local UI = require(script.Parent.Parent.Controllers.UI)

local Settings = {}
local toggles = {}

function Settings:Build(App, content)
	self.App = App
	UI.list(content, 16)
	for i, info in ipairs({ { Key = "Music", Text = "🎵 Música" }, { Key = "Sfx", Text = "🔊 Efeitos sonoros" } }) do
		local row = UI.frame({ Size = UDim2.new(1, -20, 0, 70), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = i, Parent = content })
		UI.label({ Text = info.Text, Size = UDim2.new(0.6, 0, 1, -16), Position = UDim2.fromOffset(16, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local b = UI.button({ Text = "LIGADO", Size = UDim2.fromOffset(180, 50), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Parent = row }, function()
			local state = App.State
			if state then
				local current = state.Settings[info.Key] ~= false
				App:Send("SetSetting", info.Key, not current)
			end
		end)
		toggles[info.Key] = b
	end
	self.SaveInfo = UI.label({ Text = "", Size = UDim2.new(1, -20, 0, 30), LayoutOrder = 10, MaxText = 18, Parent = content })
end

function Settings:Update(state)
	for key, b in pairs(toggles) do
		local on = state.Settings[key] ~= false
		b.Text = on and "LIGADO" or "DESLIGADO"
		UI.setButtonColor(b, on and UI.Colors.Green or UI.Colors.Red)
	end
	self.SaveInfo.Text = state.CanSave and "💾 Seu progresso é salvo automaticamente." or "⚠️ Progresso NÃO está sendo salvo."
end

return Settings
