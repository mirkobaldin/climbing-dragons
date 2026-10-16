--!strict
-- Tutorial "visivo": quando il passo del tutorial o della missione chiede di premere un pulsante
-- del menu ({UI:Store}, {UI:Crafting}, {UI:Dragons} nel testo, UiView.hintButton), quel pulsante
-- lampeggia con un anello dorato e una manina che lo indica. Per i bambini: si vede cosa
-- premere senza leggere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiView"))

local Theme = require(script.Parent.Theme)
local ClientState = require(script.Parent.ClientState)
-- comando da accendere per l'obiettivo (client/HUD: ClientState.tutorialFocus, dopo qualche
-- secondo senza riuscirci): casella della barra o pulsante del telefono
local FOCUS = {
	KEY1 = { hud = "Casella1" }, KEY2 = { hud = "Casella2" },
	PITON = { touch = "Piton" }, UNCLIP = { touch = "Release" }, CLIMB = { touch = "Climb" },
	MINE = { touch = "Mine" }, JUMP = { touch = "JumpOff" }, RIDE = { touch = "Ride" }, FIRE = { touch = "Shoot" },
} :: { [string]: { hud: string?, touch: string? } }
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
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ACCENT
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
	Theme.fitText(hand, 20, false)

	RunService.RenderStepped:Connect(function()
		local text = player:GetAttribute("TutorialText") or player:GetAttribute("MissionText")
		local name = if type(text) == "string" then Ui.hintButton(text) else nil
		-- menu unico (client/MainMenu): chiuso -> lampeggia l'apri-menu (ApriMenu); aperto -> la scheda
		-- da premere, finche' la sua pagina non e' aperta
		local menu = player.PlayerGui:FindFirstChild("MainMenu")
		local menuOpen = menu ~= nil and menu:GetAttribute("MenuOpen") == true
		local btn: Instance? = nil
		if menu and name then
			if not menuOpen then
				btn = menu:FindFirstChild("ApriMenu")
			else
				local window = menu:FindFirstChild("Window")
				local content = window and window:FindFirstChild("Content", true) -- (dentro lo Scorrimento)
				local pageFrame = content and content:FindFirstChild(name)
				if not (pageFrame and pageFrame:IsA("GuiObject") and pageFrame.Visible) then
					btn = window and window:FindFirstChild("Tab_" .. name)
				end
			end
		end
		-- niente pulsante del menu da premere: il comando dell'obiettivo, se ce n'e' uno a schermo
		local focusKey = (ClientState :: any).tutorialFocus
		local control = false
		if not btn and type(focusKey) == "string" and FOCUS[focusKey] and not menuOpen then
			local f = FOCUS[focusKey]
			if f.hud then
				local hud = player.PlayerGui:FindFirstChild("ClimbHUD")
				-- la casella vera dell'attrezzo (la barra si puo' riordinare nello zaino)
				local hudName = f.hud :: string
				if focusKey == "KEY1" or focusKey == "KEY2" then
					local Hotbar = require(ReplicatedStorage.Shared.Hotbar)
					local ClimbConfig = require(ReplicatedStorage.Shared.ClimbConfig)
					local slot = table.find(Hotbar.current(player), if focusKey == "KEY1" then ClimbConfig.TOOL_NAME else ClimbConfig.PICKAXE_NAME)
					hudName = "Casella" .. tostring(slot or (if focusKey == "KEY1" then 1 else 2))
				end
				btn = hud and hud:FindFirstChild(hudName, true)
			elseif f.touch and Ui.touch() then
				local mobile = player.PlayerGui:FindFirstChild("MobileControls")
				btn = mobile and mobile:FindFirstChild(f.touch, true)
			end
			control = btn ~= nil
		end
		local show = btn ~= nil and btn:IsA("GuiObject") and btn.Visible
		ring.Visible = show
		-- la manina solo per il menu; sui comandi basta il bordo che pulsa piano (niente lampeggi)
		hand.Visible = show and not control
		if not show then
			return
		end
		local b = btn :: GuiObject
		local t = os.clock()
		local pulse = (math.sin(t * (if control then 3 else 6)) + 1) / 2
		local round = control and b:FindFirstChildOfClass("UICorner") ~= nil and (b:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius.Scale >= 0.45
		corner.CornerRadius = if round then UDim.new(0.5, 0) else UDim.new(0, 2)
		local size = math.max(b.AbsoluteSize.X, b.AbsoluteSize.Y)
		local center = b.AbsolutePosition + b.AbsoluteSize / 2 + game:GetService("GuiService"):GetGuiInset()
		ring.Position = UDim2.fromOffset(center.X, center.Y)
		local grow = if control then 6 else -8
		ring.Size = UDim2.fromOffset(math.max(1, b.AbsoluteSize.X + grow), math.max(1, b.AbsoluteSize.Y + grow))
		stroke.Thickness = if control then 3 else 5
		stroke.Transparency = if control then 0.15 + pulse * 0.45 else pulse * 0.5
		-- la manina sopra il pulsante, che va su e giu'
		hand.Size = UDim2.fromOffset(22, 22)
		hand.Position = UDim2.fromOffset(center.X + b.AbsoluteSize.X / 2 - 16, center.Y + 3)
	end)
end

return TutorialHints
