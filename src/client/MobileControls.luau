--!strict
-- Comandi del telefono: ad arco attorno al tasto del salto di Roblox, nell'angolo in basso a
-- destra (sotto il pollice). Prima stavano in una fila staccata dal bordo, verso il centro, e
-- Ride / Fire finivano a meta' schermo sotto il riquadro del meteo. Dal computer si provano con
-- gli attributi SimTouch = true e SimViewport = Vector2.new(844, 354) sul giocatore.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("UiView"))
local Theme = require(script.Parent.Theme)
local Config = require(Shared:WaitForChild("ClimbConfig"))
local Climbing = require(script.Parent.Climbing)
local ClientState = require(script.Parent.ClientState)
local Sprint = require(script.Parent.Sprint)
local PickaxeThrow = require(script.Parent.PickaxeThrow)
local TrainingFX = require(script.Parent.TrainingFX)
local Glider = require(script.Parent.Glider)
local DragonRide = require(script.Parent.DragonRide)
local HudLayout = require(script.Parent.HudLayout)
local player = Players.LocalPlayer
local MobileControls = {}

-- ordine nell'arco: il primo sta subito a sinistra del salto (il piu' comodo), poi si sale
local ORDER = { "Fire", "Glide", "Throw", "Mine", "Grapple", "Climb", "JumpOff", "Piton", "Release", "Shoot", "Ride", "Run" }
-- posto fisso di ogni azione nell'arco attorno al salto (1 = il piu' comodo, accanto al salto):
--   1 azione principale: Climb (a piedi vicino alla parete) / Piton (in parete) / Fire (in groppa)
--     / Shoot (forma di drago): non capitano mai insieme
--   2 attrezzo in mano: JumpOff (in parete) / Mine (piccone) / Throw (piccozze) / Grapple (rampino)
--   3 Release (corda attaccata) / Glide (in caduta)
--   4 Ride / Land      5 Run / Walk
local SLOT_OF: { [string]: number } = {
	Climb = 1, Piton = 1, Fire = 1, Shoot = 1,
	JumpOff = 2, Mine = 2, Throw = 2, Grapple = 2,
	Release = 3, Glide = 3,
	Ride = 4,
	Run = 5,
}
-- un colore per comando: prima erano tutti uguali (blu scuro) e non si distinguevano
local COLORS: { [string]: Color3 } = {
	Fire = Theme.BAD,
	Shoot = Theme.BAD,
	Glide = Theme.BLUE,
	Ride = Theme.ORANGE,
	Throw = Theme.ORANGE,
	Mine = Theme.BAD,
	Grapple = Theme.TEAL,
	Climb = Theme.GOOD,
	JumpOff = Theme.ORANGE,
	Piton = Theme.PURPLE,
	Release = Theme.GOOD,
	Run = Theme.BLUE,
}

