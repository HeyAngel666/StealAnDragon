-- Esteira central: dragões saem da caverna, andam até o portal e podem ser comprados.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Dragons = require(Shared.Dragons)
local Rarities = require(Shared.Rarities)
local Mutations = require(Shared.Mutations)
local Format = require(Shared.Format)
local DragonBuilder = require(Shared.DragonBuilder)

local ConveyorService = {}
local active = {} -- lista de { Model, Id, Mut, Price, Distance, Bought }
local rng = Random.new()
local folder

function ConveyorService:Init()
	folder = Instance.new("Folder")
	folder.Name = "ConveyorDragons"
	folder.Parent = workspace
end

function ConveyorService:PriceOf(dragonId: string, mutationId: string): number
	return math.floor(Dragons.Get(dragonId).Price * Mutations.Get(mutationId).Multiplier)
end

function ConveyorService:Spawn(forcedId: string?, forcedMutation: string?)
	local S = self.Services
	local dragonId = forcedId
	if not dragonId then
		local rarity = Dragons.RollRarity(S.EventService:GetLuck(), rng)
		dragonId = Dragons.RandomOfRarity(rarity, rng).Id
	end
	local mutationId = forcedMutation or Mutations.Roll(S.EventService:GetMutationBoosts(), rng)
	local def = Dragons.Get(dragonId)
	local rarity = Rarities.Get(def.Rarity)
	local mutation = Mutations.Get(mutationId)
	local price = self:PriceOf(dragonId, mutationId)

	local model = DragonBuilder.Build(dragonId, mutationId)
	local startCF = CFrame.lookAt(Layout.ConveyorStart, Layout.ConveyorStart + Vector3.new(1, 0, 0))
	model:PivotTo(startCF)

	local entry = { Model = model, Id = dragonId, Mut = mutationId, Price = price, Distance = 0, Bought = false }

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Comprar " .. Format.Cash(price)
	prompt.ObjectText = (mutation.Id ~= "Normal" and (mutation.Name .. " ") or "") .. def.Name .. " [" .. rarity.Name .. "]"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("PromptType", "Buy")
	prompt.Parent = model.Root.PromptAttachment
	prompt.Triggered:Connect(function(player)
		self:Buy(player, entry)
	end)

	-- placa com nome, raridade e preço
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(220, 80)
	gui.Adornee = model.Root
	gui.StudsOffsetWorldSpace = Vector3.new(0, (model:GetAttribute("Height") or 5) + 2, 0)
	gui.MaxDistance = 90
	gui.Parent = model.Root
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local function line(text, color, order, height)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, height, 0)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextStrokeTransparency = 0
		t.TextColor3 = color
		t.Text = text
		t.LayoutOrder = order
		t.Parent = gui
		return t
	end
	if mutation.Id ~= "Normal" then
		line(mutation.Name, mutation.Color, 0, 0.22)
	end
	line(def.Name, Color3.new(1, 1, 1), 1, 0.28)
	line(rarity.Name, rarity.Color, 2, 0.22)
	line(Format.Cash(price) .. "  •  " .. Format.Cash(def.Income * mutation.Multiplier) .. "/s", Color3.fromRGB(120, 255, 120), 3, 0.24)

	model.Parent = folder
	table.insert(active, entry)

	local prefix = mutation.Id ~= "Normal" and (mutation.Name .. " ") or ""
	if rarity.Order >= 5 or mutationId == "ArcoIris" then
		S.ActionService:AlertAll(string.format("✨ Um %s%s (%s) apareceu na esteira!", prefix, def.Name, rarity.Name), rarity.Color)
		S.ActionService:EffectAll("Sound", { Name = "Roar" })
	end
	return entry
end

function ConveyorService:Buy(player: Player, entry)
	local S = self.Services
	if entry.Bought or not entry.Model.Parent then
		return
	end
	local data = S.DataService:Get(player)
	if not data then
		return
	end
	if S.StealService:IsCarrying(player) then
		S.ActionService:Notify(player, "Você está carregando um dragão!", "error")
		return
	end
	if data.Cash < entry.Price then
		S.ActionService:Notify(player, "Dinheiro insuficiente! Faltam " .. Format.Cash(entry.Price - data.Cash), "error")
		S.ActionService:Effect(player, "Sound", { Name = "Error" })
		return
	end
	if not S.BaseService:FindFreeSlot(player) then
		S.ActionService:Notify(player, "Sua base está cheia! Venda um dragão ou faça Rebirth.", "error")
		S.ActionService:Effect(player, "Sound", { Name = "Error" })
		return
	end

	entry.Bought = true
	data.Cash -= entry.Price
	local mutationId = entry.Mut
	-- passe de Sorte: chance de subir a mutação
	if S.MonetizationService:HasPass(player, "Luck") and rng:NextNumber() < 0.3 then
		local up = Mutations.UpgradeChain[mutationId]
		if up then
			mutationId = up
			S.ActionService:Notify(player, "🍀 Sorte! Seu dragão virou " .. Mutations.Get(up).Name .. "!", "rare")
		end
	end
	local flyFrom = entry.Model:GetPivot()
	entry.Model:Destroy()
	S.DragonService:Give(player, entry.Id, mutationId, flyFrom)
	S.ActionService:Effect(player, "Sound", { Name = "Buy" })
	S.ActionService:Notify(player, "Você comprou " .. Dragons.Get(entry.Id).Name .. "!", "success")
	S.RewardService:OnTutorialEvent(player, "Bought")
	S.StateService:MarkDirty(player)
end

function ConveyorService:Start()
	local length = (Layout.ConveyorEnd - Layout.ConveyorStart).Magnitude
	local dir = (Layout.ConveyorEnd - Layout.ConveyorStart).Unit

	RunService.Heartbeat:Connect(function(dt)
		local speed = Config.ConveyorSpeed * self.Services.EventService:GetConveyorSpeed()
		for i = #active, 1, -1 do
			local entry = active[i]
			if entry.Bought or not entry.Model.Parent then
				table.remove(active, i)
			else
				entry.Distance += speed * dt
				if entry.Distance >= length then
					entry.Model:Destroy()
					table.remove(active, i)
				else
					local pos = Layout.ConveyorStart + dir * entry.Distance
					entry.Model:PivotTo(CFrame.lookAt(pos, pos + dir))
				end
			end
		end
	end)

	-- preenche a esteira no começo para não ficar vazia
	for i = 1, 12 do
		local entry = self:Spawn()
		entry.Distance = length * (i / 13)
	end

	while true do
		task.wait(Config.ConveyorSpawnInterval / self.Services.EventService:GetSpawnRate())
		if #active < Config.ConveyorMaxDragons and #Players:GetPlayers() > 0 then
			self:Spawn()
		end
	end
end

return ConveyorService
