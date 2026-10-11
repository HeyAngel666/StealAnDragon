-- Inicializa todos os serviços do servidor na ordem certa.

local Services = {}
local folder = script.Parent:WaitForChild("Services")

local ORDER = {
	"MapService",
	"DataService",
	"StateService",
	"MovementService",
	"BaseService",
	"DragonService",
	"ConveyorService",
	"StealService",
	"GearService",
	"RebirthService",
	"MonetizationService",
	"EventService",
	"RewardService",
	"LeaderboardService",
	"AdminService",
	"ActionService",
	"PlayerService",
}

for _, name in ipairs(ORDER) do
	local module = require(folder:WaitForChild(name))
	module.Services = Services
	Services[name] = module
end

for _, name in ipairs(ORDER) do
	local service = Services[name]
	if service.Init then
		service:Init()
	end
end

for _, name in ipairs(ORDER) do
	local service = Services[name]
	if service.Start then
		task.spawn(function()
			service:Start()
		end)
	end
end

print("[Roube um Dragão] Servidor iniciado!")
