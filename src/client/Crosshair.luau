--!strict
-- Mirino sullo schermo (come su Blox Fruits), solo quando hai in mano il Rampino: prende il posto
-- della freccia del mouse e la segue (al centro se il mouse e' bloccato o sul telefono).
-- Verde se il punto mirato e' a portata (potenziamento "Rampino"), rosso se no, arancione su un
-- nemico agganciabile (potenziamento "Uncino"); sotto la distanza.
-- Tasto X: acceso / spento.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClimbConfig = require(Shared:WaitForChild("ClimbConfig"))
local UpgradeConfig = require(Shared:WaitForChild("UpgradeConfig"))
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local Crosshair = {}

local WHITE = Color3.fromRGB(245, 245, 245)
local GREEN = Color3.fromRGB(110, 235, 130)
local RED = Color3.fromRGB(240, 90, 80)
local ORANGE = Color3.fromRGB(255, 160, 40)

-- il punto colpito e' un nemico (o un drago volante)?
local function isFoe(inst: Instance): boolean
	for _, name in { "Nemici", "Volanti" } do
		local f = workspace:FindFirstChild(name)
		if f and inst:IsDescendantOf(f) then
			return true
		end
	end
	return false
end

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

	local shown = false
	-- su PC il mirino fa da cursore: mentre si vede, la freccia sparisce
	local function show(on: boolean)
		if on ~= shown then
			shown = on
			gui.Enabled = on
			UserInputService.MouseIconEnabled = not (on and UserInputService.MouseEnabled)
		end
	end
	gui.Enabled = false

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.X then
			return
		end
		enabled = not enabled
		ClientState.hint = if enabled then "Crosshair on (X to turn off)" else "Crosshair off (X to turn on)"
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local tool = character and character:FindFirstChildWhichIsA("Tool")
		show(enabled and tool ~= nil and tool.Name == ClimbConfig.GRAPPLE_NAME and root ~= nil)
		if not shown or not root then
			return
		end
		local camera = workspace.CurrentCamera
		local at = ClientState.aimPoint()
		holder.Position = UDim2.fromOffset(at.X, at.Y)
		label.Text = ""
		do
			local ray = camera:ViewportPointToRay(at.X, at.Y)
			params.FilterDescendantsInstances = { character :: Instance, camera }
			local range = UpgradeConfig.value(player, "Rampino", "range")
			local reach = range + (camera.CFrame.Position - root.Position).Magnitude
			local hit = workspace:Raycast(ray.Origin, ray.Direction * (reach + 400), params)
			if hit then
				local dist = (hit.Position - root.Position).Magnitude
				local ok = dist <= range
				local foe = ok and isFoe(hit.Instance)
				setColor(if foe then ORANGE elseif ok then GREEN else RED)
				label.Text = string.format("%d / %d m%s", math.floor(dist), range, if foe then "  STRIKE" else "")
			else
				setColor(RED)
			end
		end
	end)
end

return Crosshair
