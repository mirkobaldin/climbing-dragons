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
local HudLayout = require(script.Parent.HudLayout)
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
	-- una sola misura (la scala unica di UiView la adatta allo schermo), centrata in basso;
	-- si sposta come gli altri elementi dell'HUD (client/HudLayout)
	HudLayout.register("Barra", bar, "HOTBAR 1-5")
	local lastLogical = Vector2.new(1280, 680)
	local function placeBar()
		local was = cell
		cell = 70
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = if lastLogical.X < 600 then UDim2.new(0.5, 0, 1, -190) else UDim2.new(0.5, 0, 1, -10)
		bar.Size = UDim2.fromOffset(SLOTS * (cell + 6), cell)
		HudLayout.place("Barra", bar)
		if was ~= cell then
			queue()
		end
	end
	HudLayout.onChange(placeBar)
	Ui.viewportChanged(function(vp)
		lastLogical = Ui.fitScale(gui, vp)
		placeBar()
	end, gui)
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

	-- GIOCATORE: ritratto tondo e, accanto, le tre barre a parallelogramma una sotto l'altra con le
	-- cornici di Codex (Mirko 16/10: barre troppo grosse e staccate, ritratto troppo grande e con
	-- uno spazio fra la foto e la cornice)
	local me = Instance.new("Frame")
	me.Name = "Giocatore"
	me.BackgroundTransparency = 1
	me.Parent = gui
	local barsBox = Instance.new("Frame")
	barsBox.BackgroundTransparency = 1
	barsBox.Parent = me
	local healthBar = UiKit.bar(barsBox, "health", Theme.BAD, Theme.DARK, 6)
	local staminaBar = UiKit.bar(barsBox, "stamina", Theme.GOOD, Theme.DARK, 6)
	local shieldBar = UiKit.bar(barsBox, "shield", Theme.BLUE, Theme.DARK, 6)
	local framedBars = healthBar:GetAttribute("Cornice") == true
	local healthText = text(healthBar, "", 15)
	local staminaText = text(staminaBar, "", 12)
	local shieldText = text(shieldBar, "", 12)
	for _, l in { healthText, staminaText, shieldText } do
		l.ZIndex = 8
		l.Size = UDim2.new(1, -20, 1, 0)
		l.Position = UDim2.fromOffset(0, 0)
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	-- ritratto: la foto riempie tutto il foro della cornice (un filo piu' grande: il bordo sta sotto
	-- l'anello) e il suo fondo e' quello della foto stessa, tondo: niente cerchio che sporge
	local avatar = Instance.new("Frame")
	avatar.Name = "Avatar"
	avatar.BackgroundTransparency = 1
	avatar.ZIndex = 8
	avatar.Parent = me
	local photo = Instance.new("ImageLabel")
	photo.Name = "Foto"
	photo.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
	photo.BackgroundTransparency = 0
	photo.BorderSizePixel = 0
	photo.AnchorPoint = Vector2.new(0.5, 0.5)
	photo.Position = UDim2.fromScale(0.5, 0.5)
	photo.Size = UDim2.fromScale(1.08, 1.08)
	photo.ZIndex = 9
	photo.Parent = avatar
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.5, 0)
	pc.Parent = photo
	if not Cornici.apply(avatar, "frame_portrait_player", { mode = "circle", z = 12 }) then
		photo.Size = UDim2.fromScale(1, 1)
		local st = Instance.new("UIStroke")
		st.Color = Theme.ACCENT
		st.Thickness = 3
		st:SetAttribute("KeepStroke", true)
		st.Parent = photo
	end
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
	HudLayout.register("Giocatore", me, "YOU")

	-- DRAGO: cerchio dell'elemento col livello nel cerchietto, barra del nome e barra dell'XP a
	-- parallelogramma con la cornice (come quelle del giocatore)
	-- Con il pass Extra Dragon c'e' una seconda scheda uguale per il secondo drago (Mirko 17/10)
	local function makePet(name: string, title: string): { [string]: any }
		local pet = Instance.new("Frame")
		pet.Name = name
		pet.BackgroundTransparency = 1
		pet.Visible = false
		pet.Parent = gui
		local petBars = Instance.new("Frame")
		petBars.BackgroundTransparency = 1
		petBars.Parent = pet
		local nameBar = UiKit.bar(petBars, "stamina", Theme.DARK2, Theme.DARK2, 6)
		Slant.setFill(nameBar, 1)
		local nameStripe = Theme.frame(nameBar, Theme.ACCENT, 0)
		nameStripe.ZIndex = 7
		local petName = text(nameBar, "", 15)
		petName.ZIndex = 8
		local xpBar = UiKit.bar(petBars, "xp", Theme.PURPLE, Theme.DARK, 6)
		local xpText = text(xpBar, "", 12)
		xpText.ZIndex = 8
		xpText.TextXAlignment = Enum.TextXAlignment.Left
		local elemCircle = Instance.new("Frame")
		elemCircle.Name = "Elemento"
		elemCircle.BackgroundTransparency = 1
		elemCircle.ZIndex = 8
		elemCircle.Parent = pet
		-- fondo tondo dell'elemento: riempie il foro (sotto l'anello), non sporge
		local elemBack = circle(elemCircle, Theme.DARK2)
		elemBack.AnchorPoint = Vector2.new(0.5, 0.5)
		elemBack.Position = UDim2.fromScale(0.5, 0.5)
		elemBack.Size = UDim2.fromScale(1.06, 1.06)
		elemBack.ZIndex = 8
		local elemRing: UIStroke? = nil
		-- ritratto del drago di Codex: cornice, filo della rarita' e gemme dell'elemento (livelli
		-- grigi colorati in refreshPet)
		if Cornici.apply(elemCircle, "frame_portrait_dragon", { mode = "circle", z = 12 }) then
			Cornici.apply(elemCircle, "frame_portrait_dragon_rarity", { mode = "circle", z = 13, name = "CorniceRarita" })
			Cornici.apply(elemCircle, "frame_portrait_dragon_gem", { mode = "circle", z = 13, name = "CorniceGemme" })
		else
			elemBack.Size = UDim2.fromScale(1, 1)
			local st = Instance.new("UIStroke")
			st.Color = Theme.PURPLE
			st.Thickness = 3
			st:SetAttribute("KeepStroke", true)
			st.Parent = elemBack
			elemRing = st
		end
		local elemIcon = Instance.new("ImageLabel")
		elemIcon.BackgroundTransparency = 1
		elemIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		elemIcon.Position = UDim2.fromScale(0.5, 0.5)
		elemIcon.Size = UDim2.fromScale(0.86, 0.86)
		elemIcon.ZIndex = 9
		elemIcon.Parent = elemCircle
		local lvCircle = Instance.new("Frame")
		lvCircle.Name = "Livello"
		lvCircle.BackgroundTransparency = 1
		lvCircle.ZIndex = 10
		lvCircle.Parent = pet
		local lvDisc = circle(lvCircle, Theme.ACCENT)
		lvDisc.AnchorPoint = Vector2.new(0.5, 0.5)
		lvDisc.Position = UDim2.fromScale(0.5, 0.5)
		lvDisc.Size = UDim2.fromScale(1.08, 1.08)
		lvDisc.ZIndex = 10
		if not Cornici.apply(lvCircle, "frame_level_badge", { mode = "circle", z = 12 }) then
			lvDisc.Size = UDim2.fromScale(1, 1)
		end
		local lvText = text(lvCircle, "", 15, Color3.fromRGB(40, 24, 0))
		lvText.Size = UDim2.fromScale(1, 1)
		lvText.TextXAlignment = Enum.TextXAlignment.Center
		lvText.TextStrokeTransparency = 1
		lvText.ZIndex = 11
		HudLayout.register(name, pet, title)
		return { pet = pet, petBars = petBars, nameBar = nameBar, nameStripe = nameStripe, petName = petName,
			xpBar = xpBar, xpText = xpText, elemCircle = elemCircle, elemRing = elemRing, elemIcon = elemIcon,
			lvCircle = lvCircle, lvText = lvText }
	end
	local cards = { makePet("Drago", "YOUR DRAGON"), makePet("Drago2", "SECOND DRAGON") }

	-- METEO in alto a destra (Mirko 16/10: "il cerchio col sole e la casella blu dell'ora sono due
	-- pezzi staccati"): UN solo elemento nello stile delle cornici. Il medaglione col meteo si
	-- appoggia sulla targa dell'ora e della quota; aperto, sotto, giorno/notte e tempo, calore e
	-- uovo. Piegato resta solo medaglione + targa
	local weather = Instance.new("Frame")
	weather.Name = "Meteo"
	weather.BackgroundTransparency = 1
	weather.Parent = gui
	local plate = Instance.new("Frame")
	plate.Name = "Targa"
	plate.BackgroundColor3 = Color3.fromRGB(18, 19, 21)
	plate.BackgroundTransparency = 0.12
	plate.BorderSizePixel = 0
	plate.ZIndex = 2
	plate.Parent = weather
	if Cornici.apply(plate, "frame_currency_counter", { fill = Color3.fromRGB(18, 19, 21), fillTransparency = 0.08, z = 3 }) then
		plate.BackgroundTransparency = 1
	else
		UiKit.edge(plate, UiKit.ACCENT, 1, 0.4)
	end
	local timeText = UiKit.label(plate, "12:00", "stat", 24)
	timeText.TextXAlignment = Enum.TextXAlignment.Left
	timeText.ZIndex = 5
	local plateSep = Theme.frame(plate, UiKit.ACCENT, 0.55)
	plateSep.ZIndex = 5
	local altText = UiKit.label(plate, "", "stat", 16)
	altText.TextXAlignment = Enum.TextXAlignment.Right
	altText.TextColor3 = UiKit.ICE
	altText.ZIndex = 5
	local wCircle = Instance.new("Frame")
	wCircle.Name = "Medaglione"
	wCircle.BackgroundTransparency = 1
	wCircle.ZIndex = 6
	wCircle.Parent = weather
	local wBack = circle(wCircle, Color3.fromRGB(28, 32, 44))
	wBack.AnchorPoint = Vector2.new(0.5, 0.5)
	wBack.Position = UDim2.fromScale(0.5, 0.5)
	wBack.Size = UDim2.fromScale(1.06, 1.06)
	wBack.ZIndex = 6
	if not Cornici.apply(wCircle, "frame_currency_medallion", { mode = "circle", z = 9 }) then
		wBack.Size = UDim2.fromScale(1, 1)
		local st = Instance.new("UIStroke")
		st.Color = UiKit.ACCENT
		st.Thickness = 2
		st:SetAttribute("KeepStroke", true)
		st.Parent = wBack
	end
	local wIcon = Instance.new("ImageLabel")
	wIcon.BackgroundTransparency = 1
	wIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	wIcon.Position = UDim2.fromScale(0.5, 0.5)
	wIcon.Size = UDim2.fromScale(0.82, 0.82)
	wIcon.ZIndex = 7
	wIcon.Parent = wCircle
	local wFallback = text(wCircle, "", 24)
	wFallback.Size = UDim2.fromScale(1, 1)
	wFallback.TextXAlignment = Enum.TextXAlignment.Center
	wFallback.ZIndex = 7
	-- dettagli (aperto): pannello attaccato sotto la targa
	local details = Instance.new("Frame")
	details.Name = "Dettagli"
	details.BackgroundTransparency = 1
	details.ZIndex = 1
	details.Parent = weather
	UiKit.panel(details, { border = 8 })
	local dayText = UiKit.label(details, "DAY", "name", 15)
	dayText.ZIndex = 4
	local condText = UiKit.label(details, "Clear", "name", 15)
	condText.TextXAlignment = Enum.TextXAlignment.Right
	condText.TextColor3 = UiKit.ICE
	condText.ZIndex = 4
	local warmBar = UiKit.bar(details, "stamina", Theme.ORANGE, Theme.DARK2, 6)
	local warmText = text(warmBar, "", 11)
	warmText.ZIndex = 8
	warmText.Size = UDim2.fromScale(1, 1)
	warmText.TextXAlignment = Enum.TextXAlignment.Center
	local finder = text(details, "", 14, Theme.ACCENT)
	finder.ZIndex = 4
	finder.TextWrapped = true
	finder.TextXAlignment = Enum.TextXAlignment.Center
	HudLayout.register("Meteo", weather, "WEATHER")

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

	-- TASTI DELL'HUD in un gruppo spostabile: ⚙ (modifica dell'HUD, client/HudLayout), "?"
	-- (pannello dei comandi, client/ControlsPanel) e HIDE HUD (via le informazioni: giocatore,
	-- drago, missione, monete, montepremi, meteo; restano i comandi, le frecce e i suggerimenti)
	local opts = Instance.new("Frame")
	opts.Name = "Opzioni"
	opts.BackgroundTransparency = 1
	opts.Parent = gui
	-- ⚙ nello stile delle cornici: medaglione con l'icona delle impostazioni (Mirko 16/10:
	-- l'ingranaggio azzurro di prima "fa schifo" e copriva THROW)
	local gear = Instance.new("TextButton")
	gear.Name = "ModificaHUD"
	gear.Text = ""
	gear.BackgroundTransparency = 1
	gear.AutoButtonColor = false
	gear.ZIndex = 5
	gear:SetAttribute("UiNative", true)
	gear.Parent = opts
	local gearBack = circle(gear, Color3.fromRGB(28, 32, 44))
	gearBack.AnchorPoint = Vector2.new(0.5, 0.5)
	gearBack.Position = UDim2.fromScale(0.5, 0.5)
	gearBack.Size = UDim2.fromScale(1.04, 1.04)
	gearBack.ZIndex = 5
	if not Cornici.apply(gear, "frame_currency_medallion", { mode = "circle", z = 7 }) then
		gearBack.Size = UDim2.fromScale(1, 1)
		UiKit.edge(gearBack, UiKit.ACCENT, 1, 0.3)
	end
	local gearIcon = Instance.new("ImageLabel")
	gearIcon.BackgroundTransparency = 1
	gearIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	gearIcon.Position = UDim2.fromScale(0.5, 0.5)
	gearIcon.Size = UDim2.fromScale(0.66, 0.66)
	gearIcon.ZIndex = 6
	gearIcon.Parent = gear
	if not Ui.asset(gearIcon, "icon_settings") then
		local g = text(gear, "⚙", 20)
		g.Size = UDim2.fromScale(1, 1)
		g.TextXAlignment = Enum.TextXAlignment.Center
		g.ZIndex = 6
	end
	gear.MouseEnter:Connect(function()
		gearIcon.ImageColor3 = UiKit.ACCENT
	end)
	gear.MouseLeave:Connect(function()
		gearIcon.ImageColor3 = Color3.new(1, 1, 1)
	end)
	gear.Activated:Connect(function()
		HudLayout.setEditing(not HudLayout.editing())
	end)
	local helpBtn = Instance.new("TextButton")
	helpBtn.Name = "Comandi"
	helpBtn.ZIndex = 5
	helpBtn.Parent = opts
	UiKit.button(helpBtn, "secondary")
	helpBtn.Text = "?"
	helpBtn.Activated:Connect(function()
		require(script.Parent.ControlsPanel).open(true)
	end)
	local hideBtn = Instance.new("TextButton")
	hideBtn.Name = "NascondiHUD"
	hideBtn.Text = "HIDE HUD"
	hideBtn.ZIndex = 5
	hideBtn.Parent = opts
	UiKit.button(hideBtn, "secondary")
	-- NOTIZIE: medaglione come il ⚙, primo del gruppo, col pallino rosso quando c'e' un
	-- aggiornamento non visto (Mirko 17/10: il ritratto resta, le notizie stanno da un'altra parte)
	local NewsPanel = require(script.Parent.NewsPanel)
	local news = Instance.new("TextButton")
	news.Name = "Notizie"
	news.Text = ""
	news.BackgroundTransparency = 1
	news.AutoButtonColor = false
	news.ZIndex = 5
	news:SetAttribute("UiNative", true)
	news.Parent = opts
	local newsBack = circle(news, Color3.fromRGB(28, 32, 44))
	newsBack.AnchorPoint = Vector2.new(0.5, 0.5)
	newsBack.Position = UDim2.fromScale(0.5, 0.5)
	newsBack.Size = UDim2.fromScale(1, 1)
	newsBack.ZIndex = 4
	Cornici.apply(news, "frame_currency_medallion", { mode = "circle", z = 7 })
	local newsIcon = Instance.new("ImageLabel")
	newsIcon.BackgroundTransparency = 1
	newsIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	newsIcon.Position = UDim2.fromScale(0.5, 0.5)
	newsIcon.Size = UDim2.fromScale(0.62, 0.62)
	newsIcon.ZIndex = 6
	newsIcon.Parent = news
	if not Ui.asset(newsIcon, "icon_news") then
		Ui.asset(newsIcon, "icon_quest")
	end
	local dot = circle(news, Color3.fromRGB(235, 60, 60))
	dot.Name = "Nuovo"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.84, 0.16)
	dot.Size = UDim2.fromScale(0.32, 0.32)
	dot.ZIndex = 9
	local ds = Instance.new("UIStroke")
	ds.Color = Color3.fromRGB(20, 10, 10)
	ds.Thickness = 2
	ds:SetAttribute("KeepStroke", true)
	ds.Parent = dot
	local function paintNews()
		dot.Visible = NewsPanel.unread()
	end
	NewsPanel.onSeen(paintNews)
	HudLayout.onChange(paintNews) -- ControlsLayout arriva dal server dopo l'avvio
	paintNews()
	news.MouseEnter:Connect(function()
		newsIcon.ImageColor3 = Color3.fromRGB(255, 225, 150)
	end)
	news.MouseLeave:Connect(function()
		newsIcon.ImageColor3 = Color3.new(1, 1, 1)
	end)
	news.Activated:Connect(function()
		if not HudLayout.editing() then
			NewsPanel.open()
		end
	end)
	HudLayout.register("Opzioni", opts, "HUD BUTTONS")
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

	-- METEO pieghevole: tocco/click = solo medaglione e targa, di nuovo = anche i dettagli.
	-- Lo stato resta per tutta la partita, anche nascondendo e rimostrando l'HUD
	local weatherFolded = Ui.touch() -- sul telefono parte chiuso (meno spazio occupato)
	weather.Active = true

	local P = Ui.px
	local logical = Vector2.new(1280, 680)
	local shieldOn = false
	-- UNA sola impaginazione in pixel logici (UiView.fitScale porta ogni schermo ad almeno
	-- 1280x540: sul telefono e' la stessa del computer, piu' piccola). Prima c'era un ramo
	-- "telefono" a parte con misure diverse
	local function layoutLeft()
		local x0, y0 = 12, 8
		local av = 76 -- ritratto (prima 96: troppo grande)
		local bx = math.floor(av * 0.5)
		-- testo delle barre: dopo il BORDO del ritratto (le barre partono dal suo centro; prima il
		-- testo partiva a meta' ritratto e "HP 100" restava coperto)
		local barX = av + 6
		-- barre una sotto l'altra, attaccate: la cornice di una tocca quella dopo
		local hH, sH = 20, 15
		local hW, sW, shW = 268, 246, 228
		local gap = if framedBars then 13 else 3
		local yH = if shieldOn then 4 else 12
		local yS = yH + hH + gap
		local ySh = yS + sH + gap
		P(me, 0, x0, 0, y0, bx + hW + 24, av + 8)
		HudLayout.place("Giocatore", me)
		P(avatar, 0, 0, 0, 4, av, av)
		P(barsBox, 0, bx, 0, 0, hW + 20, av + 8)
		P(healthBar, 0, 0, 0, yH, hW, hH)
		P(staminaBar, 0, 0, 0, yS, sW, sH)
		P(shieldBar, 0, 0, 0, ySh, shW, sH)
		shieldBar.Visible = shieldOn
		for _, l in { healthText, staminaText, shieldText } do
			l.Position = UDim2.fromOffset(barX - bx + 4, 0)
			l.Size = UDim2.new(1, -(barX - bx + 18), 1, 0)
		end
		Ui.text(healthText, 15, true)
		Ui.text(staminaText, 12, true)
		Ui.text(shieldText, 12, true)
		-- nome sotto la stamina quando non c'e' lo scudo
		P(nameLabel, 0, barX + 4, 0, ySh - 2, 200, 18)
		nameLabel.Visible = not shieldOn
		Ui.text(nameLabel, 13, true)
		-- drago sotto
		local py = y0 + av + 22 -- (il cerchietto del livello non tocca l'anello del ritratto)
		local ec = 60
		-- una scheda per drago al seguito (la seconda sotto la prima, col pass Extra Dragon)
		local cy = py
		for i, c in cards do
			P(c.pet, 0, x0 + 24, 0, cy, ec / 2 + 262, ec + 8)
			HudLayout.place(if i == 1 then "Drago" else "Drago2", c.pet)
			P(c.elemCircle, 0, 0, 0, 4, ec, ec)
			-- livello in alto a sinistra, FUORI dal ritratto (Mirko 17/10: copriva quasi tutta
			-- l'icona dell'elemento). La cornice del distintivo e' il doppio del suo foro: foro
			-- piccolo e centro a ~45 pixel logici dal centro del ritratto, tocca solo l'anello
			local lv = 22
			P(c.lvCircle, 0, -4 - lv / 2, 0, 4 - lv / 2, lv, lv)
			Ui.text(c.lvText, 13, true)
			P(c.petBars, 0, math.floor(ec * 0.5), 0, 4, 262, ec)
			c.nameBar.Visible = true
			local nb, xb = 20, 13
			local nbY = 6
			local xbY = nbY + nb + (if framedBars then 12 else 3)
			P(c.nameBar, 0, 0, 0, nbY, 250, nb)
			local inset = math.floor(ec * 0.5) + 6
			P(c.nameStripe, 0, inset - 4, 0, 3, 3, nb - 6)
			P(c.petName, 0, inset + 2, 0, 0, 200, nb)
			Ui.text(c.petName, 14, true)
			P(c.xpBar, 0, 0, 0, xbY, 226, xb)
			c.xpText.Position = UDim2.fromOffset(inset + 2, 0)
			c.xpText.Size = UDim2.new(1, -(inset + 16), 1, 0)
			Ui.text(c.xpText, 11, true)
			if c.pet.Visible then
				cy += ec + 18
			end
		end
		-- missione sotto i draghi (o sotto il giocatore se non hai un drago al seguito)
		local my = cy
		local mw = 340
		local mh = if helpShown then 98 else 62
		P(mission, 0, x0, 0, my, mw, mh)
		HudLayout.place("Missione", mission)
		P(mDiamond, 0, 14, 0, 34, 9, 9)
		P(mStep, 0, 12, 0, 4, mw - 160, 18)
		UiKit.text(mStep, "status", 12)
		P(skip, 1, -6, 0, 5, 64, 22, 1, 0)
		skip.TextSize = 13
		P(hideMission, 1, -76, 0, 5, 64, 22, 1, 0)
		hideMission.TextSize = 13
		if HudLayout.get("Missione") then
			-- spostata: la pillola si riapre dove sta il riquadro
			missionPill.AnchorPoint = Vector2.new(0.5, 0.5)
			missionPill.Position = mission.Position
			missionPill.Size = UDim2.fromOffset(150, 30)
		else
			P(missionPill, 0, x0, 0, my, 150, 30)
		end
		missionPill.TextSize = 15
		P(mGoal, 0, 32, 0, 25, mw - 120, 30)
		UiKit.text(mGoal, "name", 19)
		P(mDist, 1, -10, 0, 28, 84, 28, 1, 0)
		UiKit.text(mDist, "stat", 18)
		mDist.TextColor3 = UiKit.ICE
		mDist.TextXAlignment = Enum.TextXAlignment.Right
		P(mHelp, 0, 14, 0, 56, mw - 28, 38)
		UiKit.text(mHelp, "body", 15)
		mHelp.TextColor3 = UiKit.MUTED
		mHelp.Visible = helpShown
		gui:SetAttribute("LeftBottom", my + mh + 10)
	end
	HudLayout.register("Missione", mission, "MISSION")
	local function layoutWeather()
		local folded = weatherFolded
		local c = 58 -- medaglione
		local plateW, plateH = 196, 42
		local over = math.floor(c * 0.5) -- il medaglione copre l'inizio della targa
		local w = over + plateW
		local frozen = warmBar.Visible and not folded
		local hasFinder = finder.Visible and not folded
		local detH = 44 + (if frozen then 30 else 0) + (if hasFinder then 44 else 0)
		local h = if folded then c else c + detH
		P(weather, 1, -12, 0, 8, w, h, 1, 0)
		HudLayout.place("Meteo", weather)
		P(wCircle, 0, 0, 0, 0, c, c)
		P(plate, 0, over, 0, math.floor((c - plateH) / 2), plateW, plateH)
		-- dentro la targa: ora a sinistra (dopo il medaglione), quota a destra, filo in mezzo
		local tx = math.floor(c * 0.5) + 10
		P(timeText, 0, tx, 0, 0, 70, plateH)
		UiKit.text(timeText, "stat", 24)
		P(plateSep, 0, tx + 74, 0.5, 0, 1, math.floor(plateH * 0.46), 0, 0.5)
		P(altText, 0, tx + 80, 0, 0, plateW - (tx + 80) - 18, plateH)
		UiKit.text(altText, "stat", 16)
		altText.TextColor3 = UiKit.ICE
		altText.TextXAlignment = Enum.TextXAlignment.Right
		details.Visible = not folded
		P(details, 0, 10, 0, c - 6, w - 10, detH + 6)
		P(dayText, 0, 18, 0, 12, (w - 46) / 2, 22)
		P(condText, 1, -18, 0, 12, (w - 46) / 2, 22, 1, 0)
		local y = 42
		P(warmBar, 0, 20, 0, y, w - 50, 13)
		Ui.text(warmText, 11, true)
		if frozen then
			y += 30
		end
		P(finder, 0, 14, 0, y, w - 38, 38)
		Ui.fit(finder, 14, 10, true)
		finder.TextXAlignment = Enum.TextXAlignment.Center
		-- tasti dell'HUD: a sinistra del meteo, alla sua altezza (non si sovrappongono)
		local bH = 36
		P(opts, 1, -(12 + w + 12), 0, 8 + math.floor((c - bH) / 2), bH * 3 + 104 + 18, bH, 1, 0)
		HudLayout.place("Opzioni", opts)
		P(news, 0, 0, 0, 0, bH, bH)
		P(gear, 0, bH + 6, 0, 0, bH, bH)
		P(helpBtn, 0, 2 * bH + 12, 0, 0, bH, bH)
		helpBtn.TextSize = 17
		P(hideBtn, 0, 3 * bH + 18, 0, 0, 104, bH)
		hideBtn.TextSize = 15
	end
	local function layoutAll()
		layoutLeft()
		layoutWeather()
		local portrait = logical.X < 600
		local w = if portrait then logical.X - 20 else math.min(520, math.max(220, logical.X - 420 - 290))
		-- avvisi in alto al centro, sotto la striscia delle monete
		P(noticePanel, 0.5, 0, 0, 126, w, 44, 0.5, 0)
		P(noticePanel.Text, 0, 8, 0, 6, w - 16, 32)
		P(hint, 0.5, 0, 1, -100, math.min(560, logical.X - 32), 40, 0.5, 1)
		Ui.text(noticePanel.Text, 17, true)
		Ui.text(hint, 19, true)
		local _ = questTitle
		local _ = questText
		noticePosition = noticePanel.Position
	end
	HudLayout.onChange(layoutAll)
	Ui.viewportChanged(function(vp)
		logical = Ui.fitScale(gui, vp)
		UiKit.setScale((gui:GetAttribute("ScalaVera") or 1) :: number)
		layoutAll()
		P(toast, 0.5, 0, 0, 66, 440, 54, 0.5, 0)
	end, gui)
	weather.InputBegan:Connect(function(input)
		if HudLayout.editing() then
			return
		end
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

	local function refreshCard(c: { [string]: any }, d: any)
		c.pet.Visible = d ~= nil and player:GetAttribute("HudNascosto") ~= true
		if not d then
			return
		end
		Ui.asset(c.elemIcon, "elem_" .. d.element)
		local tone = Theme.ELEMENT[d.element] or Theme.PURPLE
		if c.elemRing then
			c.elemRing.Color = tone
		end
		local lv = d.level or 1
		local need = DragonConfig.xpForLevel(lv)
		c.lvText.Text = tostring(lv)
		local rarity = Theme.RARITY[d.rarity]
		local rc = if rarity then rarity[1] else Theme.ACCENT
		c.nameStripe.BackgroundColor3 = rc
		local rLayer = c.elemCircle:FindFirstChild("CorniceRarita") :: ImageLabel?
		if rLayer then
			rLayer.ImageColor3 = rc
		end
		local gLayer = c.elemCircle:FindFirstChild("CorniceGemme") :: ImageLabel?
		if gLayer then
			gLayer.ImageColor3 = tone
		end
		local hex = string.format("#%02X%02X%02X", math.floor(rc.R * 255), math.floor(rc.G * 255), math.floor(rc.B * 255))
		local title = if type(d.name) == "string" and d.name ~= "" then d.name else Names.dragon(d.element)
		c.petName.Text = string.format('%s <font color="%s">· %s</font>', title, hex, Names.t(d.rarity))
		Slant.setFill(c.xpBar, (d.xp or 0) / need)
		local fill = c.xpBar:FindFirstChild("Pieno")
		if fill then
			Slant.paint(fill, tone, 0)
		end
		c.xpText.Text = string.format("%d / %d XP", math.floor(d.xp or 0), need)
	end
	local lastCount = -1
	local function refreshPet()
		local ok, data = pcall(function()
			return HttpService:JSONDecode(player:GetAttribute("DragonData") :: string)
		end)
		local count = 0
		for i, c in cards do
			local d: any = nil
			if ok and type(data) == "table" and data.equipped then
				for _, x in data.dragons or {} do
					if x.id == data.equipped[i] then
						d = x
					end
				end
			end
			refreshCard(c, d)
			if c.pet.Visible then
				count += 1
			end
		end
		-- comprato il pass o messo/tolto il secondo drago: la missione scende o sale
		if count ~= lastCount then
			lastCount = count
			task.defer(layoutLeft)
		end
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
		-- tutorial obbligatorio per chi e' nuovo (Mirko 17/10): niente SKIP finche' non e' finito
		-- (server/Tutorial mette TutorialSaltabile a chi ha gia' draghi o e' admin)
		skip.Visible = not inTutorial or player:GetAttribute("TutorialSaltabile") == true
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
		altText.Text = string.format("▲ %d m", alt)
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
		if logical.Y < 560 and noticePanel.Visible then
			hint.Visible = false -- schermi bassi: un avviso alla volta
		end
	end)
end

return HUD
