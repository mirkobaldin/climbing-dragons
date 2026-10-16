--!strict
-- Pannello "Controls": i comandi essenziali per il dispositivo in uso (computer, telefono,
-- gamepad), presi dalle associazioni vere degli script (Climbing: F chiodo, R sgancia, E/clic
-- aggrappati; Abilities: Q lancio; Combat: Z speciale; DragonRide: H; Sprint: Shift; HUD 1-5;
-- MainMenu: G B T N I U M). Si apre da solo all'inizio del tutorial (una volta) e poi col
-- pulsante "?" accanto a HIDE HUD (o F1). Se cambi dispositivo (prendi il gamepad, tocchi lo
-- schermo) i testi cambiano.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local Shared = RS:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("UiView"))
local Hotbar = require(Shared:WaitForChild("Hotbar"))
local ClimbConfig = require(Shared:WaitForChild("ClimbConfig"))
local UiKit = require(script.Parent.UiKit)
local player = Players.LocalPlayer

local ControlsPanel = {}

-- slot della barra dove sta un attrezzo (cambia se il giocatore lo sposta nello zaino)
local function slotOf(name: string): string
	local i = table.find(Hotbar.current(player), name)
	return if i then tostring(i) else "?"
end

type Row = { what: string, pc: string, touch: string, pad: string }
local function rows(): { Row }
	local axe, pick = slotOf(ClimbConfig.TOOL_NAME), slotOf(ClimbConfig.PICKAXE_NAME)
	return {
		{ what = "Move / look", pc = "W A S D  ·  right mouse", touch = "Left stick  ·  drag the screen", pad = "Left stick  ·  right stick" },
		{ what = "Jump", pc = "Space", touch = "JUMP", pad = "A" },
		{ what = "Sprint", pc = "Shift", touch = "RUN", pad = "L3" },
		{ what = "Ice axes (climbing tool)", pc = "[" .. axe .. "]", touch = "Slot " .. axe .. " in the bar", pad = "Slot " .. axe },
		{ what = "Grab a wall / let go", pc = "Click the rock or E", touch = "CLIMB", pad = "R2" },
		{ what = "Climb up / down", pc = "W / S on the wall", touch = "Stick up / down", pad = "Stick up / down" },
		{ what = "Jump off the wall", pc = "Space", touch = "JUMP OFF", pad = "A" },
		{ what = "Piton: aim, then place", pc = "Hold F, release on green", touch = "Hold PITON, release on green", pad = "Hold X, release on green" },
		{ what = "Unclip + take piton back", pc = "R (near the piton)", touch = "UNCLIP (near the piton)", pad = "Y (near the piton)" },
		{ what = "Pickaxe: mine ore", pc = "[" .. pick .. "], click the shiny rock", touch = "Slot " .. pick .. ", then MINE", pad = "Slot " .. pick .. ", then R2" },
		{ what = "Throw ice axe", pc = "Q", touch = "THROW", pad = "—" },
		{ what = "Dragon special", pc = "Z", touch = "Round dragon button", pad = "Y" },
		{ what = "Ride your dragon", pc = "H", touch = "RIDE", pad = "H" },
		{ what = "Paraglider", pc = "Space while falling", touch = "GLIDE", pad = "A while falling" },
		{ what = "Menu", pc = "M  (G B T N I U for each page)", touch = "MENU button next to the bar", pad = "Menu button" },
	}
end

function ControlsPanel.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PannelloComandi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local shade = Instance.new("TextButton") -- tocco fuori dal pannello = chiudi
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = gui
	local panel = Instance.new("Frame")
	panel.Name = "Pannello"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Parent = gui
	UiKit.panel(panel, { transparency = 0.04 })
	local title = UiKit.label(panel, "CONTROLS", "title", 28)
	local mode = UiKit.label(panel, "", "status")
	mode.TextColor3 = UiKit.ACCENT
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local close = Instance.new("TextButton")
	close.Parent = panel
	UiKit.button(close, "primary")
	close.Text = "GOT IT"

	local function render()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local m = Ui.inputMode()
		mode.Text = if m == "touch" then "TOUCH SCREEN" elseif m == "pad" then "GAMEPAD" else "KEYBOARD AND MOUSE"
		for i, r in rows() do
			local row = Instance.new("Frame")
			row.LayoutOrder = i
			row.BackgroundColor3 = UiKit.RAISED
			row.BackgroundTransparency = if i % 2 == 0 then 0.4 else 0.15
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, -6, 0, if UiKit.compact then 24 else 30)
			row.Parent = list
			local what = UiKit.label(row, r.what, "body", if UiKit.compact then 13 else 15)
			what.Position = UDim2.fromOffset(10, 0)
			what.Size = UDim2.new(0.48, -10, 1, 0)
			what.TextColor3 = UiKit.TEXT
			local key = UiKit.label(row, if m == "touch" then r.touch elseif m == "pad" then r.pad else r.pc, "name", if UiKit.compact then 14 else 16)
			key.Position = UDim2.new(0.48, 0, 0, 0)
			key.Size = UDim2.new(0.52, -10, 1, 0)
			key.TextColor3 = UiKit.ACCENT
			key.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
	Ui.viewportChanged(function(vp)
		local logical = Ui.fitScale(gui, vp)
		local compact = Ui.compact(vp)
		local w = math.min(620, logical.X - 24)
		local h = math.min(560, logical.Y - 16)
		Ui.px(panel, 0.5, 0, 0.5, 0, w, h, 0.5, 0.5)
		Ui.px(title, 0, 16, 0, 6, w - 32, if compact then 30 else 40)
		Ui.px(mode, 0, 16, 0, if compact then 34 else 44, w - 32, 18)
		local top = if compact then 56 else 70
		local btnH = if compact then 36 else 46
		Ui.px(list, 0, 12, 0, top, w - 24, h - top - btnH - 20)
		Ui.px(close, 0.5, 0, 1, -10, 200, btnH, 0.5, 1)
		if gui.Enabled then
			render()
		end
	end)
	local function open(on: boolean)
		gui.Enabled = on
		if on then
			render()
		end
	end
	ControlsPanel.open = open
	close.Activated:Connect(function()
		open(false)
	end)
	shade.Activated:Connect(function()
		open(false)
	end)
	UIS.LastInputTypeChanged:Connect(function()
		if gui.Enabled then
			render()
		end
	end)
	CAS:BindAction("PannelloComandi", function(_, state)
		if state == Enum.UserInputState.Begin then
			open(not gui.Enabled)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F1)
	-- all'inizio del tutorial, una volta per partita: prima di tutto, i comandi
	task.spawn(function()
		for _ = 1, 40 do
			local step = player:GetAttribute("TutorialStep")
			if type(step) == "number" then
				if step == 1 then
					task.wait(2)
					open(true)
				end
				return
			end
			task.wait(0.5)
		end
	end)
end

-- (impostata da start)
ControlsPanel.open = function(_: boolean) end

return ControlsPanel
