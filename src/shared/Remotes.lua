-- Cria (servidor) ou encontra (cliente) os RemoteEvents usados no jogo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"State", -- servidor -> cliente: dados do jogador para a interface
	"Notify", -- servidor -> cliente: mensagem pequena
	"Alert", -- servidor -> cliente: mensagem grande no meio da tela
	"Effect", -- servidor -> cliente: efeitos visuais/sonoros
	"Action", -- cliente -> servidor: pedidos (comprar, rebirth, códigos...)
}

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(NAMES) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in ipairs(NAMES) do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
