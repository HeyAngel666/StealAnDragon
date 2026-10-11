-- Eventos do servidor: automáticos (a cada ~9 min) e comprados com Robux
-- (sorte do servidor, chuva de meteoros, congelar todos, abrir bases).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)

local EventService = {}

EventService.Events = {
	{ Id = "ChuvaDeOuro", Name = "🌟 CHUVA DE OURO", Description = "Muito mais dragões de Ouro e Diamante!",
		Mutations = { Ouro = 6, Diamante = 3 } },
	{ Id = "NoiteDeLava", Name = "🌋 NOITE DE LAVA", Description = "Dragões de LAVA (x3) aparecem na esteira!",
		Mutations = { Lava = 1 } },
	{ Id = "HoraLendaria", Name = "🐉 HORA LENDÁRIA", Description = "Sorte x4 para dragões raros!",
		Luck = 4 },
	{ Id = "TempestadeArcoIris", Name = "🌈 TEMPESTADE ARCO-ÍRIS", Description = "Chance de Arco-Íris x8!",
		Mutations = { ArcoIris = 8 } },
	{ Id = "Frenesi", Name = "💰 FRENESI DO DINHEIRO", Description = "Todos ganham dinheiro em dobro!",
		Cash = 2, SpawnRate = 1.5 },
}

local byId = {}
for _, e in ipairs(EventService.Events) do
	byId[e.Id] = e
end

local current = nil
local currentEnds = 0
local serverLuckUntil = 0
local SERVER_LUCK = 3

local function now()
	return workspace:GetServerTimeNow()
end

function EventService:GetCurrent()
	if current and now() < currentEnds then
		return current
	end
	return nil
end

function EventService:GetLuck(): number
	local luck = 1
	local e = self:GetCurrent()
	if e and e.Luck then
		luck *= e.Luck
	end
	if now() < serverLuckUntil then
		luck *= SERVER_LUCK
	end
	return luck
end

function EventService:GetMutationBoosts()
	local e = self:GetCurrent()
	return e and e.Mutations or {}
end

function EventService:GetCashMultiplier(): number
	local e = self:GetCurrent()
	return e and e.Cash or 1
end

function EventService:GetSpawnRate(): number
	local e = self:GetCurrent()
	return e and e.SpawnRate or 1
end

function EventService:GetConveyorSpeed(): number
	local e = self:GetCurrent()
	return e and e.SpawnRate and 1.3 or 1
end

local function publish()
	local e = EventService:GetCurrent()
	workspace:SetAttribute("EventId", e and e.Id or "")
	workspace:SetAttribute("EventName", e and e.Name or "")
	workspace:SetAttribute("EventDescription", e and e.Description or "")
	workspace:SetAttribute("EventEnds", e and currentEnds or 0)
	workspace:SetAttribute("ServerLuckEnds", serverLuckUntil)
end

function EventService:StartEvent(id: string, duration: number?)
	local e = byId[id]
	if not e then
		return false
	end
	current = e
	currentEnds = now() + (duration or Config.EventDuration)
	publish()
	local S = self.Services
	S.ActionService:AlertAll(e.Name .. " COMEÇOU! " .. e.Description, Color3.fromRGB(255, 220, 80))
	S.ActionService:EffectAll("Sound", { Name = "Event" })
	S.StateService:MarkAllDirty()
	return true
end

function EventService:StopEvent()
	current = nil
	currentEnds = 0
	publish()
	self.Services.StateService:MarkAllDirty()
end

-- ============ Produtos de servidor ============

function EventService:AddServerLuck(seconds: number, buyer: Player?)
	serverLuckUntil = math.max(serverLuckUntil, now()) + seconds
	publish()
	local who = buyer and buyer.DisplayName or "Alguém"
	self.Services.ActionService:AlertAll("🍀 " .. who .. " ativou SORTE x3 para o servidor inteiro!", Color3.fromRGB(120, 255, 120))
	self.Services.ActionService:EffectAll("Sound", { Name = "Event" })
end

