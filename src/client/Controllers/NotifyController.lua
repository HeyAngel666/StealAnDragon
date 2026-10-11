-- Mensagens na tela: pequenas (canto) e grandes (centro).

local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local NotifyController = {}

local KIND_COLORS = {
	info = Color3.fromRGB(70, 130, 230),
	success = Color3.fromRGB(60, 190, 90),
	error = Color3.fromRGB(220, 60, 60),
	warning = Color3.fromRGB(240, 150, 40),
	rare = Color3.fromRGB(170, 80, 255),
}

function NotifyController:Init(App)
	self.App = App
	self.Toasts = UI.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 140),
		Size = UDim2.fromOffset(340, 400),
		Parent = App.Gui,
	})
	local layout = UI.list(self.Toasts, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	self.AlertLabel = UI.label({
		Name = "Alert",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.8, 0, 0, 60),
		Text = "",
		Visible = false,
		MaxText = 46,
		ZIndex = 20,
		Parent = App.Gui,
	})
	self.AlertLabel:FindFirstChildOfClass("UIStroke").Thickness = 3
end

function NotifyController:Toast(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	local frame = UI.frame({
		Size = UDim2.fromOffset(330, 44),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.05,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = self.Toasts,
	})
	UI.label({
		Text = text,
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		MaxText = 20,
		TextWrapped = true,
		Parent = frame,
	})
	UI.pop(frame)
	local count = 0
	for _, child in ipairs(self.Toasts:GetChildren()) do
		if child:IsA("Frame") then
			count += 1
		end
	end
	if count > 6 then
		-- remove a mais antiga
		local oldest, oldestOrder = nil, -math.huge
		for _, child in ipairs(self.Toasts:GetChildren()) do
			if child:IsA("Frame") and child.LayoutOrder > oldestOrder then
				oldest, oldestOrder = child, child.LayoutOrder
			end
		end
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(4, function()
		if frame.Parent then
			TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.wait(0.3)
			frame:Destroy()
		end
	end)
end

local alertToken = 0
function NotifyController:Alert(text: string, color: Color3?)
	alertToken += 1
	local token = alertToken
	local l = self.AlertLabel
	l.Text = text
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextTransparency = 0
	l.Visible = true
	UI.pop(l)
	task.delay(3.2, function()
		if token == alertToken then
			TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.4)
			if token == alertToken then
				l.Visible = false
			end
		end
	end)
end

function NotifyController:Start(App)
	App.Remotes.Notify.OnClientEvent:Connect(function(text, kind)
		self:Toast(text, kind)
	end)
	App.Remotes.Alert.OnClientEvent:Connect(function(text, color)
		self:Alert(text, color)
	end)
end

return NotifyController
