--!strict
-- Pozioni attive (shared/Items, attributi Boost_<tipo>): una piastrina per pozione con l'icona,
-- il nome e il tempo che resta ("x2 Coins 12:40"). Sotto il meteo, spostabile col ⚙ dell'HUD
-- (client/HudLayout, nome "Pozioni"). Sparisce quando non ce n'e' nessuna.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("UiView"))
local Items = require(Shared:WaitForChild("Items"))
local UiKit = require(script.Parent.UiKit)
local HudLayout = require(script.Parent.HudLayout)

local player = Players.LocalPlayer
local BoostBar = {}

-- l'icona della pozione che accende ogni potenziamento
local function potionOf(kind: string): Items.Item?
	for _, it in Items.LIST do
		if it.boost == kind then
			return it
		end
	end
	return nil
end

function BoostBar.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Pozioni"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")
	local box = Instance.new("Frame")
	box.Name = "Pozioni"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(190, 4 * 32)
	box.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = box
	type Row = { frame: Frame, text: TextLabel }
	local rows: { [string]: Row } = {}
	for i, kind in { "Coins", "HatchLuck", "ShinyLuck", "DropLuck" } do
		local def = potionOf(kind)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = UiKit.PANEL
		f.BackgroundTransparency = 0.2
		f.BorderSizePixel = 0
		f.Size = UDim2.new(1, 0, 0, 28)
		f.LayoutOrder = i
		f.Visible = false
		f.Parent = box
		UiKit.edge(f, if def then def.color else UiKit.ACCENT, 1, 0.3)
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Position = UDim2.fromOffset(4, 2)
		img.Size = UDim2.fromOffset(24, 24)
		img.Parent = f
		if def and not Ui.asset(img, def.icon) then
			Ui.asset(img, def.fallback)
		end
		local t = UiKit.label(f, "", "stat", 15)
		t.Position = UDim2.fromOffset(34, 0)
		t.Size = UDim2.new(1, -40, 1, 0)
		t.TextColor3 = if def then def.color else UiKit.TEXT
		rows[kind] = { frame = f, text = t }
	end
	HudLayout.register("Pozioni", box, "POTIONS")
	local lastVp: Vector2? = nil
	local function place()
		local vp = lastVp
		if not vp then
			return
		end
		local logical = Ui.fitScale(gui, vp)
		-- a destra sotto il meteo
		Ui.px(box, 0, logical.X - 204, 0, 190, 190, 4 * 32)
		HudLayout.place("Pozioni", box)
	end
	HudLayout.onChange(place)
	Ui.viewportChanged(function(vp)
		lastVp = vp
		place()
	end, gui)
	task.spawn(function()
		while gui.Parent do
			local any = false
			for kind, r in rows do
				local left = Items.boostLeft(player, kind)
				r.frame.Visible = left > 0 or HudLayout.editing()
				if left > 0 then
					any = true
					local s = math.ceil(left)
					r.text.Text = string.format("%s  %d:%02d", Items.BOOST_NAMES[kind] or kind, s // 60, s % 60)
				elseif HudLayout.editing() then
					r.text.Text = Items.BOOST_NAMES[kind] or kind
				end
			end
			local menu = player.PlayerGui:FindFirstChild("MainMenu")
			gui.Enabled = (any or HudLayout.editing()) and player:GetAttribute("SchiusaInCorso") ~= true
				and player:GetAttribute("HudNascosto") ~= true and not (menu and menu:GetAttribute("MenuOpen") == true)
			task.wait(1)
		end
	end)
end

return BoostBar
