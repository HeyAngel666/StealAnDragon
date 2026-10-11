-- Toca efeitos sonoros e a música de fundo (IDs em Shared/Sounds).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local SoundController = {}
local templates = {}
local music
local sfxEnabled = true

function SoundController:Init(App)
	self.App = App
	local folder = Instance.new("Folder")
	folder.Name = "GameSounds"
	folder.Parent = SoundService
	for name, info in pairs(Sounds) do
		if info.Id and info.Id ~= 0 then
			local s = Instance.new("Sound")
			s.Name = name
			s.SoundId = "rbxassetid://" .. info.Id
			s.Volume = info.Volume or 0.5
			s.Parent = folder
			templates[name] = s
		end
	end
	if templates.Music then
		music = templates.Music
		music.Looped = true
	end
end

function SoundController:Play(name: string, position: Vector3?)
	if not sfxEnabled then
		return
	end
	local template = templates[name]
	if not template or name == "Music" then
		return
	end
	if position then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(1, 1, 1)
		holder.Position = position
		holder.Parent = workspace
		local s = template:Clone()
		s.RollOffMaxDistance = 150
		s.Parent = holder
		s:Play()
		Debris:AddItem(holder, 5)
	else
		SoundService:PlayLocalSound(template)
	end
end

function SoundController:Start(App)
	App.StateChanged.Event:Connect(function(state)
		local settings = state.Settings or {}
		sfxEnabled = settings.Sfx ~= false
		if music then
			if settings.Music ~= false then
				if not music.IsPlaying then
					music:Play()
				end
			elseif music.IsPlaying then
				music:Stop()
			end
		end
	end)
end

return SoundController