function EventService:MeteorShower(buyer: Player?)
	local S = self.Services
	local who = buyer and buyer.DisplayName or "Alguém"
	S.ActionService:AlertAll("☄️ " .. who .. " comprou CHUVA DE METEOROS! CORRA!", Color3.fromRGB(255, 120, 40))
	S.ActionService:EffectAll("Sound", { Name = "Event" })
	task.spawn(function()
		local rng = Random.new()
		for _ = 1, 45 do
			-- mira perto de jogadores aleatórios (menos o comprador)
			local targets = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= buyer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
					table.insert(targets, p.Character.HumanoidRootPart.Position)
				end
			end
			local pos
			if #targets > 0 and rng:NextNumber() < 0.6 then
				pos = targets[rng:NextInteger(1, #targets)] + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
			else
				pos = Vector3.new(rng:NextNumber(-180, 180), 0, rng:NextNumber(-100, 100))
			end
			self:DropMeteor(Vector3.new(pos.X, 1, pos.Z), buyer)
			task.wait(0.45)
		end
	end)
end

function EventService:DropMeteor(target: Vector3, buyer: Player?)
	local S = self.Services
	local meteor = Instance.new("Part")
	meteor.Name = "Meteor"
	meteor.Shape = Enum.PartType.Ball
	meteor.Size = Vector3.new(6, 6, 6)
	meteor.Material = Enum.Material.Basalt
	meteor.Color = Color3.fromRGB(60, 40, 30)
	meteor.Anchored = true
	meteor.CanCollide = false
	meteor.CanQuery = false
	meteor.CanTouch = false
	local fire = Instance.new("Fire")
	fire.Size = 10
	fire.Heat = 15
	fire.Parent = meteor
	local startPos = target + Vector3.new(40, 160, 20)
	meteor.Position = startPos
	meteor.Parent = workspace
	S.ActionService:EffectAll("MeteorWarning", { Position = target, Time = 1.2 })
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 1.2 do
			local a = (os.clock() - t0) / 1.2
			meteor.Position = startPos:Lerp(target, a)
			task.wait()
		end
		meteor:Destroy()
		local boom = Instance.new("Explosion")
		boom.Position = target
		boom.BlastRadius = 10
		boom.BlastPressure = 0
		boom.DestroyJointRadiusPercent = 0
		boom.Parent = workspace
		Debris:AddItem(boom, 2)
		S.ActionService:EffectAll("Sound", { Name = "Explosion", Position = target })
		S.ActionService:EffectAll("Shake", { Position = target, Strength = 1 })
		for _, p in ipairs(Players:GetPlayers()) do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if p ~= buyer and root and (root.Position - target).Magnitude < 14 then
				local dir = (root.Position - target) * Vector3.new(1, 0, 1)
				dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
				S.GearService:HitPlayer(nil, p, dir * 70 + Vector3.new(0, 60, 0), 1.2)
			end
		end
	end)
end

function EventService:FreezeAll(buyer: Player?)
	local S = self.Services
	local who = buyer and buyer.DisplayName or "Alguém"
	S.ActionService:AlertAll("🧊 " .. who .. " CONGELOU TODO MUNDO!", Color3.fromRGB(120, 220, 255))
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= buyer then
			S.StealService:Interrupt(p, "Você foi congelado e soltou o dragão!")
			S.MovementService:Freeze(p, 8, "Ice")
		end
	end
	S.ActionService:EffectAll("Sound", { Name = "Freeze" })
end

function EventService:UnlockAll(buyer: Player?)
	local S = self.Services
	local who = buyer and buyer.DisplayName or "Alguém"
	S.BaseService:ForceOpenAll(buyer, 30)
	S.ActionService:AlertAll("🔓 " .. who .. " ABRIU TODAS AS BASES POR 30s! HORA DE ROUBAR!", Color3.fromRGB(255, 150, 40))
	S.ActionService:EffectAll("Sound", { Name = "Alarm" })
end

function EventService:Start()
	publish()
	while true do
		task.wait(Config.EventInterval)
		if not self:GetCurrent() and #Players:GetPlayers() > 0 then
			local e = self.Events[math.random(1, #self.Events)]
			self:StartEvent(e.Id)
			task.wait(Config.EventDuration)
			if current == e then
				self:StopEvent()
				self.Services.ActionService:NotifyAll(e.Name .. " terminou!", "info")
			end
		end
	end
end

return EventService
