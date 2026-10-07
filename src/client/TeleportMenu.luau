--!strict
-- Menu del teletrasporto (solo con lo Chalet, attributo HouseLevel 3): tasto T o il pulsante
-- a destra. Il server (Teleports) controlla e sposta il personaggio.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer

local TeleportMenu = {}

local NAMES = { "Base camp (hub)", "My camp", "Dragon training" }

function TeleportMenu.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Teleport", 30) :: RemoteEvent?
	if not remote then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Teletrasporto"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local open = Instance.new("TextButton")
	open.AnchorPoint = Vector2.new(1, 0.5)
	open.Position = UDim2.new(1, -12, 0.5, 0)
	open.Size = UDim2.fromOffset(120, 40)
	open.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
	open.BackgroundTransparency = 0.15
	open.Font = Enum.Font.GothamBold
	open.TextSize = 15
	open.TextColor3 = Color3.fromRGB(150, 220, 255)
	open.Text = "Teleport (T)"
	open.Parent = gui
	Instance.new("UICorner").Parent = open
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -140, 0.5, 0)
	panel.Size = UDim2.fromOffset(220, #NAMES * 44 + 12)
	panel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = gui
	Instance.new("UICorner").Parent = panel
	for k, name in NAMES do
		local b = Instance.new("TextButton")
		b.Position = UDim2.fromOffset(8, 8 + (k - 1) * 44)
		b.Size = UDim2.new(1, -16, 0, 38)
		b.BackgroundColor3 = Theme.GOOD or Color3.fromRGB(60, 140, 90)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 15
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = name
		b.Parent = panel
		Instance.new("UICorner").Parent = b
		b.Activated:Connect(function()
			panel.Visible = false
			;(remote :: RemoteEvent):FireServer(name)
		end)
	end
	local function refresh()
		open.Visible = true -- per tutti: il server dice cosa e' ancora bloccato
		if not open.Visible then
			panel.Visible = false
		end
	end
	refresh()
	player:GetAttributeChangedSignal("HouseLevel"):Connect(refresh)
	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	ContextActionService:BindAction("TeleportMenu", function(_, state)
		if state == Enum.UserInputState.Begin and open.Visible then
			panel.Visible = not panel.Visible
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.T)
end

return TeleportMenu
