-- Rebirth: zera dinheiro, dragões e equipamentos comprados com dinheiro,
-- e dá multiplicador maior, mais espaços, trava mais longa e novos itens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Rebirths = require(Shared.Rebirths)
local Rarities = require(Shared.Rarities)
local Dragons = require(Shared.Dragons)
local Format = require(Shared.Format)

local RebirthService = {}

function RebirthService:Check(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return false, "Carregando..."
	end
	local nextEntry = Rebirths.List[data.Rebirths + 1]
	if not nextEntry then
		return false, "Você já está no Rebirth máximo!"
	end
	if data.Cash < nextEntry.Cash then
		return false, "Precisa de " .. Format.Cash(nextEntry.Cash)
	end
	if nextEntry.NeedRarity then
		local need = Rarities.Get(nextEntry.NeedRarity).Order
		local has = false
		for _, record in pairs(data.Dragons) do
			local def = Dragons.Get(record.Id)
			if def and Rarities.Get(def.Rarity).Order >= need then
				has = true
				break
			end
		end
		if not has then
			return false, "Precisa ter um dragão " .. Rarities.Get(nextEntry.NeedRarity).Name .. " ou melhor na base"
		end
	end
	return true, nil
end

function RebirthService:Rebirth(player: Player)
	local S = self.Services
	local ok, reason = self:Check(player)
	if not ok then
		S.ActionService:Notify(player, reason, "error")
		S.ActionService:Effect(player, "Sound", { Name = "Error" })
		return
	end
	if S.StealService:IsCarrying(player) then
		return
	end
	local data = S.DataService:Get(player)

	-- cancela roubos em andamento contra este jogador
	S.StealService:OnPlayerRemoving(player)
	S.DragonService:ClearModels(player)
	data.Dragons = {}
	data.Cash = Config.StartingCash
	data.Gear = {}
	data.Rebirths += 1

	S.BaseService:RefreshSlots(player)
	S.GearService:GiveTools(player)
	S.MovementService:Recompute(player)

	local entry = Rebirths.List[data.Rebirths]
	S.ActionService:Effect(player, "Sound", { Name = "Rebirth" })
	S.ActionService:Effect(player, "Confetti", {})
	S.ActionService:Alert(player, "🌟 REBIRTH " .. data.Rebirths .. "! Renda x" .. entry.Multiplier, Color3.fromRGB(255, 220, 80))
	S.ActionService:NotifyAll("🌟 " .. player.DisplayName .. " fez Rebirth " .. data.Rebirths .. "!", "rare")
	S.StateService:MarkDirty(player)
	task.spawn(S.DataService.Save, S.DataService, player)
end

return RebirthService
