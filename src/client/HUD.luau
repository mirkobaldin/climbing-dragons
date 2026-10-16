--!strict
-- HUD impaginato come lo schizzo di Mirko del 15/10 ("foto 5"):
--   in alto a sinistra (sotto il tasto MENU): foto dell'avatar in un cerchio e, accanto, le
--   barre a parallelogramma di vita, stamina e scudo; sotto il drago al seguito: cerchio
--   dell'elemento col livello nel cerchietto sopra, nome (o il nome che gli hai dato) e rarita',
--   barra dell'XP
--   in alto al centro: monete | montepremi | pietre del drago (client/Montepremi)
--   in alto a destra: meteo (icona tonda, ora, giorno/notte e tempo), quota e calore
--   in basso al centro: barra degli attrezzi a cinque caselle coi tasti 1-5
-- Missione, avvisi e suggerimenti restano i riquadri del modello in StarterGui.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local ClimbConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClimbConfig"))
local Gear = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Gear"))
local Names = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Names"))
local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Slant = require(script.Parent.Slant)
local UiKit = require(script.Parent.UiKit)
local Cornici = require(script.Parent.Cornici)
local Sfx = require(script.Parent.Sfx)
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local HUD = {}

local WEATHER_NAMES =
	{ Clear = "Clear", Cloudy = "Cloudy", Rain = "Rain", Thunderstorm = "Thunderstorm", Storm = "Storm", Snow = "Snow" }

local Ui = require(ReplicatedStorage.Shared.UiView)

local function circle(parent: Instance, color: Color3, stroke: Color3?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	if stroke then
		local s = Instance.new("UIStroke")
		s.Color = stroke
		s.Thickness = 3
		s:SetAttribute("KeepStroke", true)
		s.Parent = f
	end
	return f
end

local function text(parent: Instance, str: string, size: number, color: Color3?): TextLabel
	local l = Theme.label(parent, str, size, color or Theme.TEXT, true)
	l.Font = Enum.Font.GothamBlack
	l.TextStrokeTransparency = 0.25
	return l
end

-- Barra degli attrezzi: cinque caselle quadrate (tasti 1-5) coi Tool del backpack di Roblox
local SLOTS = 5
local function toolBar(gui: ScreenGui)
	local UIS = game:GetService("UserInputService")
	local UiAssets = require(ReplicatedStorage.Shared.UiAssets)
	local order = { ClimbConfig.TOOL_NAME, ClimbConfig.PICKAXE_NAME, ClimbConfig.GRAPPLE_NAME, ClimbConfig.TORCH_NAME }
	local icons = { "item_Piccozza", "item_Piccone", "item_Rampino", "item_Torcia" }
	local bar = Instance.new("Frame")
	bar.Name = "ToolBar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar
	local Hotbar = require(ReplicatedStorage.Shared.Hotbar)
	-- casella -> Tool, secondo la scelta fatta nello zaino (shared/Hotbar, attributo HotbarOrder)
	local tools: { [number]: Tool } = {}
	local cell = 74
	local function equip(index: number)
		if not gui.Enabled then
			return
		end
		local tool = tools[index]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not tool or not humanoid or humanoid.Health <= 0 then
			return
		end
		if tool.Parent == character then
			humanoid:UnequipTools()
		else
			humanoid:EquipTool(tool)
		end
	end
	local function refresh()
		for _, c in bar:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		table.clear(tools)
		for i, t in Hotbar.layout(player) do
			tools[i] = t
		end
		for i = 1, SLOTS do
			local tool = tools[i]
			local on = tool ~= nil and tool.Parent == player.Character
			local b = Instance.new("TextButton")
			b.Name = "Casella" .. i
			b.Text = ""
			b.LayoutOrder = i
			b.Size = UDim2.fromOffset(cell, cell)
			b.AutoButtonColor = tool ~= nil
			b.BackgroundColor3 = if on then Color3.fromRGB(70, 56, 18) else Theme.DARK2
			b.BackgroundTransparency = if tool then 0.08 else 0.35
			b:SetAttribute("UiNative", true)
			b.Parent = bar
			Theme.corner(b, 10)
			local s = Instance.new("UIStroke")
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			s.Color = if on then Theme.ACCENT else Color3.fromRGB(10, 12, 20)
			s.Thickness = if on then 3 else 2
			s:SetAttribute("KeepStroke", true)
			s.Parent = b
			-- casella di Codex (oro e ferro con gli artigli): in mano = oro acceso, vuota = spenta
			if Cornici.apply(b, if on then "frame_slot_selected" elseif tool then "frame_slot_normal" else "frame_slot_disabled") then
				b.BackgroundTransparency = 1
				s.Enabled = false
				local corner = b:FindFirstChildOfClass("UICorner")
				if corner then
					corner:Destroy()
				end
				if tool and not on then
					-- premuto: la casella si accende e l'icona scende di un filo
					b.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							Cornici.apply(b, "frame_slot_hover")
						end
					end)
				end
			end
			local key = text(b, tostring(i), 14, if on then Theme.ACCENT else Theme.MUTED)
			key.Position = UDim2.fromOffset(4, 1)
			key.Size = UDim2.fromOffset(20, 20)
			key.ZIndex = 4
			key.Visible = not Ui.touch()
			if tool then
				local icon = Instance.new("ImageLabel")
				icon.BackgroundTransparency = 1
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Position = UDim2.fromScale(0.5, 0.48)
				icon.Size = UDim2.fromScale(0.7, 0.7)
				icon.ZIndex = 3
				icon.Parent = b
				local known = table.find(order, tool.Name)
				local id = known and UiAssets.get(icons[known])
				icon.Image = id or tool.TextureId
				if icon.Image == "" then
					local n = text(b, tool.Name, 11)
					n.Size = UDim2.fromScale(1, 1)
					n.TextWrapped = true
					n.TextXAlignment = Enum.TextXAlignment.Center
					n.ZIndex = 3
				end
				b.Activated:Connect(function()
					equip(i)
				end)
			end
		end
	end
	local pending = false
	local function queue()
		if pending then
			return
		end
		pending = true
		task.defer(function()
			pending = false
			refresh()
		end)
	end
	local connections: { RBXScriptConnection } = {}
	local function characterAdded(character: Model)
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
		for _, parent in { player:WaitForChild("Backpack"), character } do
			table.insert(connections, parent.ChildAdded:Connect(queue))
			table.insert(connections, parent.ChildRemoved:Connect(queue))
		end
		queue()
	end
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
	player:GetAttributeChangedSignal("HotbarOrder"):Connect(queue)
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }
	UIS.InputBegan:Connect(function(input, processed)
		if processed or UIS:GetFocusedTextBox() then
			return
		end
		local i = table.find(keys, input.KeyCode)
		if i then
			equip(i)
		end
	end)
	Ui.viewportChanged(function(vp)
		local logical = Ui.fitScale(gui, vp)
		local small = Ui.compact(vp) or Ui.touch()
		local was = cell
		cell = if small then 54 else 74
		-- centrata anche sul telefono (Mirko 16/10: era spostata a sinistra); il tasto del menu ora
		-- sta nell'angolo a sinistra, non piu' accanto alla barra
		bar.Position = if logical.X < 600 then UDim2.new(0.5, 0, 1, -190) elseif small then UDim2.new(0.5, 0, 1, -6) else UDim2.new(0.5, 0, 1, -10)
		bar.Size = UDim2.fromOffset(SLOTS * (cell + 6), cell)
		if was ~= cell then
			queue()
		end
	end)
	gui:SetAttribute("CustomToolBar", true)
	-- in groppa o nella forma di drago gli attrezzi non si usano: barra nascosta
	local function ridingBar()
		bar.Visible = player:GetAttribute("Riding") ~= true
	end
	player:GetAttributeChangedSignal("Riding"):Connect(ridingBar)
	ridingBar()
