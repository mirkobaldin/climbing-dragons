--!strict
-- Corsa: tieni premuto Shift (o L3 sul gamepad) per correre. Consuma stamina; a zero si torna
-- a camminare finche' non la recuperi un po'. La visuale si allarga leggermente mentre corri.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClimbConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClimbConfig"))
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local Sprint = {}

local wantsSprint = false
local exhausted = false
local BASE_FOV = 70

-- Pulsante "Corri" del telefono: premi per correre, premi di nuovo per camminare
function Sprint.toggle(): boolean
	wantsSprint = not wantsSprint
	return wantsSprint
end

function Sprint.start()
	ContextActionService:BindAction("Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			wantsSprint = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			wantsSprint = false
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)

	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			ClientState.sprinting = false
			return
		end
		if ClientState.stamina <= 0 then
			exhausted = true
			ClientState.hint = "Senza fiato!"
		elseif ClientState.stamina > 25 then
			exhausted = false
		end
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local sprinting = wantsSprint and moving and not exhausted and not ClientState.climbing
		ClientState.sprinting = sprinting
		if not ClientState.climbing then
			local base = ClientState.speedOverride or ClimbConfig.WALK_SPEED
			humanoid.WalkSpeed = if sprinting then base * ClimbConfig.SPRINT_SPEED / ClimbConfig.WALK_SPEED else base
		end
		if sprinting and grounded then
			ClientState.stamina = math.max(0, ClientState.stamina - ClimbConfig.SPRINT_DRAIN / ClientState.regenBoost * dt)
		end
		local camera = workspace.CurrentCamera
		if camera then
			local target = (if sprinting then ClimbConfig.SPRINT_FOV else BASE_FOV) + ClientState.fovOffset
			camera.FieldOfView += (target - camera.FieldOfView) * math.min(1, dt * 8)
		end
	end)
end

return Sprint
