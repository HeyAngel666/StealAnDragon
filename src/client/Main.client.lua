-- Inicia todos os controladores do cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local App = {
	Player = player,
	State = nil,
	Remotes = Remotes,
	Controllers = {},
	StateChanged = Instance.new("BindableEvent"),
}

function App:Send(action: string, ...)
	Remotes.Action:FireServer(action, ...)
end

local gui = Instance.new("ScreenGui")
gui.Name = "MainGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
gui.Parent = playerGui
App.Gui = gui

-- escala da interface para celular/tablet
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.55, 1.15)
	end
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

local folder = script.Parent:WaitForChild("Controllers")
local ORDER = {
	"SoundController",
	"NotifyController",
	"PanelController",
	"HudController",
	"EffectsController",
	"WorldController",
	"TutorialController",
}

for _, name in ipairs(ORDER) do
	App.Controllers[name] = require(folder:WaitForChild(name))
end
for _, name in ipairs(ORDER) do
	local c = App.Controllers[name]
	if c.Init then
		c:Init(App)
	end
end

Remotes.State.OnClientEvent:Connect(function(state)
	App.State = state
	App.StateChanged:Fire(state)
end)

for _, name in ipairs(ORDER) do
	local c = App.Controllers[name]
	if c.Start then
		task.spawn(c.Start, c, App)
	end
end
