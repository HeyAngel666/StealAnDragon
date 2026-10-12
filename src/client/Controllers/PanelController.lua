-- Abre/fecha as janelas (Loja, Robux, Rebirth, Índice, Presentes, Códigos, Config, Admin).

local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)

local PanelController = {}
local panels = {} -- [name] = { Frame, Module }
local openName = nil

local PANEL_LIST = {
	{ Name = "Shop", Title = "🛒 LOJA DE EQUIPAMENTOS", Color = UI.Colors.Red },
	{ Name = "Robux", Title = "💎 LOJA VIP", Color = UI.Colors.Gold },
	{ Name = "Rebirth", Title = "🌟 REBIRTH", Color = UI.Colors.Purple },
	{ Name = "Index", Title = "📖 ÍNDICE DE DRAGÕES", Color = UI.Colors.Blue },
	{ Name = "Rewards", Title = "🎁 PRESENTES", Color = UI.Colors.Green },
	{ Name = "Codes", Title = "🎟️ CÓDIGOS", Color = UI.Colors.Blue },
	{ Name = "Settings", Title = "⚙️ CONFIGURAÇÕES", Color = UI.Colors.Gray },
	{ Name = "Admin", Title = "🛠️ ADMIN", Color = UI.Colors.Red },
}

function PanelController:Init(App)
	self.App = App
	local panelsFolder = script.Parent.Parent:WaitForChild("Panels")
	for _, info in ipairs(PANEL_LIST) do
		local frame = UI.frame({
			Name = info.Name .. "Panel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromOffset(720, 480),
			Visible = false,
			ZIndex = 5,
			Parent = App.Gui,
		})
		UI.gradient(UI.Colors.PanelLight, UI.Colors.Panel).Parent = frame
		UI.shadow(frame)
		local header = UI.frame({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = info.Color,
			Parent = frame,
		})
		UI.label({ Text = info.Title, Size = UDim2.new(1, -80, 1, -10), Position = UDim2.fromOffset(16, 5), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 32, Parent = header })
		UI.button({ Text = "X", Color = UI.Colors.Red, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -52, 0, 5), Parent = header }, function()
			self:Close()
		end)
		local content = UI.new("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 66),
			Size = UDim2.new(1, -24, 1, -78),
			Parent = frame,
		})
		local module = require(panelsFolder:WaitForChild(info.Name))
		module:Build(App, content)
		panels[info.Name] = { Frame = frame, Module = module }
	end

	App.StateChanged.Event:Connect(function(state)
		if openName then
			local p = panels[openName]
			if p.Module.Update then
				p.Module:Update(state)
			end
		end
	end)

	-- barracas da praça abrem janelas
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local name = prompt:GetAttribute("OpenPanel")
		if name then
			self:Open(name)
		end
	end)
end

function PanelController:Open(name: string)
	local p = panels[name]
	if not p then
		return
	end
	if openName == name then
		return self:Close()
	end
	self:Close()
	openName = name
	p.Frame.Visible = true
	UI.pop(p.Frame)
	self.App.Controllers.SoundController:Play("Click")
	if p.Module.OnOpen then
		p.Module:OnOpen()
	end
	if p.Module.Update and self.App.State then
		p.Module:Update(self.App.State)
	end
	-- controle (console): já seleciona o primeiro botão da janela
	if UserInputService.GamepadEnabled then
		task.defer(function()
			for _, d in ipairs(p.Frame.Content:GetDescendants()) do
				if d:IsA("GuiButton") and d.Visible then
					GuiService.SelectedObject = d
					return
				end
			end
		end)
	end
end

function PanelController:Close()
	if openName then
		local frame = panels[openName].Frame
		frame.Visible = false
		openName = nil
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(frame) then
			GuiService.SelectedObject = nil
		end
	end
end

function PanelController:GetOpen(): string?
	return openName
end

function PanelController:IsOpen(name: string): boolean
	return openName == name
end

return PanelController