function MobileControls.start()
	local gui = Ui.screen("MobileControls")
	gui.Enabled = Ui.touch()
	local actions = Ui.node(gui, "Actions")
	-- l'arco si misura dall'angolo in basso a destra: cornice di grandezza zero sull'angolo (una
	-- cornice grande sopra lo schermo avrebbe preso i tocchi della camera)
	actions.AnchorPoint = Vector2.new(1, 1)
	actions.Position = UDim2.fromScale(1, 1)
	actions.Size = UDim2.fromOffset(0, 0)
	actions.ClipsDescendants = false

	-- pulsanti nuovi (parapendio, monta, colpo del drago) copiati da Run
	local function extra(name: string, label: string, icon: string?): TextButton
		local b = actions.Run:Clone()
		b.Name = name
		-- la copia della cornice e della scritta di Run restava ferma su "Run": si rifanno
		for _, n in { "AssetSurface", "AssetCaption", "Tinta" } do
			local old = b:FindFirstChild(n)
			if old then
				old:Destroy()
			end
		end
		b.Text = label
		b.Parent = actions
		-- prima l'icona, poi la cornice (la scritta va sotto l'icona o in mezzo se non c'e')
		local img = b:FindFirstChild("Icon") :: ImageLabel?
		if img then
			if icon then
				Ui.asset(img, icon)
			else
				img.Image = ""
				img.Visible = false
			end
		end
		local skin = b:GetAttribute("UiAsset")
		if type(skin) == "string" then
			Ui.skin(b, skin)
		end
		return b
	end
	-- modifica dei tasti (pulsante ⚙): mentre li sposti non fanno partire le azioni
	local editing = false
	local function on(b: GuiButton, fn: () -> ())
		b.Activated:Connect(function()
			if not editing then
				fn()
			end
		end)
	end
	extra("Glide", "Glide")
	extra("Ride", "Ride")
	extra("Fire", "Fire", "act_shoot")

	on(actions.Run, function()
		actions.Run.Text = if Sprint.toggle() then "Walk" else "Run"
	end)
	on(actions.Climb, function()
		Climbing.grabNearest()
	end)
	on(actions.JumpOff, Climbing.jumpOff)
	on(actions.Release, Climbing.releaseRope)
	on(actions.Throw, function()
		task.spawn(PickaxeThrow.activate)
	end)
	on(actions.Shoot, function()
		if TrainingFX.shoot then
			TrainingFX.shoot()
		end
	end)
	on(actions.Glide, function()
		Glider.toggle(true)
	end)
	on(actions.Ride, DragonRide.toggle)
	on(actions.Fire, DragonRide.fire)
	local function activateTool(name: string)
		local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if tool and tool.Name == name then
			tool:Activate()
		end
	end
	on(actions.Grapple, function()
		activateTool(Config.GRAPPLE_NAME)
	end)
	on(actions.Mine, function()
		activateTool(Config.PICKAXE_NAME)
	end)
	local function tap(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	actions.Piton.InputBegan:Connect(function(input)
		if tap(input) and not editing then
			Climbing.aimBegin()
		end
	end)
	actions.Piton.InputEnded:Connect(function(input)
		if tap(input) and not editing then
			Climbing.aimFinish()
		end
	end)
	local labels = { JumpOff = "Jump", Release = "Unclip", Grapple = "Hook" }
	for name, label in labels do
		actions[name].Text = label
	end
	-- tondi, colorati, testo in basso sotto l'icona
	for _, name in ORDER do
		local b = actions[name] :: TextButton
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Font = Enum.Font.GothamBlack
		b.TextYAlignment = Enum.TextYAlignment.Bottom
		local icon = b:FindFirstChild("Icon") :: ImageLabel?
		if icon then
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 4)
			icon.Size = UDim2.fromOffset(28, 28)
		end
		local corner = b:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0.5, 0)
		end
		Ui.tint(b, COLORS[name] or Theme.BLUE, true)
		-- etichetta intera sotto l'icona (prima "Ju...", "Pit...": il testo del pulsante si
		-- rimpiccioliva e troncava dentro il cerchio). Il testo vero del pulsante resta (altri
		-- script lo cambiano, es. Ride/Land) ma invisibile: l'etichetta lo copia, in Oswald stretto,
		-- e puo' uscire un poco dai lati del cerchio. Il pulsante non si rimpicciolisce.
		local tag = Instance.new("TextLabel")
		tag.Name = "Etichetta"
		tag.BackgroundTransparency = 1
		tag.AnchorPoint = Vector2.new(0.5, 1)
		tag.Position = UDim2.new(0.5, 0, 1, -3)
		tag.Size = UDim2.new(1.4, 0, 0, 16)
		tag.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
		tag.TextColor3 = Color3.new(1, 1, 1)
		tag.TextStrokeTransparency = 0.35
		tag.TextScaled = false
		tag.TextTruncate = Enum.TextTruncate.None
		tag.TextWrapped = false
		tag.ZIndex = b.ZIndex + 3
		tag:SetAttribute("TipoTesto", "button")
		tag.Parent = b
		-- una scritta sola: via quella della cornice (AssetCaption di Ui.skin), anche dopo
		b:SetAttribute("OwnCaption", true)
		local caption = b:FindFirstChild("AssetCaption")
		if caption then
			caption:Destroy()
		end
		b.ChildAdded:Connect(function(c)
			if c.Name == "AssetCaption" then
				task.defer(function()
					c:Destroy()
				end)
			end
		end)
		b.ClipsDescendants = false
		local function copy()
			tag.Text = string.upper(b.Text)
		end
		b:GetPropertyChangedSignal("Text"):Connect(copy)
		copy()
		b.TextTransparency = 1
		b.TextStrokeTransparency = 1
		-- TASTO PIATTO (Mirko 17/10: "troppo colorati", "non farli sembrare in rilievo, devono
		-- essere piatti"): fondo scuro traslucido, anello sottile e icona del colore dell'azione,
		-- scritta bianca. Quanto si vedono lo sceglie il giocatore (barra EDIT HUD, voce Opacita di
		-- ControlsLayout, HudLayout.opacity). Premuto: il fondo prende il colore dell'azione
		-- niente piu' immagini dei vecchi pulsanti: UIPolish, al tocco e al passaggio del mouse,
		-- le rimetteva leggendo l'attributo UiAsset (Mirko 17/10: "quando cambi la posizione
		-- tornano le vecchie icone colorate")
		b:SetAttribute("UiAsset", nil)
		local surface = b:FindFirstChild("AssetSurface")
		if surface then
			surface:Destroy()
		end
		b.ChildAdded:Connect(function(c)
			if c.Name == "AssetSurface" then
				task.defer(function()
					c:Destroy()
				end)
			end
		end)
		local face = Instance.new("Frame")
		face.Name = "Faccia"
		face.BorderSizePixel = 0
		face.Size = UDim2.fromScale(1, 1)
		face.ZIndex = 1
		face.Active = false
		face.Parent = b
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0.5, 0)
		fc.Parent = face
		local rim = Instance.new("UIStroke")
		rim.Thickness = 2
		rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rim:SetAttribute("KeepStroke", true)
		rim.Parent = face
		for _, st in b:GetChildren() do
			if st:IsA("UIStroke") and not st:GetAttribute("KeepStroke") then
				st.Enabled = false
			end
		end
		local pressed = false
		local function paint()
			local col = b.BackgroundColor3
			local o = HudLayout.opacity()
			if b.BackgroundTransparency < 1 then
				b.BackgroundTransparency = 1
			end
			face.BackgroundColor3 = if pressed then col:Lerp(Color3.new(0, 0, 0), 0.35) else Color3.fromRGB(10, 13, 20)
			face.BackgroundTransparency = if pressed then 0.25 else 1 - 0.7 * o
			rim.Color = col
			rim.Transparency = 1 - o
			if icon then
				-- icona non tinta: le icone di adesso sono gia' colorate (quelle nuove, bianche e
				-- monocrome, docs/CODEX_ICONE_V2.md, si potranno tingere col colore dell'azione)
				icon.ImageColor3 = Color3.new(1, 1, 1)
				icon.ImageTransparency = (1 - o) * 0.7
			end
			tag.TextTransparency = (1 - o) * 0.7
			tag.TextStrokeTransparency = 0.35 + (1 - o) * 0.5
		end
		b:GetPropertyChangedSignal("BackgroundColor3"):Connect(paint)
		b:GetPropertyChangedSignal("BackgroundTransparency"):Connect(paint)
		HudLayout.onChange(paint)
		paint()
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				pressed = true
				paint()
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				pressed = false
				paint()
			end
		end)
		-- rilascio ovunque: se il tasto cambia sotto il dito (Ride -> Land) il suo InputEnded non
		-- arriva e restava "premuto" (pieno di colore)
		game:GetService("UserInputService").InputEnded:Connect(function(input)
			if pressed and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
				pressed = false
				paint()
			end
		end)
		b.MouseLeave:Connect(function()
			pressed = false
			paint()
		end)
		if icon then
			icon.ZIndex = math.max(icon.ZIndex, 2)
		end
	end

	local vp = Vector2.new(844, 390)
	Ui.viewportChanged(function(size)
		vp = size
	end)
	local last = ""
	-- tasti spostati dal giocatore: { Nome = { x, y } } in pixel dall'angolo in basso a destra,
	-- dentro ControlsLayout insieme alle posizioni dell'HUD (client/HudLayout)
	local custom: { [string]: any } = HudLayout.data()
	HudLayout.onChange(function()
		custom = HudLayout.data()
		last = ""
	end)
	local function refresh()
		local touch = Ui.touch()
		custom = HudLayout.data()
		local pg = player.PlayerGui
  local menu = pg:FindFirstChild("MainMenu")
  local travel = pg:FindFirstChild("Teletrasporto")
  local panel = travel and travel:FindFirstChild("Panel") :: GuiObject?
  local death = pg:FindFirstChild("DeathScreen")
  gui.Enabled = touch and not ((menu and menu:GetAttribute("MenuOpen") == true) or (panel and panel.Visible)
   or (death and death:IsA("ScreenGui") and death.Enabled) or player:GetAttribute("SchiusaInCorso") == true)
		if not touch then
			return
		end
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local climbing = ClientState.climbing
		local dragon = ClientState.dragonMode
		local riding = ClientState.riding
		local onFoot = not dragon and not riding
		local available = {
			Run = not climbing and onFoot,
			Climb = not climbing and onFoot and Climbing.wallInReach(),
			JumpOff = climbing and onFoot,
			Piton = climbing and onFoot,
			Release = root ~= nil and root:FindFirstChild("BelayRope") ~= nil and onFoot,
			Grapple = tool ~= nil and tool.Name == Config.GRAPPLE_NAME and onFoot,
			Mine = tool ~= nil and tool.Name == Config.PICKAXE_NAME and onFoot and not climbing,
			Throw = tool ~= nil and tool.Name == Config.TOOL_NAME and onFoot and not climbing,
			Shoot = dragon,
			Glide = onFoot and Glider.available(),
			Ride = DragonRide.canRide and not climbing,
			Fire = riding,
		}
		if editing then
			-- in modifica si vedono tutti, per sistemarli
			for _, name in ORDER do
				available[name] = true
			end
		end
		actions.Glide.Text = if Glider.isGliding() then "Close" else "Glide"
		actions.Ride.Text = if riding then "Land" else "Ride"
		local visible = {}
		for _, name in ORDER do
			actions[name].Visible = available[name] == true
			if available[name] then
				table.insert(visible, name)
			end
		end
		local key = table.concat(visible, "|") .. tostring(vp) .. tostring(editing)
		if key == last then
			return
		end
		last = key
		-- il tasto del salto di Roblox: 70 px sugli schermi piccoli (lato corto <= 500), 120 sui
		-- tablet; centro a (-60, -55) o (-110, -150) dall'angolo
		local small = math.min(vp.X, vp.Y) <= 500
		local jx, jy = if small then 60 else 110, if small then 55 else 150
		local size = if small then 60 else 88
		local r1 = if small then 92 else 150
		local r2 = r1 + size + 8
		-- primo giro: sinistra, diagonale, sopra; secondo giro piu' largo
		local slots = {
			{ r1, 180 }, { r1, 132 }, { r1, 88 },
			{ r2, 180 }, { r2, 155 }, { r2, 130 }, { r2, 105 }, { r2, 82 },
			-- terzo giro (si vede quasi solo quando sposti i tasti: li' compaiono tutti)
			{ r2 + size + 8, 180 }, { r2 + size + 8, 160 }, { r2 + size + 8, 140 }, { r2 + size + 8, 120 },
		}
		-- POSTI FISSI (Mirko 17/10: "un layout adeguato, tenendo conto che non tutti appaiono
		-- sempre"): ogni azione ha il suo posto e quelle che non compaiono mai insieme dividono lo
		-- stesso (vedi SLOT_OF). Prima i tasti visibili si mettevano in fila e, quando ne compariva
		-- uno, tutti gli altri cambiavano posto sotto il pollice. Se due capitano insieme sullo
		-- stesso posto, il secondo va nel primo posto libero del secondo giro. In modifica ognuno
		-- ha un posto suo (si vedono tutti)
		local used: { [number]: boolean } = {}
		local placeOf: { [string]: number } = {}
		for i, name in visible do
			local want = if editing then i else (SLOT_OF[name] or 6)
			if used[want] then
				want = 6
				while used[want] and want < #slots do
					want += 1
				end
			end
			used[want] = true
			placeOf[name] = want
		end
		for _, name in visible do
			local b = actions[name] :: TextButton
			local i = placeOf[name]
			local s = slots[math.min(i, #slots)]
			local a = math.rad(s[2])
			b.Size = UDim2.fromOffset(if i == 1 then size + 8 else size, if i == 1 then size + 8 else size)
			local c = custom[name]
			-- posizione scelta dal giocatore (ControlsLayout), se no l'arco attorno al salto
			b.Position = if type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" then UDim2.fromOffset(c[1], c[2]) else UDim2.fromOffset(-jx + math.cos(a) * s[1], -jy - math.sin(a) * s[1])
			b.TextSize = if small then 11 else 15
			local tag = b:FindFirstChild("Etichetta") :: TextLabel?
			if tag then
				tag.TextSize = if small then 13 else 16
				tag.Size = UDim2.new(1.4, 0, 0, if small then 15 else 18)
			end
		end
	end
	-- Modifica dei tasti: la apre il tasto ⚙ dell'HUD (client/HudLayout, barra DONE / RESET in
	-- alto, anche sul computer). Prima c'era qui un ingranaggio azzurro che finiva sopra THROW
	-- (Mirko 16/10: "fa schifo") e un pannello Reset/Done a parte
	local function setEditing(on: boolean)
		editing = on
		last = ""
	end
	HudLayout.onEditing(setEditing)
	-- trascinamento (dito o mouse): il pulsante segue il dito, la posizione e' dall'angolo
	local dragging: TextButton? = nil
	local UIS = game:GetService("UserInputService")
	for _, name in ORDER do
		local b = actions[name] :: TextButton
		b.InputBegan:Connect(function(input)
			if editing and tap(input) then
				dragging = b
			end
		end)
	end
	UIS.InputChanged:Connect(function(input)
		local b = dragging
		if not b or not editing then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
			local corner = actions.AbsolutePosition
			local x = math.floor(input.Position.X - corner.X)
			local y = math.floor(input.Position.Y - corner.Y)
			b.Position = UDim2.fromOffset(x, y)
			custom[b.Name] = { x, y }
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if tap(input) then
			dragging = nil
		end
	end)
	task.spawn(function()
		while gui.Parent do
			refresh()
			task.wait(0.1)
		end
	end)
end
return MobileControls
