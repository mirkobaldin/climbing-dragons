--!strict
-- Pulsanti per il telefono (solo con lo schermo touch): una colonna ordinata sul lato destro,
-- sopra al tasto salto di Roblox e lontana dal joystick. Sulla parete compaiono "Chiodo",
-- "Sgancia" e "Salta via"; a terra "Corri". Grandi (64 px) e distanziati.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Climbing = require(script.Parent.Climbing)
local ClientState = require(script.Parent.ClientState)
local Sprint = require(script.Parent.Sprint)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer

local MobileControls = {}

function MobileControls.start()
	if not UserInputService.TouchEnabled then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MobileControls"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local column = Theme.frame(gui, nil, 1)
	column.AnchorPoint = Vector2.new(1, 1)
	column.Position = UDim2.new(1, -18, 1, -190) -- sopra il tasto salto
	column.Size = UDim2.new(0, 64, 0, 3 * 72)
	local layout = Theme.list(column, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	local function round(text: string, color: Color3, order: number, onTap: () -> ()): TextButton
		local b = Instance.new("TextButton")
		b.LayoutOrder = order
		b.Size = UDim2.new(0, 64, 0, 64)
		b.BackgroundColor3 = Theme.BG
		b.BackgroundTransparency = 0.25
		b.Text = text
		b.TextColor3 = color
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.TextWrapped = true
		b.Parent = column
		Theme.corner(b, 32)
		Theme.stroke(b, color, 2, 0.3)
		b.Activated:Connect(onTap)
		return b
	end

	local run = round("Run", Theme.GOOD, 1, function() end)
	run.Activated:Connect(function()
		local on = Sprint.toggle()
		run.BackgroundColor3 = if on then Theme.GOOD else Theme.BG
		run.TextColor3 = if on then Theme.BG else Theme.GOOD
	end)
	local jumpOff = round("Jump off", Theme.ACCENT, 1, Climbing.jumpOff)
	local piton = round("Piton", Color3.fromRGB(200, 205, 215), 2, function() end)
	-- tenendo premuto compare il mirino sulla roccia, al rilascio il chiodo va dove punta
	local function isTap(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	piton.InputBegan:Connect(function(input)
		if isTap(input) then
			Climbing.aimBegin()
		end
	end)
	piton.InputEnded:Connect(function(input)
		if isTap(input) then
			Climbing.aimFinish()
		end
	end)
	local release = round("Unclip", Theme.BAD, 3, Climbing.releaseRope)

	RunService.Heartbeat:Connect(function()
		local climbing = ClientState.climbing
		run.Visible = not climbing
		jumpOff.Visible = climbing
		piton.Visible = climbing
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		release.Visible = root ~= nil and root:FindFirstChild("BelayRope") ~= nil
	end)
end

return MobileControls
