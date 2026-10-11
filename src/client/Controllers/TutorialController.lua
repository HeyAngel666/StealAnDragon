-- Tutorial para jogadores novos, com seta guiando cada passo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Layout)
local UI = require(script.Parent.UI)

local TutorialController = {}

local STEPS = {
	{ Text = "1/4  🐉 Vá até a esteira e compre um dragão (aperte E)!", Wait = "Bought" },
	{ Text = "2/4  💰 Volte pra sua base e pise no botão verde do dragão para coletar!", Wait = "Collected" },
	{ Text = "3/4  🔒 Pise no botão grande na entrada da base para TRANCAR!", Wait = "Locked" },
	{ Text = "4/4  😈 Agora roube dragões das outras bases! Segure E e leve até a sua.", Wait = "Stole", Timeout = 25 },
}

function TutorialController:Init(App)
	self.App = App
	self.Step = 0
	self.Banner = UI.frame({
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(640, 50),
		BackgroundColor3 = Color3.fromRGB(255, 180, 40),
		Visible = false,
		Parent = App.Gui,
	})
	self.BannerText = UI.label({ Text = "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), MaxText = 24, Parent = self.Banner })
end

function TutorialController:ShowStep(index: number)
	self.Step = index
	local step = STEPS[index]
	local world = self.App.Controllers.WorldController
	if not step then
		self.Banner.Visible = false
		world:ClearPointer()
		self.App:Send("TutorialDone")
		self.App.Controllers.NotifyController:Alert("🎉 Tutorial completo! Boa sorte, ladrão de dragões!", Color3.fromRGB(255, 220, 80))
		return
	end
	self.Banner.Visible = true
	self.BannerText.Text = step.Text
	UI.pop(self.Banner)
	local state = self.App.State
	local baseIndex = state and state.BaseIndex or 1
	local baseCF = Layout.Bases[baseIndex]
	if step.Wait == "Bought" then
		local root = self.App.Player.Character and self.App.Player.Character:FindFirstChild("HumanoidRootPart")
		local x = root and math.clamp(root.Position.X, -150, 150) or 0
		world:PointTo("Position", Vector3.new(x, 3, 0))
	elseif step.Wait == "Collected" and baseCF then
		world:PointTo("Position", (baseCF * CFrame.new(Layout.Slots[1] + Vector3.new(5, 2, 0))).Position)
	elseif step.Wait == "Locked" and baseCF then
		self.LockBaseline = state and state.LockedUntil or 0
		world:PointTo("Position", (baseCF * CFrame.new(Layout.LockButton + Vector3.new(0, 2, 0))).Position)
	else
		world:ClearPointer()
	end
	if step.Timeout then
		task.delay(step.Timeout, function()
			if self.Step == index then
				self:ShowStep(index + 1)
			end
		end)
	end
end

function TutorialController:OnEvent(event: string)
	local step = STEPS[self.Step]
	if step and step.Wait == event then
		self.App.Controllers.SoundController:Play("Reward")
		self:ShowStep(self.Step + 1)
	end
end

function TutorialController:Start(App)
	local started = false
	App.StateChanged.Event:Connect(function(state)
		if not started then
			started = true
			if not state.TutorialDone then
				task.wait(2)
				self:ShowStep(1)
			end
		end
		-- passo de trancar: detecta pela trava
		if STEPS[self.Step] and STEPS[self.Step].Wait == "Locked" and (state.LockedUntil or 0) > (self.LockBaseline or 0) + 1 then
			self:OnEvent("Locked")
		end
	end)
end

return TutorialController
