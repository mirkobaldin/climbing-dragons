--!strict
-- La "sensazione" dell'arrampicata: senza questo la salita e' a velocita' costante e sembra
-- un ascensore. Qui stanno le cose che si sentono ma non cambiano le regole del gioco:
--   * scossa della camera a ogni trazione, all'aggancio e quando si scivola
--   * scintille di roccia dove la piccozza morde la parete
--   * vignetta rossa che pulsa quando la stamina sta finendo
--   * leggera apertura del campo visivo mentre scali (si vede piu' parete)
-- La camera si muove con Humanoid.CameraOffset, cosi' non litiga con la camera di Roblox.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ClientState = require(script.Parent.ClientState)
local ClimbConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ClimbConfig"))

local player = Players.LocalPlayer

local ClimbFeel = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- scossa in corso: ampiezza che si spegne da sola
local shake = Vector3.zero
local shakeDecay = 8
local vignette: Frame? = nil

-- Piccola scossa: dir e' la direzione in cui spingere la camera (spazio della camera)
function ClimbFeel.kick(strength: number, dir: Vector3?)
	local d = dir or Vector3.new(0, -1, 0)
	shake += d * strength
	if shake.Magnitude > 2.2 then
		shake = shake.Unit * 2.2
	end
end

-- Scintille e schegge dove la piccozza entra nella roccia
-- Colpo di piccozza: uno dei suoni a caso, tono leggermente diverso ogni volta (cosi' non
-- sembra un suono ripetuto). Il ghiaccio (colore passato) suona piu' acuto.
local function axeSound(position: Vector3, icy: boolean, loud: number)
	local list = ClimbConfig.SFX_AXE_ROCK
	if #list == 0 then
		return
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = list[math.random(1, #list)]
	s.Volume = 0.35 + 0.35 * loud
	s.PlaybackSpeed = (if icy then 1.25 else 1) * (0.9 + math.random() * 0.25)
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 120
	s.Parent = a
	s:Play()
	Debris:AddItem(a, 2)
end

function ClimbFeel.impact(position: Vector3, normal: Vector3, color: Color3?, amount: number?)
	axeSound(position, color ~= nil, math.clamp((amount or 5) / 10, 0, 1))
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.lookAt(position + normal * 0.3, position + normal * 2)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Color = ColorSequence.new(color or Color3.fromRGB(215, 205, 190))
	e.Size = NumberSequence.new(0.28, 0)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Lifetime = NumberRange.new(0.25, 0.55)
	e.Speed = NumberRange.new(5, 12)
	e.SpreadAngle = Vector2.new(55, 55)
	e.Acceleration = Vector3.new(0, -45, 0)
	e.EmissionDirection = Enum.NormalId.Front
	e.Rate = 0
	e.LightEmission = 0.4
	e.Parent = p
	e:Emit(amount or 6)
	Debris:AddItem(p, 1.2)
end

function ClimbFeel.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClimbFeel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")

	local v = Instance.new("Frame")
	v.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
	v.BackgroundTransparency = 1
	v.Size = UDim2.fromScale(1, 1)
	v.Visible = false
	v.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	grad.Parent = v
	vignette = v

	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		-- la scossa si spegne
		shake = shake:Lerp(Vector3.zero, math.min(1, dt * shakeDecay))
		local sway = Vector3.zero
		if ClientState.climbing then
			-- respiro lento del corpo appeso alla parete
			local t = os.clock()
			sway = Vector3.new(math.sin(t * 1.6) * 0.09, math.sin(t * 2.3) * 0.07, 0)
		end
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(shake + sway, math.min(1, dt * 18))

		-- campo visivo: un filo piu' aperto mentre scali (si vede piu' parete)
		ClientState.fovOffset = if ClientState.climbing then 6 else 0

		-- stamina agli sgoccioli: vignetta rossa che pulsa
		local ratio = ClientState.stamina / 100
		local low = ClientState.climbing and ratio < 0.3
		v.Visible = low
		if low then
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * (6 + (0.3 - ratio) * 24))
			v.BackgroundTransparency = 0.45 + 0.35 * pulse + ratio
		end
	end)
end

return ClimbFeel
