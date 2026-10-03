--!strict
-- Mirino sullo schermo (come su Blox Fruits): prende il posto della freccia del mouse e la segue
-- (al centro se il mouse e' bloccato; sul telefono al centro, solo con un attrezzo in mano).
-- Cambia colore secondo l'attrezzo che hai in mano:
--   Rampino    verde se il punto mirato e' a portata (Gear.GRAPPLE_RANGE), rosso se no; sotto
--              la distanza in metri
--   Piccozza   verde se c'e' una parete a cui aggrapparsi; bianco quando sei gia' attaccato
--   niente     bianco
-- Tasto X: acceso / spento.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClimbConfig = require(Shared:WaitForChild("ClimbConfig"))
local Gear = require(Shared:WaitForChild("Gear"))
local ClientState = require(script.Parent.ClientState)
local Climbing = require(script.Parent.Climbing)

local player = Players.LocalPlayer

local Crosshair = {}

local WHITE = Color3.fromRGB(245, 245, 245)
local GREEN = Color3.fromRGB(110, 235, 130)
local RED = Color3.fromRGB(240, 90, 80)
local CHECK_EVERY = 0.1 -- la parete vicina si cerca 10 volte al secondo (sono parecchi raggi)

local enabled = true

local function bar(parent: Instance, size: UDim2, pos: UDim2): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = pos
	f.BorderSizePixel = 0
	f.BackgroundColor3 = WHITE
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = f
	f.Parent = parent
	return f
end

function Crosshair.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Mirino"
	gui.IgnoreGuiInset = true -- le coordinate del mouse comprendono la barra in alto
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(40, 40)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	-- quattro tacche attorno al punto, con uno spazio in mezzo
	local LONG, THICK, GAP = 11, 3, 6
	local parts = {
		bar(holder, UDim2.fromOffset(THICK, LONG), UDim2.new(0.5, 0, 0.5, -(GAP + LONG / 2))),
		bar(holder, UDim2.fromOffset(THICK, LONG), UDim2.new(0.5, 0, 0.5, GAP + LONG / 2)),
		bar(holder, UDim2.fromOffset(LONG, THICK), UDim2.new(0.5, -(GAP + LONG / 2), 0.5, 0)),
		bar(holder, UDim2.fromOffset(LONG, THICK), UDim2.new(0.5, GAP + LONG / 2, 0.5, 0)),
		bar(holder, UDim2.fromOffset(4, 4), UDim2.fromScale(0.5, 0.5)),
	}
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 1, 2)
	label.Size = UDim2.fromOffset(90, 16)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Parent = holder

	local function setColor(c: Color3)
		for _, p in parts do
			p.BackgroundColor3 = c
		end
		label.TextColor3 = c
	end

	local function apply()
		gui.Enabled = enabled
		-- su PC il mirino fa da cursore: la freccia sparisce
		UserInputService.MouseIconEnabled = not (enabled and UserInputService.MouseEnabled)
	end
	apply()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.X then
			return
		end
		enabled = not enabled
		apply()
		ClientState.hint = if enabled then "Mirino acceso (X per spegnerlo)" else "Mirino spento (X per riaccenderlo)"
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local lastCheck = 0
	local wallNear = false

	RunService.RenderStepped:Connect(function()
		if not enabled then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local tool = character and character:FindFirstChildWhichIsA("Tool")
		local toolName = tool and tool.Name or ""
		local camera = workspace.CurrentCamera
		local mouse = UserInputService.MouseEnabled
		local at = if mouse then UserInputService:GetMouseLocation() else camera.ViewportSize / 2
		holder.Position = UDim2.fromOffset(at.X, at.Y)
		-- sul telefono serve solo per mirare con un attrezzo
		holder.Visible = mouse or toolName == "Rampino" or toolName == ClimbConfig.TOOL_NAME
		label.Text = ""

		if toolName == "Rampino" and root then
			local ray = camera:ViewportPointToRay(at.X, at.Y)
			params.FilterDescendantsInstances = { character :: Instance, camera }
			local reach = Gear.GRAPPLE_RANGE + (camera.CFrame.Position - root.Position).Magnitude
			local hit = workspace:Raycast(ray.Origin, ray.Direction * (reach + 400), params)
			if hit then
				local dist = (hit.Position - root.Position).Magnitude
				local ok = dist <= Gear.GRAPPLE_RANGE
				setColor(if ok then GREEN else RED)
				label.Text = string.format("%d m", math.floor(dist))
			else
				setColor(RED)
			end
		elseif toolName == ClimbConfig.TOOL_NAME then
			if Climbing.isClimbing() then
				setColor(WHITE)
			else
				if os.clock() - lastCheck > CHECK_EVERY then
					lastCheck = os.clock()
					wallNear = Climbing.wallInReach()
				end
				setColor(if wallNear then GREEN else WHITE)
			end
		else
			setColor(WHITE)
		end
	end)
end

return Crosshair
