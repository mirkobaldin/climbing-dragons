--!strict
-- Suona un effetto di SoundConfig: nel mondo (in un punto, si sente di piu' da vicino) o a
-- tutto schermo (senza punto). Tono leggermente diverso ogni volta, cosi' un colpo ripetuto non
-- sembra sempre lo stesso campione. Tutto locale.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundConfig = require(ReplicatedStorage.Shared.SoundConfig)

local Sfx = {}

-- name: voce di SoundConfig.SOUNDS; at: punto nel mondo (nil = suono "dell'interfaccia");
-- loud: moltiplica il volume
function Sfx.play(name: string, at: Vector3?, loud: number?)
	local def = SoundConfig.SOUNDS[name]
	if not def or #def.ids == 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.ids[math.random(1, #def.ids)]
	sound.Volume = def.volume * (loud or 1)
	sound.PlaybackSpeed = (def.speed or 1) * (0.93 + math.random() * 0.14)
	local holder: Instance
	if at then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = workspace.Terrain
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = def.range or 150
		holder = a
	else
		holder = sound
	end
	sound.Parent = if at then holder else SoundService
	sound:Play()
	-- si toglie quando ha finito (la durata e' nota solo dopo il caricamento)
	Debris:AddItem(holder, 6)
	sound.Ended:Connect(function()
		holder:Destroy()
	end)
end

return Sfx
