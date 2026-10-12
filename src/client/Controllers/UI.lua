-- Pequena biblioteca para criar a interface com o mesmo estilo em tudo.

local TweenService = game:GetService("TweenService")

local UI = {}

UI.Font = Enum.Font.FredokaOne
UI.Colors = {
	Panel = Color3.fromRGB(34, 28, 52),
	PanelLight = Color3.fromRGB(52, 44, 78),
	Stroke = Color3.fromRGB(15, 10, 25),
	Gold = Color3.fromRGB(255, 200, 60),
	Green = Color3.fromRGB(70, 210, 100),
	Red = Color3.fromRGB(230, 70, 70),
	Blue = Color3.fromRGB(70, 150, 255),
	Purple = Color3.fromRGB(160, 90, 255),
	Gray = Color3.fromRGB(110, 110, 120),
	White = Color3.new(1, 1, 1),
}

local CUSTOM = { Parent = true, MaxText = true, Radius = true, NoStroke = true }

function UI.new(className: string, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if not CUSTOM[k] then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UI.corner(radius: number?)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UI.stroke(thickness: number?, color: Color3?)
	return UI.new("UIStroke", { Thickness = thickness or 3, Color = color or UI.Colors.Stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UI.textStroke(thickness: number?)
	return UI.new("UIStroke", { Thickness = thickness or 2, Color = UI.Colors.Stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

function UI.gradient(top: Color3, bottom: Color3)
	return UI.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end

function UI.padding(px: number)
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
	})
end

function UI.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextColor3 = UI.Colors.White,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 30),
	}
	for k, v in pairs(props or {}) do
		defaults[k] = v
	end
	local l = UI.new("TextLabel", defaults)
	UI.textStroke(2).Parent = l
	local c = UI.new("UITextSizeConstraint", { MaxTextSize = props and props.MaxText or 40 })
	c.Parent = l
	return l
end

function UI.button(props, onClick)
	local color = props.Color or UI.Colors.Green
	local b = UI.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 50),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = props.Text or "",
		Font = UI.Font,
		TextColor3 = UI.Colors.White,
		TextScaled = true,
		AutoButtonColor = false,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UI.corner(props.Radius or 12).Parent = b
	UI.stroke(3).Parent = b
	UI.textStroke(2).Parent = b
	UI.padding(6).Parent = b
	UI.new("UITextSizeConstraint", { MaxTextSize = props.MaxText or 30, Parent = b })
	local grad = UI.gradient(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.15))
	grad.Parent = b
	local scale = UI.new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.05), { Scale = 0.94 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- muda a cor de um botão criado com UI.button
function UI.setButtonColor(b: TextButton, color: Color3)
	local grad = b:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.15))
	end
end

function UI.frame(props)
	local defaults = {
		BackgroundColor3 = UI.Colors.Panel,
		BorderSizePixel = 0,
	}
	for k, v in pairs(props or {}) do
		defaults[k] = v
	end
	local f = UI.new("Frame", defaults)
	UI.corner(props and props.Radius or 14).Parent = f
	if not (props and props.NoStroke) then
		UI.stroke(3).Parent = f
	end
	return f
end

function UI.list(parent: Instance, padding: number?, horizontal: boolean?)
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = parent,
	})
end

function UI.scroll(props)
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Colors.Gold,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Selectable = false,
	}
	for k, v in pairs(props or {}) do
		defaults[k] = v
	end
	return UI.new("ScrollingFrame", defaults)
end

-- faixa de brilho que passa pelo botão de tempos em tempos
function UI.shine(button: GuiObject)
	local holder = UI.new("Frame", { Name = "Shine", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = button.ZIndex + 2, Parent = button })
	UI.corner(12).Parent = holder
	local streak = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0,
		Size = UDim2.new(0.25, 0, 2, 0), Position = UDim2.new(-0.4, 0, -0.5, 0), Rotation = 20, ZIndex = button.ZIndex + 2, Parent = holder })
	UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = streak })
	task.spawn(function()
		while holder.Parent do
			streak.Position = UDim2.new(-0.4, 0, -0.5, 0)
			TweenService:Create(streak, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Position = UDim2.new(1.2, 0, -0.5, 0) }):Play()
			task.wait(3 + math.random())
		end
	end)
end

-- sombra suave atrás de um frame
function UI.shadow(frame: GuiObject)
	local shadow = UI.new("Frame", {
		Name = "Shadow",
		AnchorPoint = frame.AnchorPoint,
		Position = frame.Position + UDim2.fromOffset(6, 8),
		Size = frame.Size,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		ZIndex = frame.ZIndex - 1,
		Visible = frame.Visible,
		Parent = frame.Parent,
	})
	UI.corner(16).Parent = shadow
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		shadow.Visible = frame.Visible
	end)
	return shadow
end

function UI.pop(inst: GuiObject)
	local scale = inst:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = inst })
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return UI
