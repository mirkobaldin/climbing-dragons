--!strict
-- Aspetto della valle dei gas tossici sul client: entrando lo schermo vira al blu-fucsia (i colori
-- del drago Gas), la nebbia si infittisce (WeatherFX legge ClientState.gas) e la vista si
-- appanna un poco. Con un drago Gas al seguito l'effetto e' leggero: lui il gas lo respira.
-- La zona arriva dagli attributi del Workspace (GasCenter, GasRadius, GasTop) scritti dal
-- generatore della mappa.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local GasFX = {}

local TINT = Color3.fromRGB(200, 185, 255)

local function amount(pos: Vector3): number
	local center = workspace:GetAttribute("GasCenter")
	local radius = workspace:GetAttribute("GasRadius")
	local top = workspace:GetAttribute("GasTop")
	if typeof(center) ~= "Vector3" or type(radius) ~= "number" or type(top) ~= "number" then
		return 0
	end
	-- il colore si vede gia' un po' prima di entrare e poco sopra l'orlo
	local above = math.clamp((pos.Y - top) / 40, 0, 1)
	local d = Vector2.new(pos.X - center.X, pos.Z - center.Z).Magnitude
	return (1 - math.clamp((d - radius * 0.7) / (radius * 0.5), 0, 1)) * (1 - above)
end

function GasFX.start()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "GasTossico"
	cc.Enabled = false
	cc.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "GasTossicoBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting
	local smooth = 0
	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local target = if camera then amount(camera.CFrame.Position) else 0
		smooth += (target - smooth) * math.min(1, dt * 1.5)
		ClientState.gas = smooth
		local immune = DragonConfig.hasAbility(player, "Gas")
		local k = smooth * (if immune then 0.4 else 1)
		cc.Enabled = k > 0.01
		cc.TintColor = Color3.new(1, 1, 1):Lerp(TINT, k)
		cc.Saturation = 0.15 * k
		cc.Contrast = 0.08 * k
		blur.Enabled = not immune and k > 0.05
		blur.Size = if immune then 0 else 4 * k
	end)
end

return GasFX
