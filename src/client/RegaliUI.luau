--!strict
-- Pacco dei regali del tempo di gioco nell'HUD (shared/RegaliConfig, server/Regali): medaglione
-- col pacco e il conto alla rovescia del prossimo regalo ("4:59", "READY!"), pallino col numero
-- dei regali pronti. Tocco/clic = pannello coi regali in fila: presi (spenti, ✓), pronti
-- (cornice verde, CLAIM), da aspettare (minuti). Sta a sinistra dei tasti ⚙ ? HIDE HUD e si
-- sposta come gli altri elementi (client/HudLayout, nome "Regali").
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("UiView"))
local RegaliConfig = require(Shared:WaitForChild("RegaliConfig"))
local UiKit = require(script.Parent.UiKit)
local Cornici = require(script.Parent.Cornici)
local HudLayout = require(script.Parent.HudLayout)

local player = Players.LocalPlayer
local RegaliUI = {}

local function fmt(sec: number): string
	local s = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- prossimo regalo da aspettare (indice, secondi che mancano) e quanti sono pronti
local function status(): (number?, number, number)
	local claimed = RegaliConfig.claimed(player)
	local t = RegaliConfig.elapsed(player)
	local ready = 0
	local nextIndex: number? = nil
	local wait = 0
	for i, g in RegaliConfig.GIFTS do
		if not claimed[i] then
			if t >= g.minutes * 60 then
				ready += 1
			elseif not nextIndex then
				nextIndex = i
				wait = g.minutes * 60 - t
			end
		end
	end
	return nextIndex, wait, ready
end

