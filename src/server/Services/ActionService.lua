-- Recebe os pedidos do cliente (com limite anti-spam) e envia mensagens/efeitos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ActionService = {}
local buckets = {} -- [player] = { tokens, last }

local function allow(player: Player): boolean
	local b = buckets[player]
	local t = os.clock()
	if not b then
		b = { Tokens = 10, Last = t }
		buckets[player] = b
	end
	b.Tokens = math.min(10, b.Tokens + (t - b.Last) * 8)
	b.Last = t
	if b.Tokens < 1 then
		return false
	end
	b.Tokens -= 1
	return true
end

-- ============ Mensagens para o cliente ============

function ActionService:Notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

function ActionService:NotifyAll(text: string, kind: string?)
	Remotes.Notify:FireAllClients(text, kind or "info")
end

function ActionService:Alert(player: Player, text: string, color: Color3?)
	Remotes.Alert:FireClient(player, text, color)
end

function ActionService:AlertAll(text: string, color: Color3?)
	Remotes.Alert:FireAllClients(text, color)
end

function ActionService:Effect(player: Player, name: string, data)
	Remotes.Effect:FireClient(player, name, data or {})
end

function ActionService:EffectAll(name: string, data)
	Remotes.Effect:FireAllClients(name, data or {})
end

-- ============ Pedidos do cliente ============

local handlers = {}

function handlers.BuyGear(S, player, gearId)
	if type(gearId) == "string" then
		S.GearService:Buy(player, gearId)
	end
end

function handlers.Rebirth(S, player)
	S.RebirthService:Rebirth(player)
end

function handlers.RedeemCode(S, player, code)
	if type(code) == "string" and #code <= 40 then
		S.RewardService:RedeemCode(player, code)
	end
end

function handlers.ClaimPlaytime(S, player, index)
	if type(index) == "number" then
		S.RewardService:ClaimPlaytime(player, index)
	end
end

function handlers.ClaimDaily(S, player)
	S.RewardService:ClaimDaily(player)
end

function handlers.PromptPass(S, player, key)
	if type(key) == "string" then
		S.MonetizationService:PromptPass(player, key)
	end
end

function handlers.PromptProduct(S, player, key)
	if type(key) == "string" then
		S.MonetizationService:PromptProduct(player, key)
	end
end

function handlers.SetSetting(S, player, key, value)
	local data = S.DataService:Get(player)
	if data and (key == "Music" or key == "Sfx") and type(value) == "boolean" then
		data.Settings[key] = value
		S.StateService:MarkDirty(player)
	end
end

function handlers.TutorialDone(S, player)
	local data = S.DataService:Get(player)
	if data then
		data.TutorialDone = true
		S.StateService:MarkDirty(player)
	end
end

function handlers.CollectAll(S, player)
	if S.BaseService:IsInOwnBase(player) then
		S.DragonService:CollectAll(player)
	end
end

function handlers.Admin(S, player, command, arg1, arg2)
	if type(command) == "string" then
		S.AdminService:Run(player, command, arg1, arg2)
	end
end

function ActionService:Start()
	Remotes.Action.OnServerEvent:Connect(function(player, action, ...)
		if type(action) ~= "string" or not allow(player) then
			return
		end
		local handler = handlers[action]
		if handler and self.Services.DataService:Get(player) then
			local ok, err = pcall(handler, self.Services, player, ...)
			if not ok then
				warn("[ActionService] Erro em", action, err)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return ActionService