end

function HUD.start()
	-- la salute la mostra la nostra HUD: quella di Roblox si spegne all'avvio, a ogni respawn e
	-- ogni 2 secondi (clip e rampino rimettono tutta l'interfaccia di Roblox)
	local function hideRobloxHealth()
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			if StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Health) then
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			end
		end)
	end
	hideRobloxHealth()
	player.CharacterAdded:Connect(function()
		task.defer(hideRobloxHealth)
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			hideRobloxHealth()
		end
	end)
	local gui = Ui.screen("ClimbHUD")
	toolBar(gui)
	UiKit.adopt(gui) -- stessi caratteri e angoli vivi del menu
	-- i vecchi riquadri del modello (giocatore, monete, drago, meteo) restano spenti
	for _, n in { "Player", "Coins", "Pet", "Weather" } do
		local o = gui:FindFirstChild(n)
		if o and o:IsA("GuiObject") then
			o.Visible = false
			o:GetPropertyChangedSignal("Visible"):Connect(function()
				o.Visible = false
			end)
		end
	end
	local quest = Ui.node(gui, "Quest")
	local questTitle, questText, skip = quest.Title, quest.Text, quest.Skip
	local hint = Ui.node(gui, "Hint")
	local noticePanel = Ui.node(gui, "Notice")
	-- avviso nello stile unico: superficie scura, angoli vivi, filo d'oro (prima riquadro blu tondo)
	for _, n in { "AssetSurface", "Tinta" } do
		local o = noticePanel:FindFirstChild(n)
		if o and o:IsA("GuiObject") then
			o.Visible = false
		end
	end
	for _, g in noticePanel:GetChildren() do
		if g:IsA("UIGradient") then
			g.Enabled = false
		end
	end
	noticePanel.BackgroundColor3 = UiKit.INK
	noticePanel.BackgroundTransparency = 0.12
	UiKit.edge(noticePanel, UiKit.ACCENT, 1, 0.35)
	-- avviso di Codex: filo d'oro con le punte ai lati, attorno al riquadro
	if Cornici.apply(noticePanel, "frame_toast", { mode = "outset", z = 6 }) then
		UiKit.edge(noticePanel, UiKit.ACCENT, 1, 1)
		local corner = noticePanel:FindFirstChildOfClass("UICorner")
		if corner then
			corner:Destroy()
		end
	end
	local noticePosition = noticePanel.Position
	local noticeVersion = 0
	local function showNotice()
		local message = player:GetAttribute("Notice")
		if type(message) ~= "string" or message == "" then
			return
		end
		noticeVersion += 1
		local version = noticeVersion
		noticePanel.Text.Text = message
		local goal = noticePosition
		noticePanel.Position = goal - UDim2.fromOffset(0, 8)
		Ui.open(noticePanel)
		game:GetService("TweenService"):Create(noticePanel, TweenInfo.new(0.18), { Position = goal }):Play()
		task.delay(4, function()
			if noticeVersion == version then
				noticePanel.Visible = false
			end
		end)
	end
	player:GetAttributeChangedSignal("NoticeTime"):Connect(showNotice)

	-- GIOCATORE: avatar tondo e tre barre oblique
	local me = Instance.new("Frame")
	me.Name = "Giocatore"
	me.BackgroundTransparency = 1
	me.Parent = gui
	local barsBox = Instance.new("Frame")
	barsBox.BackgroundTransparency = 1
	barsBox.Parent = me
	-- barre dritte dentro le cornici di Codex (terminali ornati); se le immagini mancano restano
	-- le barre oblique di prima
	local framedBars = Cornici.has("frame_bar_health")
	local healthBar = Slant.bar(barsBox, Theme.DARK, Theme.BAD, if framedBars then 0 else 18)
	local staminaBar = Slant.bar(barsBox, Theme.DARK, Theme.GOOD, if framedBars then 0 else 16)
	local shieldBar = Slant.bar(barsBox, Theme.DARK, Theme.BLUE, if framedBars then 0 else 14)
	if framedBars then
		Cornici.apply(healthBar, "frame_bar_health", { mode = "outset", z = 5 })
		Cornici.apply(staminaBar, "frame_bar_stamina", { mode = "outset", z = 5 })
		Cornici.apply(shieldBar, "frame_bar_shield", { mode = "outset", z = 5 })
	end
	Slant.setZ(healthBar, 2)
	Slant.setZ(staminaBar, 2)
	Slant.setZ(shieldBar, 2)
	local healthText = text(healthBar, "", 16)
	local staminaText = text(staminaBar, "", 13)
	local shieldText = text(shieldBar, "", 13)
	for _, l in { healthText, staminaText, shieldText } do
		l.ZIndex = 6
		l.Size = UDim2.new(1, -20, 1, 0)
		l.Position = UDim2.fromOffset(0, 0)
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	local avatar = circle(me, Theme.DARK2, Theme.ACCENT)
	avatar.Name = "Avatar"
	avatar.ZIndex = 8
	-- ritratto di Codex: il foro coincide col cerchio della foto
	if Cornici.apply(avatar, "frame_portrait_player", { mode = "circle", z = 12 }) then
		local st = avatar:FindFirstChildOfClass("UIStroke")
		if st then
			st.Enabled = false
		end
	end
	local photo = Instance.new("ImageLabel")
	photo.BackgroundTransparency = 1
	photo.Size = UDim2.fromScale(1, 1)
	photo.ZIndex = 9
	photo.Parent = avatar
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.5, 0)
	pc.Parent = photo
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and type(img) == "string" then
			photo.Image = img
		end
	end)
	local nameLabel = text(me, player.DisplayName, 15)
	nameLabel.ZIndex = 8

	-- DRAGO: cerchio dell'elemento, livello nel cerchietto sopra, nome-rarita' e XP obliqui
	local pet = Instance.new("Frame")
	pet.Name = "Drago"
	pet.BackgroundTransparency = 1
	pet.Visible = false
	pet.Parent = gui
	local petBars = Instance.new("Frame")
	petBars.BackgroundTransparency = 1
	petBars.Parent = pet
	local nameBar = Slant.new(petBars, Theme.DARK2, 0.1, 16)
	Slant.setZ(nameBar, 2)
	local nameStripe = Theme.frame(nameBar, Theme.ACCENT, 0)
	nameStripe.ZIndex = 3
	local petName = text(nameBar, "", 16)
	petName.ZIndex = 4
	local xpBar = Slant.bar(petBars, Theme.DARK, Theme.PURPLE, if framedBars then 0 else 14)
	Slant.setZ(xpBar, 2)
	if framedBars then
		Cornici.apply(xpBar, "frame_bar_xp", { mode = "outset", z = 5 })
	end
	local xpText = text(xpBar, "", 13)
	xpText.ZIndex = 6
	xpText.TextXAlignment = Enum.TextXAlignment.Left
	local elemCircle = circle(pet, Theme.DARK2, Theme.PURPLE)
	elemCircle.ZIndex = 8
	-- ritratto del drago di Codex: cornice, filo della rarita' e gemme dell'elemento (livelli
	-- grigi colorati in refreshPet)
	if Cornici.apply(elemCircle, "frame_portrait_dragon", { mode = "circle", z = 12 }) then
		Cornici.apply(elemCircle, "frame_portrait_dragon_rarity", { mode = "circle", z = 13, name = "CorniceRarita" })
		Cornici.apply(elemCircle, "frame_portrait_dragon_gem", { mode = "circle", z = 13, name = "CorniceGemme" })
		local st = elemCircle:FindFirstChildOfClass("UIStroke")
		if st then
			st.Enabled = false
		end
	end
	local elemIcon = Instance.new("ImageLabel")
	elemIcon.BackgroundTransparency = 1
	elemIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	elemIcon.Position = UDim2.fromScale(0.5, 0.5)
	elemIcon.Size = UDim2.fromScale(0.78, 0.78)
	elemIcon.ZIndex = 9
	elemIcon.Parent = elemCircle
	local lvCircle = circle(pet, Theme.ACCENT, Color3.fromRGB(60, 40, 0))
	lvCircle.ZIndex = 10
	if Cornici.apply(lvCircle, "frame_level_badge", { mode = "circle", z = 12 }) then
		local st = lvCircle:FindFirstChildOfClass("UIStroke")
		if st then
			st.Enabled = false
		end
	end
	local lvText = text(lvCircle, "", 15, Color3.fromRGB(40, 24, 0))
	lvText.Size = UDim2.fromScale(1, 1)
	lvText.TextXAlignment = Enum.TextXAlignment.Center
	lvText.TextStrokeTransparency = 1
	lvText.ZIndex = 11

	-- METEO in alto a destra
	local weather = Instance.new("Frame")
	weather.Name = "Meteo"
	weather.BackgroundColor3 = Theme.DARK
	weather.BackgroundTransparency = 0.2
	weather.Parent = gui
	Theme.corner(weather, 14)
	local ws = Instance.new("UIStroke")
	ws.Color = Color3.fromRGB(10, 12, 20)
	ws.Thickness = 2
	ws:SetAttribute("KeepStroke", true)
	ws.Parent = weather
	local wCircle = circle(weather, Theme.DARK2, Theme.BLUE)
	wCircle.ZIndex = 2
	-- cornice di Codex attorno al meteo e medaglione attorno all'icona
	if Cornici.apply(weather, "frame_panel", { border = 8 }) then
		weather.BackgroundTransparency = 1
		ws.Enabled = false
		local wc = weather:FindFirstChildOfClass("UICorner")
		if wc then
			wc:Destroy()
		end
		if Cornici.apply(wCircle, "frame_currency_medallion", { mode = "circle", z = 4 }) then
			local st = wCircle:FindFirstChildOfClass("UIStroke")
			if st then
				st.Enabled = false
			end
		end
	end
	local wIcon = Instance.new("ImageLabel")
	wIcon.BackgroundTransparency = 1
	wIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	wIcon.Position = UDim2.fromScale(0.5, 0.5)
	wIcon.Size = UDim2.fromScale(0.8, 0.8)
	wIcon.ZIndex = 3
	wIcon.Parent = wCircle
	local wFallback = text(wCircle, "", 26)
	wFallback.Size = UDim2.fromScale(1, 1)
	wFallback.TextXAlignment = Enum.TextXAlignment.Center
	wFallback.ZIndex = 3
	local timeBox = Instance.new("Frame")
	timeBox.BackgroundColor3 = Theme.DARK2
	timeBox.ZIndex = 2
	timeBox.Parent = weather
	Theme.corner(timeBox, 10)
	local timeText = text(timeBox, "12:00", 30)
	timeText.Size = UDim2.fromScale(1, 1)
	timeText.TextXAlignment = Enum.TextXAlignment.Center
	timeText.ZIndex = 3
	local condBox = Instance.new("Frame")
	condBox.BackgroundColor3 = Theme.DARK2
	condBox.ZIndex = 2
	condBox.Parent = weather
	Theme.corner(condBox, 10)
	local dayText = text(condBox, "Day", 16, Theme.ACCENT)
	dayText.ZIndex = 3
	dayText.TextXAlignment = Enum.TextXAlignment.Center
	local condText = text(condBox, "Clear", 16, Theme.BLUE)
	condText.ZIndex = 3
	condText.TextXAlignment = Enum.TextXAlignment.Center
	local altText = text(weather, "", 15, Theme.MUTED)
	altText.ZIndex = 3
	local warmBar = Slant.bar(weather, Theme.DARK2, Theme.ORANGE, 10)
	Slant.setZ(warmBar, 3)
	local warmText = text(warmBar, "", 12)
	warmText.ZIndex = 6
	warmText.Size = UDim2.fromScale(1, 1)
	warmText.TextXAlignment = Enum.TextXAlignment.Center
	local finder = text(weather, "", 14, Theme.ACCENT)
	finder.ZIndex = 3
	finder.TextWrapped = true
	finder.TextXAlignment = Enum.TextXAlignment.Center


	-- MISSIONE ATTUALE, sotto il drago su tutti i dispositivi (Mirko 16/10: "IO -> IL MIO DRAGO ->
	-- COSA DEVO FARE"). Un solo obiettivo corto (rombo + VERBO...), la distanza dalla meta e
	-- l'aiuto progressivo: prima solo l'obiettivo, se il giocatore ci mette un po' si accende il
	-- comando giusto, poi compare la riga d'aiuto. Il riquadro "Quest" del modello resta spento.
	quest.Visible = false
	local mission = Instance.new("Frame")
	mission.Name = "Missione"
	mission.BackgroundColor3 = UiKit.INK
	mission.BackgroundTransparency = 0.3
	mission.BorderSizePixel = 0
	mission.Visible = false
	mission.Parent = gui
	UiKit.edge(mission, UiKit.LINE, 1, 0.75)
	local mBar = Instance.new("Frame")
	mBar.BorderSizePixel = 0
	mBar.BackgroundColor3 = UiKit.ACCENT
	mBar.Size = UDim2.new(0, 3, 1, 0)
	mBar.Parent = mission
	local mDiamond = Instance.new("Frame") -- il "rombo" davanti all'obiettivo (al posto della stella)
	mDiamond.BorderSizePixel = 0
	mDiamond.BackgroundColor3 = UiKit.ACCENT
	mDiamond.Rotation = 45
	mDiamond.Parent = mission
	local mStep = UiKit.label(mission, "", "status")
	local mGoal = UiKit.label(mission, "", "name", 19)
	local mDist = UiKit.label(mission, "", "stat", 18)
	mDist.TextColor3 = UiKit.ICE
	mDist.TextXAlignment = Enum.TextXAlignment.Right
	local mHelp = UiKit.label(mission, "", "body", 15)
	mHelp.TextWrapped = true
	mHelp.TextTruncate = Enum.TextTruncate.None
	mHelp.TextYAlignment = Enum.TextYAlignment.Top
	mHelp.TextColor3 = UiKit.MUTED
	skip.Parent = mission
	-- il modello gli imponeva una misura minima (copriva la distanza): via i vincoli
	for _, c in skip:GetChildren() do
		if c:IsA("UISizeConstraint") or c:IsA("UITextSizeConstraint") or c:IsA("UIPadding") then
			c:Destroy()
		end
	end
	UiKit.button(skip, "secondary")
	-- HIDE accanto a SKIP (Mirko 16/10): piega il riquadro ma la missione resta attiva (frecce,
	-- avanzamento, ricompensa); la pillola "◆ MISSION" lo riapre. Diverso da HIDE HUD
	local hideMission = Instance.new("TextButton")
	hideMission.Name = "NascondiMissione"
	hideMission.Parent = mission
	UiKit.button(hideMission, "secondary")
	hideMission.Text = "HIDE"
	local missionPill = Instance.new("TextButton")
	missionPill.Name = "RiapriMissione"
	missionPill.Visible = false
	missionPill.Parent = gui
	UiKit.button(missionPill, "secondary")
	missionPill.Text = "◆ MISSION  ▸"
	missionPill.TextColor3 = UiKit.ACCENT
	local missionHidden = false
	local helpShown = false

	-- CONFERMA breve al centro ("PITON PLACED!", "OBJECTIVE COMPLETE!"): niente finestre da chiudere
	local toast = Instance.new("Frame")
	toast.Name = "Conferma"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundColor3 = UiKit.INK
	toast.BackgroundTransparency = 0.25
	toast.BorderSizePixel = 0
	toast.Visible = false
	toast.Parent = gui
	UiKit.edge(toast, UiKit.ACCENT, 1, 0.3)
	local toastText = UiKit.label(toast, "", "title", 26)
	toastText.TextXAlignment = Enum.TextXAlignment.Center
	toastText.Size = UDim2.fromScale(1, 1)
	toastText.TextColor3 = UiKit.ACCENT
	local toastScale = Instance.new("UIScale")
	toastScale.Parent = toast
	local toastVersion = 0
	local function success(text: string)
		toastVersion += 1
		local v = toastVersion
		toastText.Text = "✓  " .. string.upper(text)
		toast.Visible = true
		toastScale.Scale = 0.85
		TweenService:Create(toastScale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		Sfx.play("Stelle", nil, 0.6)
		task.delay(1.6, function()
			if toastVersion == v then
				toast.Visible = false
			end
		end)
	end
	-- le prime volte che fai una cosa nuova (poi basta: hai capito)
	local seen: { [string]: number } = {}
	local function firstTimes(key: string, text: string)
		seen[key] = (seen[key] or 0) + 1
		if seen[key] <= 3 then
			success(text)
		end
	end
	for attr, text in { PitonsPlaced = "Piton placed!", OresMined = "Ore mined!", EggsHatched = "Dragon hatched!" } do
		local last = (player:GetAttribute(attr) or 0) :: number
		player:GetAttributeChangedSignal(attr):Connect(function()
			local now = (player:GetAttribute(attr) or 0) :: number
			if now > last then
				firstTimes(attr, text)
			end
			last = now
		end)
	end
	player:GetAttributeChangedSignal("CarryingEgg"):Connect(function()
		if player:GetAttribute("CarryingEgg") then
			success("Egg found!")
		end
	end)

	-- NASCONDI HUD: via le informazioni (giocatore, drago, missione, monete, montepremi, meteo),
	-- restano i comandi di gioco, le frecce guida e i suggerimenti del tutorial. Il tasto resta
	-- sempre al suo posto (in alto a destra, accanto al meteo)
	local hideBtn = Instance.new("TextButton")
	hideBtn.Name = "NascondiHUD"
	hideBtn.Text = "HIDE HUD"
	hideBtn.ZIndex = 5
	hideBtn.Parent = gui
	UiKit.button(hideBtn, "secondary")
	-- "?" = pannello dei comandi (client/ControlsPanel), sempre consultabile dopo il tutorial
	local helpBtn = Instance.new("TextButton")
	helpBtn.Name = "Comandi"
	helpBtn.ZIndex = 5
	helpBtn.Parent = gui
	UiKit.button(helpBtn, "secondary")
	helpBtn.Text = "?"
	helpBtn.Activated:Connect(function()
		require(script.Parent.ControlsPanel).open(true)
	end)
	local hidden = false
	local function applyHidden()
		player:SetAttribute("HudNascosto", hidden)
		hideBtn.Text = if hidden then "SHOW HUD" else "HIDE HUD"
		me.Visible = not hidden
		weather.Visible = not hidden
	end
	hideBtn.Activated:Connect(function()
		hidden = not hidden
		applyHidden()
	end)

	-- METEO pieghevole: tocco/click = solo icona e ora, di nuovo = tutto (quota, calore, uovo).
	-- Lo stato resta per tutta la partita, anche nascondendo e rimostrando l'HUD
	local weatherFolded = Ui.touch() -- sul telefono parte chiuso (meno spazio occupato)
	weather.Active = true

	local P = Ui.px
	local compact = false
	local logical = Vector2.new(1280, 680)
	local shieldOn = false
	-- impaginazione in pixel logici (UiView.fitScale adatta tutto allo schermo)
	-- telefono: dettagli del drago (nome e rarita') aperti toccando il suo cerchio
	local petExpanded = false
	local function layoutLeft()
		local x0 = 12
		local y0 = 6
		if compact then
			-- TELEFONO (Mirko 16/10: ritratti troppo grandi): avatar da 50, barre sottili coi
			-- valori essenziali, drago piccolo con livello e XP; nome e rarita' a richiesta
			local av = 50
			P(me, 0, 8, 0, 4, 250, av + 6)
			P(avatar, 0, 0, 0, 3, av, av)
			local bx = math.floor(av * 0.5)
			P(barsBox, 0, bx, 0, 0, 220, av + 6)
			local barX = bx + 5
			if framedBars then
				-- cornici di Codex: barre piu' sottili e piu' distanti (la cornice sta fuori dalla barra)
				P(healthBar, 0, 0, 0, 5, 196, 14)
				P(staminaBar, 0, 0, 0, 31, 178, 11)
				P(shieldBar, 0, 0, 0, 53, 162, 11)
			else
				P(healthBar, 0, 0, 0, 4, 200, 19)
				P(staminaBar, 0, 0, 0, 4 + 19 + 3, 182, 15)
				P(shieldBar, 0, 0, 0, 4 + 19 + 3 + 15 + 3, 166, 15)
			end
			shieldBar.Visible = shieldOn
			for _, l in { healthText, staminaText, shieldText } do
				l.Position = UDim2.fromOffset(barX, 0)
				l.Size = UDim2.new(1, -(barX + 14), 1, 0)
			end
			Ui.text(healthText, if framedBars then 12 else 13, true)
			Ui.text(staminaText, if framedBars then 11 else 12, true)
			Ui.text(shieldText, if framedBars then 11 else 12, true)
			nameLabel.Visible = false
			local py = 4 + av + 10 + (if framedBars and shieldOn then 14 else 0)
			local ec = 38
			P(pet, 0, x0, 0, py, 240, ec + 4)
			P(elemCircle, 0, 0, 0, 3, ec, ec)
			local lv = 20
			P(lvCircle, 0, -5, 0, -3, lv, lv)
			Ui.text(lvText, 12, true)
			P(petBars, 0, math.floor(ec * 0.5), 0, 3, 200, ec)
			nameBar.Visible = petExpanded
			local nb = 18
			P(nameBar, 0, 0, 0, 0, 190, nb)
			nameStripe.Position = UDim2.fromOffset(math.floor(ec * 0.5) + 2, 0)
			nameStripe.Size = UDim2.fromOffset(3, nb)
			P(petName, 0, math.floor(ec * 0.5) + 8, 0, 0, 150, nb)
			Ui.text(petName, 12, true)
			P(xpBar, 0, 0, 0, if petExpanded then nb + 3 else 10, 160, 15)
			xpText.Position = UDim2.fromOffset(math.floor(ec * 0.5) + 8, 0)
			xpText.Size = UDim2.new(1, -(math.floor(ec * 0.5) + 18), 1, 0)
			Ui.text(xpText, 12, true)
			-- missione: riquadro stretto sotto il drago
			local my = if pet.Visible then py + ec + 10 else py
			local mw = 248
			local mh = if helpShown then 76 else 50
			P(mission, 0, x0 - 4, 0, my, mw, mh)
			P(mDiamond, 0, 10, 0, 27, 7, 7)
			P(mStep, 0, 9, 0, 2, mw - 112, 15)
			UiKit.text(mStep, "status", 11)
			P(skip, 1, -4, 0, 3, 50, 17, 1, 0)
			skip.TextSize = 12
			P(hideMission, 1, -58, 0, 3, 50, 17, 1, 0)
			hideMission.TextSize = 12
			P(missionPill, 0, x0 - 4, 0, my, 128, 26)
			missionPill.TextSize = 13
			P(mGoal, 0, 24, 0, 19, mw - 90, 24)
			UiKit.text(mGoal, "name", 15)
			P(mDist, 1, -8, 0, 21, 64, 22, 1, 0)
			UiKit.text(mDist, "stat", 15)
			mDist.TextColor3 = UiKit.ICE
			mDist.TextXAlignment = Enum.TextXAlignment.Right
			P(mHelp, 0, 10, 0, 44, mw - 20, 30)
			UiKit.text(mHelp, "body", 13)
			mHelp.TextColor3 = UiKit.MUTED
			mHelp.Visible = helpShown
			gui:SetAttribute("LeftBottom", my + mh + 8)
			return
		end
		local k = 1
		local av = math.floor(96 * k)
		P(me, 0, x0, 0, y0, math.floor(380 * k), av + 4)
		P(avatar, 0, 0, 0, 2, av, av)
		-- barre: partono da meta' cerchio (il cerchio le copre a sinistra), via via piu' corte
		local bx = math.floor(av * 0.5)
		P(barsBox, 0, bx, 0, 0, math.floor(320 * k), av + 4)
		local hH, sH = math.floor(30 * k), math.floor(22 * k)
		local barX = math.floor(av * 0.5) + 6
		if framedBars then
			hH, sH = 24, 18
			P(healthBar, 0, 0, 0, 10, math.floor(300 * k), hH)
			P(staminaBar, 0, 0, 0, 54, math.floor(270 * k), sH)
			P(shieldBar, 0, 0, 0, 90, math.floor(244 * k), sH)
		else
			P(healthBar, 0, 0, 0, math.floor(8 * k), math.floor(300 * k), hH)
			P(staminaBar, 0, 0, 0, math.floor(8 * k) + hH + 4, math.floor(270 * k), sH)
			P(shieldBar, 0, 0, 0, math.floor(8 * k) + hH + sH + 8, math.floor(244 * k), sH)
		end
		shieldBar.Visible = shieldOn
		for _, l in { healthText, staminaText, shieldText } do
			l.Position = UDim2.fromOffset(barX, 0)
			l.Size = UDim2.new(1, -(barX + 20), 1, 0)
		end
		Ui.text(healthText, math.floor(17 * k), true)
		Ui.text(staminaText, math.floor(13 * k), true)
		Ui.text(shieldText, math.floor(13 * k), true)
		P(nameLabel, 0, av + 8, 0, math.floor(8 * k) + hH + sH * 2 + 12, 200, math.floor(18 * k))
		nameLabel.Visible = not shieldOn
		Ui.text(nameLabel, 14, true)
		-- drago sotto
		local py = y0 + av + math.floor(14 * k) + (if framedBars and shieldOn then 18 else 0)
		local ec = math.floor(70 * k)
		P(pet, 0, x0 + math.floor(12 * k), 0, py, math.floor(360 * k), ec + 6)
		P(elemCircle, 0, 0, 0, 6, ec, ec)
		local lv = math.floor(34 * k)
		P(lvCircle, 0, -math.floor(8 * k), 0, -math.floor(4 * k), lv, lv)
		Ui.text(lvText, math.floor(15 * k), true)
		P(petBars, 0, math.floor(ec * 0.5), 0, 6, math.floor(310 * k), ec)
		nameBar.Visible = true
		local nb = math.floor(28 * k)
		P(nameBar, 0, 0, 0, math.floor(6 * k), math.floor(290 * k), nb)
		P(nameStripe, 0, 0, 0, 0, 4, nb)
		nameStripe.Position = UDim2.fromOffset(math.floor(ec * 0.5) + 2, 0)
		P(petName, 0, math.floor(ec * 0.5) + 10, 0, 0, math.floor(220 * k), nb)
		Ui.text(petName, math.floor(16 * k), true)
		P(xpBar, 0, 0, 0, math.floor(6 * k) + nb + 4, math.floor(262 * k), math.floor(22 * k))
		xpText.Position = UDim2.fromOffset(math.floor(ec * 0.5) + 10, 0)
		xpText.Size = UDim2.new(1, -(math.floor(ec * 0.5) + 24), 1, 0)
		Ui.text(xpText, math.floor(13 * k), true)
		-- missione sotto il drago (o sotto il giocatore se non hai un drago al seguito)
		local my = if pet.Visible then py + ec + math.floor(14 * k) else py
		local mw = math.floor(340 * k)
		local mh = math.floor((if helpShown then 98 else 62) * k)
		P(mission, 0, x0, 0, my, mw, mh)
		P(mDiamond, 0, math.floor(14 * k), 0, math.floor(34 * k), math.floor(9 * k), math.floor(9 * k))
		P(mStep, 0, math.floor(12 * k), 0, math.floor(4 * k), mw - math.floor(160 * k), math.floor(18 * k))
		UiKit.text(mStep, "status", math.floor(12 * k + 0.5))
		P(skip, 1, -6, 0, 5, 64, 22, 1, 0)
		skip.TextSize = 13
		P(hideMission, 1, -76, 0, 5, 64, 22, 1, 0)
		hideMission.TextSize = 13
		P(missionPill, 0, x0, 0, my, 150, 30)
		missionPill.TextSize = 15
		P(mGoal, 0, math.floor(32 * k), 0, math.floor(25 * k), mw - math.floor(120 * k), math.floor(30 * k))
		UiKit.text(mGoal, "name", math.floor(19 * k + 0.5))
		P(mDist, 1, -math.floor(10 * k), 0, math.floor(28 * k), math.floor(84 * k), math.floor(28 * k), 1, 0)
		UiKit.text(mDist, "stat", math.floor(18 * k + 0.5))
		mDist.TextColor3 = UiKit.ICE
		mDist.TextXAlignment = Enum.TextXAlignment.Right
		P(mHelp, 0, math.floor(14 * k), 0, math.floor(56 * k), mw - math.floor(28 * k), math.floor(38 * k))
		UiKit.text(mHelp, "body", math.max(13, math.floor(15 * k)))
		mHelp.TextColor3 = UiKit.MUTED
		mHelp.Visible = helpShown
		gui:SetAttribute("LeftBottom", my + mh + 10)
	end
	elemCircle.Active = true
	elemCircle.InputBegan:Connect(function(input)
		if compact and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			petExpanded = not petExpanded
			layoutLeft()
		end
	end)
	local function layoutWeather()
		local k = if compact then 0.8 else 1
		local folded = weatherFolded
		local w = math.floor((if folded then 168 else 250) * k)
		local frozen = warmBar.Visible and not folded
		local hasFinder = finder.Visible and not folded
		local c = math.floor((if folded then 44 else 64) * k)
		local h = if folded then c + math.floor(16 * k)
			else math.floor(122 * k) + (if frozen then math.floor(26 * k) else 0) + (if hasFinder then math.floor(40 * k) else 0)
		-- in alto a destra, subito sotto la barra di Roblox
		TweenService:Create(weather, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(w, h) }):Play()
		weather.AnchorPoint = Vector2.new(1, 0)
		weather.Position = UDim2.new(1, -12, 0, 6)
		P(hideBtn, 1, -(12 + w + 8), 0, 6, math.floor(92 * k), math.floor(30 * k), 1, 0)
		hideBtn.TextSize = math.max(13, math.floor(15 * k))
		P(helpBtn, 1, -(12 + w + 8 + math.floor(92 * k) + 6), 0, 6, math.floor(30 * k), math.floor(30 * k), 1, 0)
		helpBtn.TextSize = math.max(14, math.floor(17 * k))
		P(wCircle, 0, math.floor(8 * k), 0, math.floor(8 * k), c, c)
		P(timeBox, 0, c + math.floor(16 * k), 0, math.floor(8 * k), w - c - math.floor(24 * k), if folded then c else math.floor(48 * k))
		for _, o in { condBox, altText } do
			o.Visible = not folded
		end
		Ui.text(timeText, math.floor(30 * k), true)
		P(condBox, 0, math.floor(10 * k), 0, c + math.floor(18 * k), w - math.floor(20 * k), math.floor(28 * k))
		P(dayText, 0, 0, 0, 0, math.floor((w - 20 * k) / 2), math.floor(28 * k))
		P(condText, 0.5, 0, 0, 0, math.floor((w - 20 * k) / 2), math.floor(28 * k))
		Ui.text(dayText, math.floor(15 * k), true)
		Ui.text(condText, math.floor(15 * k), true)
		local y = c + math.floor(50 * k)
		P(altText, 0, math.floor(12 * k), 0, y, w - math.floor(24 * k), math.floor(20 * k))
		Ui.text(altText, math.floor(14 * k), true)
		y += math.floor(22 * k)
		P(warmBar, 0, math.floor(12 * k), 0, y, w - math.floor(24 * k), math.floor(18 * k))
		Ui.text(warmText, math.floor(12 * k), true)
		if frozen then
			y += math.floor(26 * k)
		end
		P(finder, 0, math.floor(8 * k), 0, y, w - math.floor(16 * k), math.floor(38 * k))
		Ui.fit(finder, math.floor(14 * k), 10, true)
		finder.TextXAlignment = Enum.TextXAlignment.Center
	end
	local function layoutAll()
		layoutLeft()
		layoutWeather()
		local portrait = logical.X < 600
		local x = if portrait then 10 elseif compact then 270 else 420
		local w = if portrait then logical.X - 20 else math.max(220, logical.X - x - (if compact then 200 else 290))
		w = math.min(w, if compact then 340 else 520)
		local y = if portrait then ((gui:GetAttribute("LeftBottom") or 300) :: number) + 92 else (if compact then 46 else 64)
		local _ = y
		-- avvisi in alto al centro, sotto la striscia delle monete
		P(noticePanel, 0.5, 0, 0, if compact then 100 else 126, w, 44, 0.5, 0)
		P(noticePanel.Text, 0, 8, 0, 6, w - 16, 32)
		-- (sul telefono piu' in alto: sopra la barra c'e' l'apri-menu)
		P(hint, 0.5, 0, 1, if compact then -132 else -100, math.min(560, logical.X - 32), 40, 0.5, 1)
		Ui.text(noticePanel.Text, if compact then 14 else 17, true)
		Ui.text(hint, if compact then 15 else 19, true)
		local _ = questTitle
		local _ = questText
		noticePosition = noticePanel.Position
	end
	Ui.viewportChanged(function(vp)
		logical = Ui.fitScale(gui, vp)
		compact = Ui.compact(vp)
		layoutAll()
		P(toast, 0.5, 0, 0, if compact then 52 else 66, if compact then 340 else 440, if compact then 44 else 54, 0.5, 0)
	end)
	weather.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			weatherFolded = not weatherFolded
			layoutWeather()
		end
	end)
	applyHidden()
	local relaying = false
	for _, o in { warmBar, finder } do
		o:GetPropertyChangedSignal("Visible"):Connect(function()
			if not relaying then
				relaying = true
				layoutWeather()
				relaying = false
			end
		end)
	end

	local function refreshPet()
		local ok, data = pcall(function()
			return HttpService:JSONDecode(player:GetAttribute("DragonData") :: string)
		end)
		local d: any = nil
		if ok and type(data) == "table" and data.equipped then
			for _, x in data.dragons or {} do
				if x.id == data.equipped[1] then
					d = x
				end
			end
		end
		pet.Visible = d ~= nil and player:GetAttribute("HudNascosto") ~= true
		if not d then
			return
		end
		Ui.asset(elemIcon, "elem_" .. d.element)
		local tone = Theme.ELEMENT[d.element] or Theme.PURPLE
		local ring = elemCircle:FindFirstChildOfClass("UIStroke")
		if ring then
			ring.Color = tone
		end
		local lv = d.level or 1
		local need = DragonConfig.xpForLevel(lv)
		lvText.Text = tostring(lv)
		local rarity = Theme.RARITY[d.rarity]
		local rc = if rarity then rarity[1] else Theme.ACCENT
		nameStripe.BackgroundColor3 = rc
		local rLayer = elemCircle:FindFirstChild("CorniceRarita") :: ImageLabel?
		if rLayer then
			rLayer.ImageColor3 = rc
		end
		local gLayer = elemCircle:FindFirstChild("CorniceGemme") :: ImageLabel?
		if gLayer then
			gLayer.ImageColor3 = tone
		end
		local hex = string.format("#%02X%02X%02X", math.floor(rc.R * 255), math.floor(rc.G * 255), math.floor(rc.B * 255))
		local title = if type(d.name) == "string" and d.name ~= "" then d.name else Names.dragon(d.element)
		petName.Text = string.format('%s <font color="%s">· %s</font>', title, hex, Names.t(d.rarity))
		Slant.setFill(xpBar, (d.xp or 0) / need)
		local fill = xpBar:FindFirstChild("Pieno")
		if fill then
			Slant.paint(fill, tone, 0)
		end
		xpText.Text = string.format("%d / %d XP", math.floor(d.xp or 0), need)
	end
	player:GetAttributeChangedSignal("DragonData"):Connect(refreshPet)
	player:GetAttributeChangedSignal("HudNascosto"):Connect(function()
		refreshPet()
		layoutLeft()
	end)
	refreshPet()

	local armedAt = -math.huge
	skip.Activated:Connect(function()
		if os.clock() - armedAt > 4 then
			armedAt = os.clock()
			skip.Text = "SURE?"
			task.delay(4, function()
				if os.clock() - armedAt >= 4 then
					skip.Text = "SKIP"
				end
			end)
			return
		end
		armedAt = -math.huge
		skip.Text = "SKIP"
		-- durante le missioni il pulsante salta la missione, non il tutorial
		local name = if player:GetAttribute("TutorialText") then "SkipTutorial" else "SkipMission"
		local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild(name)
		if remote then
			(remote :: RemoteEvent):FireServer()
		end
	end)
	-- MISSIONE: testo del server "(n/N) OBIETTIVO|aiuto" ({KEY1}, {PITON}... = comandi del
	-- dispositivo in uso). Alcuni obiettivi cambiano da soli: senza piccozze in mano diventa
	-- "EQUIP YOUR ICE AXES", col chiodo piantato "UNCLIP THE ROPE"
	local HIGHLIGHT_AFTER, HELP_AFTER = 8, 18
	local lastGoal, goalSince, lastStep = "", os.clock(), ""
	hideMission.Activated:Connect(function()
		missionHidden = true
		mission.Visible = false
	end)
	missionPill.Activated:Connect(function()
		missionHidden = false
		missionPill.Visible = false
	end)
	local function updateMission(root: BasePart?)
		local tutorialLine = player:GetAttribute("TutorialText")
		local inTutorial = type(tutorialLine) == "string"
		local line = if inTutorial then tutorialLine else player:GetAttribute("MissionText")
		if type(line) ~= "string" then
			mission.Visible = false
			missionPill.Visible = false
			;(ClientState :: any).tutorialFocus = nil
			lastGoal = ""
			return
		end
		local stepNum, rest = string.match(line, "^%((%d+/%d+)%)%s*(.*)$")
		rest = rest or line
		local goal, help = string.match(rest, "^(.-)|(.*)$")
		goal = goal or rest
		help = help or ""
		local character = player.Character
		local holding = character and character:FindFirstChildOfClass("Tool")
		local holdName = if holding then holding.Name else ""
		if string.find(help, "{KEY1}", 1, true) and holdName ~= ClimbConfig.TOOL_NAME then
			goal, help = "EQUIP YOUR ICE AXES", "{KEY1}"
		elseif string.find(help, "{KEY2}", 1, true) and holdName ~= ClimbConfig.PICKAXE_NAME then
			goal, help = "EQUIP YOUR PICKAXE", "{KEY2}"
		elseif goal == "PLACE A PITON" and root and root:FindFirstChild("BelayRope") then
			goal, help = "UNCLIP THE ROPE", "{UNCLIP}"
		end
		-- passo nuovo = obiettivo completato
		local stepKey = (if inTutorial then "T" else "M") .. (stepNum or "")
		if stepKey ~= lastStep then
			if lastStep ~= "" and string.sub(lastStep, 1, 1) == string.sub(stepKey, 1, 1) then
				success("Objective complete!")
			end
			lastStep = stepKey
			-- nel tutorial ogni passo nuovo riapre il riquadro: le sue istruzioni hanno la precedenza
			if inTutorial then
				missionHidden = false
			end
		end
		if goal ~= lastGoal then
			lastGoal = goal
			goalSince = os.clock()
		end
		local waited = os.clock() - goalSince
		local shown = player:GetAttribute("HudNascosto") ~= true or inTutorial
		mission.Visible = shown and not missionHidden
		missionPill.Visible = shown and missionHidden
		missionPill.Text = if inTutorial then "◆ TUTORIAL  ▸" else "◆ MISSION  ▸"
		hideMission.Visible = true
		-- tipo (tutorial / missione), passo, ricompensa
		local reward = player:GetAttribute("MissionReward")
		mStep.Text = string.upper((if inTutorial then "Tutorial" else "Mission") .. (if stepNum then "  " .. stepNum else "")
			.. (if not inTutorial and type(reward) == "number" then string.format("  ·  +%d coins", reward) else ""))
		-- avanzamento dentro il passo ("MINE 5 ORES  3/5")
		local progress = player:GetAttribute("MissionProgress")
		mGoal.Text = string.upper(goal) .. (if not inTutorial and type(progress) == "string" then "  " .. progress else "")
		local target = player:GetAttribute("GuideTarget")
		mDist.Text = if root and typeof(target) == "Vector3" then string.format("%d m", math.floor((root.Position - target).Magnitude)) else ""
		-- aiuto progressivo: prima il comando si accende, poi compare la riga d'aiuto
		local key = string.match(help, "{(%u+%d?)}")
		;(ClientState :: any).tutorialFocus = if key and waited > HIGHLIGHT_AFTER then key else nil
		-- nel tutorial il comando si legge subito (azione, tasto, attrezzo: Mirko 16/10); nelle
		-- missioni l'aiuto resta progressivo
		local wantHelp = help ~= "" and (inTutorial or waited > HELP_AFTER)
		if wantHelp ~= helpShown then
			helpShown = wantHelp
			layoutLeft()
		end
		mHelp.Text = if wantHelp then Ui.hintText(help) else ""
		if os.clock() - armedAt > 4 then
			skip.Text = "SKIP"
		end
	end
	local lastHint, hintTime = "", 0
	local lastNotice: any = nil
	local shownHealth = 1
	local lastWeather = ""

	RunService.RenderStepped:Connect(function(dt)
		local pg = player.PlayerGui
		local menu = pg:FindFirstChild("MainMenu")
		local death = pg:FindFirstChild("DeathScreen")
		local menuOpen = menu ~= nil and menu:GetAttribute("MenuOpen") == true
		gui.Enabled = not (menuOpen or (death and death:IsA("ScreenGui") and death.Enabled) or player:GetAttribute("SchiusaInCorso") == true)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

		-- salute (scende in modo fluido)
		local health = if humanoid then math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1) else 0
		shownHealth += (health - shownHealth) * math.min(1, dt * 8)
		Slant.setFill(healthBar, shownHealth)
		healthText.Text = if humanoid then string.format("HP %d", math.ceil(humanoid.Health)) else ""

		-- stamina
		local ratio = math.clamp(ClientState.stamina / ClimbConfig.STAMINA_MAX, 0, 1)
		Slant.setFill(staminaBar, ratio)
		local sFill = staminaBar:FindFirstChild("Pieno")
		if sFill then
			Slant.paint(sFill, if ratio > 0.5 then Theme.GOOD elseif ratio > 0.2 then Theme.ACCENT else Theme.BAD, 0)
		end
		staminaText.Text = string.format("STAMINA %d%%", math.floor(ratio * 100))
		local shieldMax = (player:GetAttribute("ShieldMax") or 0) :: number
		if (shieldMax > 0) ~= shieldOn then
			shieldOn = shieldMax > 0
			layoutLeft()
		end
		if shieldOn then
			local sh = (player:GetAttribute("Shield") or 0) :: number
			Slant.setFill(shieldBar, sh / shieldMax)
			shieldText.Text = string.format("SHIELD %d", sh)
		end

		-- ora, meteo, quota, calore
		local t = Lighting.ClockTime
		local day = t >= 6 and t < 19
		local w = workspace:GetAttribute("Weather") :: any
		local ICON = {
			Clear = if day then "☀️" else "🌙",
			Cloudy = "☁️",
			Rain = "🌧️",
			Thunderstorm = "⛈️",
			Storm = "🌪️",
			Snow = "❄️",
		}
		local weatherKey = ({
			Clear = if day then "clear" else "night",
			Cloudy = "cloudy",
			Rain = "rain",
			Thunderstorm = "thunder",
			Storm = "storm",
			Snow = "snow",
		})[w] or (if day then "clear" else "night")
		if weatherKey ~= lastWeather then
			lastWeather = weatherKey
			wFallback.Visible = not Ui.asset(wIcon, "weather_" .. weatherKey)
			wFallback.Text = ICON[w] or (if day then "☀️" else "🌙")
		end
		timeText.Text = string.format("%02d:%02d", math.floor(t), math.floor((t % 1) * 60))
		dayText.Text = if day then "DAY" else "NIGHT"
		dayText.TextColor3 = if day then Theme.ACCENT else Theme.MUTED
		condText.Text = WEATHER_NAMES[w] or "Clear"
		local alt = if root then math.max(0, math.floor(root.Position.Y - 20)) else 0
		altText.Text = string.format("ALTITUDE  %d m", alt)
		local warmth = (player:GetAttribute("Warmth") or 100) :: number
		warmBar.Visible = (warmth < 99.5 or alt > Gear.COLD_ALTITUDE - 20) and not weatherFolded
		Slant.setFill(warmBar, warmth / 100)
		local wf = warmBar:FindFirstChild("Pieno")
		if wf then
			Slant.paint(wf, if warmth > 40 then Theme.ORANGE else Theme.BLUE, 0)
		end
		warmText.Text = if warmth <= 0 then "FREEZING!" else string.format("WARMTH %d%%", math.floor(warmth))
		local carrying = player:GetAttribute("CarryingEgg")
		local finderText = ClientState.eggFinder
		if type(carrying) == "string" then
			local parts = string.split(carrying, "|")
			finderText = string.format("Carrying a %s %s egg: take it to your nest!", Names.t(parts[2]), Names.t(parts[1]))
		end
		finder.Visible = finderText ~= nil and not weatherFolded
		finder.Text = finderText or ""

		updateMission(root)

		-- avvisi dal server e suggerimenti (restano 4 secondi)
		local notice = player:GetAttribute("Notice")
		local noticeTime = player:GetAttribute("NoticeTime")
		if type(notice) == "string" and noticeTime ~= lastNotice then
			lastNotice = noticeTime
			ClientState.hint = notice
		end
		-- nell'arena sei il drago: niente suggerimenti dell'arrampicata
		if (ClientState :: any).dragonMode and type(ClientState.hint) == "string" and not string.find(ClientState.hint :: string, "XP", 1, true) then
			ClientState.hint = ""
		end
		if ClientState.hint ~= lastHint then
			lastHint = ClientState.hint
			hintTime = os.clock()
		end
		hint.Text = if os.clock() - hintTime < 4 then lastHint else ""
		local combat = gui.Parent and gui.Parent:FindFirstChild("CombatHUD")
		hint.Visible = not combat or (Ui.node(combat, "Timer").Text == "" and Ui.node(combat, "Event").Text == "")
		if compact and noticePanel.Visible then
			hint.Visible = false
		end
	end)
end

return HUD
