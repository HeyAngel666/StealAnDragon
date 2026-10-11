-- Gamepasses e Produtos (Robux). Processa compras com segurança (sem duplicar).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Monetization = require(Shared.Monetization)
local Dragons = require(Shared.Dragons)
local Format = require(Shared.Format)

local MonetizationService = {}
local owned = {} -- [player] = { [passKey] = true }
local IS_STUDIO = RunService:IsStudio()

function MonetizationService:GetOwnedPasses(player: Player)
	return owned[player] or {}
end

function MonetizationService:HasPass(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

function MonetizationService:LoadPasses(player: Player)
	local set = {}
	owned[player] = set
	local data = self.Services.DataService:Get(player)
	if IS_STUDIO and data then
		for key in pairs(data.TestPasses) do
			set[key] = true
		end
	end
	for _, pass in ipairs(Monetization.Passes) do
		if pass.Id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and has then
				set[pass.Key] = true
			end
		end
	end
end

-- Aplica os efeitos de um passe recém-comprado
function MonetizationService:GrantPass(player: Player, key: string)
	local S = self.Services
	owned[player] = owned[player] or {}
	if owned[player][key] then
		return
	end
	owned[player][key] = true
	local pass = Monetization.PassByKey[key]
	if key == "VIP" then
		player:SetAttribute("VIP", true)
	end
	S.BaseService:RefreshSlots(player)
	S.GearService:GiveTools(player)
	S.MovementService:Recompute(player)
	S.ActionService:Effect(player, "Sound", { Name = "Reward" })
	S.ActionService:Alert(player, "✅ Obrigado! Você ganhou: " .. pass.Name, Color3.fromRGB(255, 220, 80))
	S.ActionService:NotifyAll("💎 " .. player.DisplayName .. " comprou " .. pass.Name .. "!", "rare")
	S.StateService:MarkDirty(player)
end

function MonetizationService:PromptPass(player: Player, key: string)
	local S = self.Services
	local pass = Monetization.PassByKey[key]
	if not pass or self:HasPass(player, key) then
		return
	end
	if pass.Id == 0 then
		if IS_STUDIO then
			local data = S.DataService:Get(player)
			data.TestPasses[key] = true
			S.ActionService:Notify(player, "[Studio] Compra simulada de " .. pass.Name, "info")
			self:GrantPass(player, key)
		else
			S.ActionService:Notify(player, "Em breve!", "info")
		end
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
end

-- Verifica antes de abrir a compra (ex.: base cheia para produto de dragão)
function MonetizationService:CanBuyProduct(player: Player, product): (boolean, string?)
	local S = self.Services
	if product.Kind == "Dragon" and not S.BaseService:FindFreeSlot(player) then
		return false, "Sua base está cheia! Libere um espaço antes."
	end
	return true, nil
end

function MonetizationService:PromptProduct(player: Player, key: string)
	local S = self.Services
	local product = Monetization.ProductByKey[key]
	if not product then
		return
	end
	local ok, reason = self:CanBuyProduct(player, product)
	if not ok then
		S.ActionService:Notify(player, reason, "error")
		return
	end
	if product.Id == 0 then
		if IS_STUDIO then
			S.ActionService:Notify(player, "[Studio] Compra simulada de " .. product.Name, "info")
			self:GrantProduct(player, product)
		else
			S.ActionService:Notify(player, "Em breve!", "info")
		end
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
end

function MonetizationService:GrantProduct(player: Player, product): boolean
	local S = self.Services
	local data = S.DataService:Get(player)
	if not data then
		return false
	end
	local kind = product.Kind
	if kind == "Cash" then
		local amount = product.Amount * (1 + data.Rebirths) ^ 2
		data.Cash += amount
		S.ActionService:Effect(player, "Sound", { Name = "Coin" })
		S.ActionService:Alert(player, "💰 +" .. Format.Cash(amount), Color3.fromRGB(120, 255, 120))
	elseif kind == "Dragon" then
		local def = Dragons.RandomOfRarity(product.Rarity)
		local uid = S.DragonService:Give(player, def.Id, "Normal")
		if not uid then
			-- sem espaço: compensa com dinheiro
			local amount = def.Price * 3
			data.Cash += amount
			S.ActionService:Notify(player, "Base cheia! Você recebeu " .. Format.Cash(amount) .. " no lugar do dragão.", "warning")
		else
			S.ActionService:Alert(player, "🐉 Você ganhou " .. def.Name .. "!", Color3.fromRGB(255, 200, 60))
			S.ActionService:Effect(player, "Confetti", {})
		end
	elseif kind == "Shield" then
		S.BaseService:AddShield(player, product.Seconds)
		S.ActionService:Alert(player, "🛡️ Escudo ativado por " .. math.floor(product.Seconds / 60) .. " minutos!", Color3.fromRGB(120, 200, 255))
	elseif kind == "ServerLuck" then
		S.EventService:AddServerLuck(product.Seconds, player)
	elseif kind == "Meteor" then
		S.EventService:MeteorShower(player)
	elseif kind == "FreezeAll" then
		S.EventService:FreezeAll(player)
	elseif kind == "UnlockAll" then
		S.EventService:UnlockAll(player)
	end
	S.StateService:MarkDirty(player)
	return true
end

function MonetizationService:Init()
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local data = self.Services.DataService:Get(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local product = Monetization.ProductById[receipt.ProductId]
		if not product then
			warn("[Monetization] Produto desconhecido:", receipt.ProductId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- já processado antes? (evita dar duas vezes)
		for _, id in ipairs(data.Purchases) do
			if id == receipt.PurchaseId then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		local ok, granted = pcall(self.GrantProduct, self, player, product)
		if not ok or not granted then
			warn("[Monetization] Falha ao entregar", product.Key, granted)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(data.Purchases, receipt.PurchaseId)
		while #data.Purchases > 50 do
			table.remove(data.Purchases, 1)
		end
		self.Services.DataService:Save(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local pass = Monetization.PassById[passId]
			if pass then
				self:GrantPass(player, pass.Key)
			end
		end
	end)
end

function MonetizationService:Start()
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			owned[player] = nil
		end)
	end)
end

return MonetizationService