function RegaliUI.start()
	local hud = player:WaitForChild("PlayerGui"):WaitForChild("ClimbHUD", 60) :: ScreenGui?
	if not hud then
		return
	end
	local gui = hud :: ScreenGui

	-- PULSANTE: medaglione col pacco, tempo sotto, pallino dei pronti
	local box = Instance.new("Frame")
	box.Name = "Regali"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(64, 78)
	box.Parent = gui
	local button = Instance.new("TextButton")
	button.Name = "Pacco"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromOffset(52, 52)
	button.Position = UDim2.fromOffset(6, 0)
	button.ZIndex = 5
	button:SetAttribute("UiNative", true)
	button.Parent = box
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
	back.BorderSizePixel = 0
	back.AnchorPoint = Vector2.new(0.5, 0.5)
	back.Position = UDim2.fromScale(0.5, 0.5)
	back.Size = UDim2.fromScale(1.04, 1.04)
	back.ZIndex = 5
	back.Parent = button
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0.5, 0)
	bc.Parent = back
	if not Cornici.apply(button, "frame_currency_medallion", { mode = "circle", z = 7 }) then
		back.Size = UDim2.fromScale(1, 1)
		UiKit.edge(back, UiKit.ACCENT, 2, 0.2)
	end
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.66, 0.66)
	icon.ZIndex = 6
	icon.Parent = button
	if not Ui.asset(icon, "icon_gift") then
		icon.Visible = false
		local t = UiKit.label(button, "🎁", "stat", 24)
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.Size = UDim2.fromScale(1, 1)
		t.ZIndex = 6
	end
	local timer = UiKit.label(box, "", "stat", 15)
	timer.Name = "Tempo"
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.Position = UDim2.fromOffset(0, 54)
	timer.Size = UDim2.fromOffset(64, 20)
	timer.TextStrokeTransparency = 0.3
	timer.ZIndex = 6
	local dot = Instance.new("TextLabel")
	dot.Name = "Pronti"
	dot.BackgroundColor3 = Color3.fromRGB(235, 60, 60)
	dot.BorderSizePixel = 0
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromOffset(52, 6)
	dot.Size = UDim2.fromOffset(20, 20)
	dot.ZIndex = 9
	dot.Parent = box
	UiKit.text(dot, "stat", 13)
	dot.TextXAlignment = Enum.TextXAlignment.Center
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(0.5, 0)
	dc.Parent = dot
	HudLayout.register("Regali", box, "GIFTS")

	-- posto: a sinistra dei tasti ⚙ ? HIDE HUD (gruppo "Opzioni" dell'HUD), alla loro altezza
	local function place()
		local opts = gui:FindFirstChild("Opzioni") :: GuiObject?
		local su = gui:FindFirstChild("ScalaUI") :: UIScale?
		local k = if su and su.Scale > 0 then su.Scale else 1
		if opts and opts.AbsoluteSize.X > 0 then
			local left = (opts.AbsolutePosition.X - gui.AbsolutePosition.X) / k
			local midY = (opts.AbsolutePosition.Y - gui.AbsolutePosition.Y + opts.AbsoluteSize.Y / 2) / k
			box.AnchorPoint = Vector2.new(1, 0)
			box.Position = UDim2.fromOffset(left - 10, midY - 26)
		else
			box.AnchorPoint = Vector2.new(1, 0)
			box.Position = UDim2.new(1, -460, 0, 8)
		end
		HudLayout.place("Regali", box)
	end
	HudLayout.onChange(place)
	task.spawn(function()
		local opts = gui:WaitForChild("Opzioni", 30) :: GuiObject?
		if opts then
			opts:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
			opts:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		end
		place()
	end)

	-- PANNELLO coi regali
	local panelGui = Instance.new("ScreenGui")
	panelGui.Name = "PannelloRegali"
	panelGui.ResetOnSpawn = false
	panelGui.IgnoreGuiInset = false
	panelGui.DisplayOrder = 40
	panelGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	panelGui.Enabled = false
	panelGui.Parent = player.PlayerGui
	local veil = Instance.new("TextButton")
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0.45
	veil.Size = UDim2.fromScale(1, 1)
	veil.Parent = panelGui
	local panel = Instance.new("Frame")
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(760, 300)
	panel.Active = true
	panel.ZIndex = 2
	panel.Parent = panelGui
	UiKit.panel(panel, { border = 12 })
	local title = UiKit.label(panel, "PLAYTIME GIFTS", "title", 28)
	title.TextColor3 = UiKit.ACCENT
	title.Position = UDim2.fromOffset(28, 18)
	title.Size = UDim2.new(1, -170, 0, 36)
	title.ZIndex = 3
	local sub = UiKit.label(panel, "Stay in the game to unlock them. They start again every time you join.", "body", 15)
	sub.Position = UDim2.fromOffset(28, 56)
	sub.Size = UDim2.new(1, -56, 0, 22)
	sub.ZIndex = 3
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -22, 0, 18)
	close.Size = UDim2.fromOffset(110, 42)
	close.ZIndex = 4
	close.Parent = panel
	UiKit.button(close, "secondary")
	close.Text = "CLOSE"
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(24, 94)
	row.Size = UDim2.new(1, -48, 1, -116)
	row.ZIndex = 3
	row.Parent = panel
	local n = #RegaliConfig.GIFTS
	type Cell = { slot: TextButton, when: TextLabel, what: TextLabel, action: TextButton }
	local cells: { Cell } = {}
	local function claim(i: number)
		local ok, message = (RS.Remotes:WaitForChild("Regali") :: RemoteFunction):InvokeServer("claim", i)
		if type(message) == "string" and message ~= "" then
			player:SetAttribute("Notice", message)
			player:SetAttribute("NoticeTime", os.clock())
		end
		local _ = ok
	end
	for i, g in RegaliConfig.GIFTS do
		local slot = Instance.new("TextButton")
		slot.Text = ""
		slot.AutoButtonColor = false
		slot.BackgroundTransparency = 1
		slot.ZIndex = 4
		slot:SetAttribute("UiNative", true)
		slot.Parent = row
		local when = UiKit.label(row, "", "status", 13)
		when.TextXAlignment = Enum.TextXAlignment.Center
		when.ZIndex = 4
		local what = UiKit.label(slot, g.text, "name", 14)
		what.TextXAlignment = Enum.TextXAlignment.Center
		what.TextYAlignment = Enum.TextYAlignment.Center
		what.TextWrapped = true
		what.TextTruncate = Enum.TextTruncate.None
		what.AnchorPoint = Vector2.new(0.5, 0.5)
		what.Position = UDim2.fromScale(0.5, 0.5)
		what.Size = UDim2.fromScale(0.74, 0.7)
		what.ZIndex = 6
		local action = Instance.new("TextButton")
		action.ZIndex = 5
		action.Parent = row
		UiKit.button(action, "primary")
		action.Text = "CLAIM"
		action.Activated:Connect(function()
			claim(i)
		end)
		slot.Activated:Connect(function()
			claim(i)
		end)
		cells[i] = { slot = slot, when = when, what = what, action = action }
	end
	local function layoutPanel()
		local w = panel.AbsoluteSize.X / ((panelGui:FindFirstChild("ScalaUI") :: UIScale?) and (panelGui:FindFirstChild("ScalaUI") :: UIScale).Scale or 1) - 48
		local cw = math.floor((w - (n - 1) * 8) / n)
		for i, c in cells do
			local x = (i - 1) * (cw + 8)
			Ui.px(c.when, 0, x, 0, 0, cw, 18)
			Ui.px(c.slot, 0, x, 0, 22, cw, cw)
			Ui.px(c.action, 0, x, 0, 26 + cw, cw, 34)
		end
	end
	local function paint()
		local claimed = RegaliConfig.claimed(player)
		local t = RegaliConfig.elapsed(player)
		for i, g in RegaliConfig.GIFTS do
			local c = cells[i]
			local readyAt = g.minutes * 60
			local isReady = not claimed[i] and t >= readyAt
			c.slot:SetAttribute("CorniceScala", 0.3)
			UiKit.slot(c.slot, if claimed[i] then "disabled" elseif isReady then "valid" else "normal")
			c.what.TextColor3 = if claimed[i] then UiKit.DIM else UiKit.TEXT
			c.when.Text = if claimed[i] then "✓ CLAIMED" elseif isReady then "READY!" else fmt(readyAt - t)
			c.when.TextColor3 = if isReady then UiKit.GOOD elseif claimed[i] then UiKit.DIM else UiKit.MUTED
			c.action.Visible = isReady
		end
	end
	close.Activated:Connect(function()
		panelGui.Enabled = false
	end)
	veil.Activated:Connect(function()
		panelGui.Enabled = false
	end)
	Ui.viewportChanged(function(vp)
		local logical = Ui.fitScale(panelGui, vp)
		panel.Size = UDim2.fromOffset(math.min(820, logical.X - 40), 300)
		task.defer(layoutPanel)
	end, panelGui)
	button.Activated:Connect(function()
		if HudLayout.editing() then
			return
		end
		panelGui.Enabled = true
		task.defer(layoutPanel)
		paint()
	end)

	-- conto alla rovescia (una volta al secondo: niente lavoro per frame)
	task.spawn(function()
		while gui.Parent do
			local nextIndex, wait, ready = status()
			dot.Visible = ready > 0
			dot.Text = tostring(ready)
			timer.Text = if ready > 0 then "READY!" elseif nextIndex then fmt(wait) else "DONE"
			timer.TextColor3 = if ready > 0 then UiKit.GOOD else UiKit.TEXT
			if panelGui.Enabled then
				paint()
			end
			task.wait(1)
		end
	end)
end

return RegaliUI
