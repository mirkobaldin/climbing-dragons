--!strict
-- Tutorial "visivo": quando il passo del tutorial o della missione chiede di premere un pulsante
-- del menu ({UI:Store}, {UI:Crafting}, {UI:Dragons} nel testo, UiView.hintButton), quel pulsante
-- lampeggia con un anello dorato e una manina che lo indica. Per i bambini: si vede cosa
-- premere senza leggere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiView"))

local TutorialHints = {}

function TutorialHints.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "SuggerimentiTutorial"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")
	local ring = Instance.new("Frame")
	ring.Name = "Anello"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 220, 80)
	stroke.Thickness = 5
	stroke.Parent = ring
	local hand = Instance.new("TextLabel")
	hand.Name = "Manina"
	hand.AnchorPoint = Vector2.new(0.5, 1)
	hand.BackgroundTransparency = 1
	hand.Size = UDim2.fromOffset(56, 56)
	hand.Font = Enum.Font.GothamBlack
	hand.TextScaled = true
	hand.Text = "👇"
	hand.Visible = false
	hand.Parent = gui

	RunService.RenderStepped:Connect(function()
		local text = player:GetAttribute("TutorialText") or player:GetAttribute("MissionText")
		local name = if type(text) == "string" then Ui.hintButton(text) else nil
		local menu = player.PlayerGui:FindFirstChild("MainMenu")
		local column = menu and menu:FindFirstChild("Column", true)
		local btn = column and name and column:FindFirstChild(name)
		local menuOpen = menu ~= nil and menu:GetAttribute("MenuOpen") == true
		local show = btn ~= nil and btn:IsA("GuiObject") and btn.Visible and not menuOpen
		ring.Visible = show
		hand.Visible = show
		if not show then
			return
		end
		local b = btn :: GuiObject
		local t = os.clock()
		local pulse = (math.sin(t * 6) + 1) / 2
		local size = math.max(b.AbsoluteSize.X, b.AbsoluteSize.Y)
		local center = b.AbsolutePosition + b.AbsoluteSize / 2 + game:GetService("GuiService"):GetGuiInset()
		ring.Position = UDim2.fromOffset(center.X, center.Y)
		ring.Size = UDim2.fromOffset(size * (1.1 + pulse * 0.25), size * (1.1 + pulse * 0.25))
		stroke.Transparency = pulse * 0.5
		-- la manina sopra il pulsante, che va su e giu'
		hand.Position = UDim2.fromOffset(center.X, center.Y - size * 0.55 + math.sin(t * 6) * 8)
	end)
end

return TutorialHints
