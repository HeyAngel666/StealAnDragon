-- Entrada e saída de jogadores: carregar dados, dar base, nascer, salvar.

local Players = game:GetService("Players")

local PlayerService = {}
local ready = {}

function PlayerService:IsReady(player: Player): boolean
	return ready[player] == true
end

function PlayerService:SpawnCharacter(player: Player)
	if player.Parent then
		player:LoadCharacter()
	end
end

function PlayerService:OnCharacterAdded(player: Player, character: Model)
	local S = self.Services
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	S.MovementService:OnCharacter(player)
	task.defer(function()
		S.GearService:GiveTools(player)
	end)
	humanoid.Died:Connect(function()
		S.StealService:Interrupt(player, "Você morreu e o dragão voltou!")
		task.wait(3)
		if player.Parent and player.Character == character then
			self:SpawnCharacter(player)
		end
	end)
end

function PlayerService:OnPlayerAdded(player: Player)
	local S = self.Services
	S.StateService:SetupLeaderstats(player)

	local profile = S.DataService:Load(player)
	if not profile or not player.Parent then
		return
	end
	S.MonetizationService:LoadPasses(player)

	local base = S.BaseService:Assign(player)
	if not base then
		player:Kick("Servidor cheio, tente outro servidor.")
		return
	end

	player.CharacterAdded:Connect(function(character)
		self:OnCharacterAdded(player, character)
	end)

	S.DragonService:OnPlayerAdded(player)
	S.DragonService:LoadAll(player)
	S.RewardService:OnPlayerReady(player)
	ready[player] = true

	if S.MonetizationService:HasPass(player, "VIP") then
		player:SetAttribute("VIP", true)
	end
	self:SpawnCharacter(player)
	S.StateService:Push(player)

	if not profile.CanSave then
		S.ActionService:Notify(player, "⚠️ Seus dados não serão salvos nesta sessão (DataStore indisponível).", "warning")
	end
end

-- Chamado antes de salvar ao fechar o servidor
function PlayerService:BeforeSave(player: Player)
	local S = self.Services
	S.StealService:OnPlayerRemoving(player)
end

function PlayerService:OnPlayerRemoving(player: Player)
	local S = self.Services
	ready[player] = nil
	S.StealService:OnPlayerRemoving(player)
	S.LeaderboardService:SubmitPlayer(player)
	S.DragonService:ClearModels(player)
	S.BaseService:Free(player)
	S.DataService:Release(player)
end

function PlayerService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(self.OnPlayerAdded, self, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)

	-- quem cair do mapa volta pra base
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and root.Position.Y < -30 then
				local base = self.Services.BaseService:GetBaseOf(player)
				if base then
					player.Character:PivotTo(base.Model.Spawn.CFrame + Vector3.new(0, 4, 0))
				end
			end
		end
	end
end

return PlayerService
