--!strict
-- Colpo di piccozza quando pianti un chiodo: muove il braccio destro (R15 o R6) scrivendo
-- Motor6D.Transform per 0.6 secondi, sopra l'animazione di arrampicata di Roblox.

local RunService = game:GetService("RunService")

local ClimbAnimator = {}

-- Articolazione: motore + come ruotarlo (R15: asse X; R6: asse Z)
type Joint = { motor: Motor6D, r6: boolean }
local motors: { [string]: Joint } = {}
local hammerUntil = 0
local connection: RBXScriptConnection? = nil

local function set(name: string, angle: number)
	local j = motors[name]
	if j then
		j.motor.Transform = if j.r6 then CFrame.Angles(0, 0, angle) else CFrame.Angles(angle, 0, 0)
	end
end

function ClimbAnimator.bind(character: Model)
	table.clear(motors)
	local upper = character:FindFirstChild("RightUpperArm")
	local lower = character:FindFirstChild("RightLowerArm")
	local torso = character:FindFirstChild("Torso") -- avatar R6
	local shoulder = upper and upper:FindFirstChild("RightShoulder")
	local elbow = lower and lower:FindFirstChild("RightElbow")
	if shoulder and shoulder:IsA("Motor6D") then
		motors.RightShoulder = { motor = shoulder, r6 = false }
	end
	if elbow and elbow:IsA("Motor6D") then
		motors.RightElbow = { motor = elbow, r6 = false }
	end
	local r6Shoulder = torso and torso:FindFirstChild("Right Shoulder")
	if r6Shoulder and r6Shoulder:IsA("Motor6D") then
		motors.RightShoulder = { motor = r6Shoulder, r6 = true }
	end
	if not connection then
		connection = RunService.Stepped:Connect(function()
			local left = hammerUntil - os.clock()
			if left > 0 then
				local swing = math.sin((1 - left / 0.6) * math.pi * 3)
				set("RightShoulder", math.rad(130) + swing * 0.6)
				set("RightElbow", 0.9 - swing * 0.5)
			end
		end)
	end
end

function ClimbAnimator.hammer()
	hammerUntil = os.clock() + 0.6
end

return ClimbAnimator
