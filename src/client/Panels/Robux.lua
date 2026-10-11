-- Janela: Loja VIP (gamepasses e produtos de Robux).

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Monetization)
local UI = require(script.Parent.Parent.Controllers.UI)

local Robux = {}
local passButtons = {}
local prices = {} -- [key] = preço real em Robux (vem do Roblox, já com preço regional)
local fetched = false

-- Busca o preço atual do item no Roblox (não fica escrito no código)
local function fetchPrice(id: number, infoType: Enum.InfoType): number?
	if id == 0 then
		return nil
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(id, infoType)
	end)
	if not ok then
		ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
	end
	if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
		return info.PriceInRobux
	end
	return nil
end

local function priceText(key: string): string
	local price = prices[key]
	return price and ("R$ " .. price) or "Comprar"
end

local CATEGORY_COLORS = {
	["Dinheiro"] = UI.Colors.Green,
	["Dragões"] = UI.Colors.Gold,
	["Proteção"] = UI.Colors.Blue,
	["Servidor"] = Color3.fromRGB(60, 200, 120),
	["Trollar"] = UI.Colors.Red,
}

local function card(parent, order, title, description, color, buttonText, onClick)
	local f = UI.frame({ Size = UDim2.fromOffset(212, 190), BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35), LayoutOrder = order, Parent = parent })
	UI.gradient(color:Lerp(Color3.new(0, 0, 0), 0.1), color:Lerp(Color3.new(0, 0, 0), 0.55)).Parent = f
	UI.label({ Text = title, Size = UDim2.new(1, -12, 0, 32), Position = UDim2.fromOffset(6, 6), MaxText = 22, Parent = f })
	UI.label({ Text = description, Size = UDim2.new(1, -16, 0, 84), Position = UDim2.fromOffset(8, 40), TextWrapped = true, MaxText = 15,
		TextColor3 = Color3.fromRGB(235, 235, 240), TextYAlignment = Enum.TextYAlignment.Top, Parent = f })
	local b = UI.button({ Text = buttonText, Color = UI.Colors.Green, Size = UDim2.new(1, -20, 0, 46), Position = UDim2.new(0, 10, 1, -54), Parent = f }, onClick)
	return f, b
end

function Robux:Build(App, content)
	self.App = App
	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = content })
	UI.list(tabs, 10, true)
	local pages = {}
	local function show(name)
		for n, page in pairs(pages) do
			page.Visible = n == name
		end
	end
	UI.button({ Text = "⭐ Passes", Color = UI.Colors.Gold, Size = UDim2.fromOffset(200, 42), Parent = tabs }, function()
		show("Passes")
	end)
	UI.button({ Text = "🛍️ Itens", Color = UI.Colors.Blue, Size = UDim2.fromOffset(200, 42), Parent = tabs }, function()
		show("Products")
	end)

	for _, name in ipairs({ "Passes", "Products" }) do
		local scroll = UI.scroll({ Size = UDim2.new(1, 0, 1, -54), Position = UDim2.fromOffset(0, 54), Visible = name == "Passes", Parent = content })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(212, 190), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = scroll })
		UI.padding(4).Parent = scroll
		pages[name] = scroll
	end

	for i, pass in ipairs(Monetization.Passes) do
		local _, b = card(pages.Passes, i, pass.Name, pass.Description, UI.Colors.Purple, "...", function()
			App:Send("PromptPass", pass.Key)
		end)
		passButtons[pass.Key] = { Button = b, Id = pass.Id }
	end
	for i, product in ipairs(Monetization.Products) do
		local color = CATEGORY_COLORS[product.Category] or UI.Colors.Blue
		local _, b = card(pages.Products, i, product.Name, "[" .. product.Category .. "] " .. product.Description, color, "...", function()
			App:Send("PromptProduct", product.Key)
		end)
		self.ProductButtons = self.ProductButtons or {}
		self.ProductButtons[product.Key] = { Button = b, Id = product.Id }
	end
end

-- Busca os preços ao abrir a loja pela primeira vez
function Robux:OnOpen()
	if fetched then
		return
	end
	fetched = true
	task.spawn(function()
		for key, info in pairs(passButtons) do
			prices[key] = fetchPrice(info.Id, Enum.InfoType.GamePass)
		end
		for key, info in pairs(self.ProductButtons or {}) do
			prices[key] = fetchPrice(info.Id, Enum.InfoType.Product)
			info.Button.Text = priceText(key)
		end
		if self.App.State then
			self:Update(self.App.State)
		end
	end)
end

function Robux:Update(state)
	for key, info in pairs(passButtons) do
		local owned = state.Passes[key]
		info.Button.Text = owned and "✔ Você tem" or priceText(key)
		UI.setButtonColor(info.Button, owned and UI.Colors.Gray or UI.Colors.Green)
	end
end

return Robux
