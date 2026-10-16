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
local player = Players.LocalPlayer
local MobileControls = {}

-- ordine nell'arco: il primo sta subito a sinistra del salto (il piu' comodo), poi si sale
local ORDER = { "Fire", "Glide", "Throw", "Mine", "Grapple", "Climb", "JumpOff", "Piton", "Release", "Shoot", "Ride", "Run" }
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
		-- TASTO IN RILIEVO (Mirko 16/10: "effetto 3d"): faccia colorata con la luce in alto, base
		-- piu' scura sotto che fa da spessore, bordo scuro. Premuto: faccia, icona e scritta
		-- scendono sulla base (il tasto si abbassa davvero). Il colore resta quello di Ui.tint
		-- (BackgroundColor3 del pulsante), il fondo vero del pulsante resta trasparente
		local surface = b:FindFirstChild("AssetSurface")
		if surface and surface:IsA("GuiObject") then
			surface.Visible = false
		end
		local DEPTH = 5
		local base = Instance.new("Frame")
		base.Name = "Base"
		base.BorderSizePixel = 0
		base.Size = UDim2.fromScale(1, 1)
		base.Position = UDim2.fromOffset(0, DEPTH)
		base.ZIndex = 0
		base.Active = false
		base.Parent = b
		local face = Instance.new("Frame")
		face.Name = "Faccia"
		face.BorderSizePixel = 0
		face.Size = UDim2.fromScale(1, 1)
		face.ZIndex = 1
		face.Active = false
		face.Parent = b
		for _, f in { base, face } do
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
		end
		local light = Instance.new("UIGradient")
		light.Rotation = 90
		light.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
		light.Parent = face
		local rim = Instance.new("UIStroke")
		rim.Color = Color3.fromRGB(8, 10, 16)
		rim.Thickness = 2
		rim.Transparency = 0.15
		rim:SetAttribute("KeepStroke", true)
		rim.Parent = face
		local function paint()
			local col = b.BackgroundColor3
			face.BackgroundColor3 = col
			base.BackgroundColor3 = col:Lerp(Color3.new(0, 0, 0), 0.6)
			if b.BackgroundTransparency < 1 then
				b.BackgroundTransparency = 1
			end
		end
		b:GetPropertyChangedSignal("BackgroundColor3"):Connect(paint)
		b:GetPropertyChangedSignal("BackgroundTransparency"):Connect(paint)
		for _, s in b:GetChildren() do
			if s:IsA("UIStroke") and not s:GetAttribute("KeepStroke") then
				s.Enabled = false -- il bordo ora e' quello della faccia
			end
		end
		paint()
		local iconBase = if icon then icon.Position else nil
		local tagBase = tag.Position
		local function press(down: boolean)
			local dy = if down then DEPTH - 1 else 0
			face.Position = UDim2.fromOffset(0, dy)
			light.Rotation = if down then 270 else 90
			if icon and iconBase then
				icon.Position = iconBase + UDim2.fromOffset(0, dy)
			end
			tag.Position = tagBase + UDim2.fromOffset(0, dy)
		end
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				press(true)
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				press(false)
			end
		end)
		b.MouseLeave:Connect(function()
			press(false)
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
	-- tasti spostati dal giocatore: { Nome = { x, y } } in pixel dall'angolo in basso a destra
	local custom: { [string]: { number } } = {}
	local function loadCustom()
		custom = {}
		local raw = player:GetAttribute("ControlsLayout")
		if type(raw) == "string" then
			local ok, t = pcall(function()
				return game:GetService("HttpService"):JSONDecode(raw)
			end)
			if ok and type(t) == "table" then
				for k, v in t do
					if type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" then
						custom[k] = { v[1], v[2] }
					end
				end
			end
		end
		-- (anche il tasto del menu si sposta: client/MainMenu legge e scrive custom.MenuFrac)
		;(ClientState :: any).controlsCustom = custom
		last = ""
	end
	player:GetAttributeChangedSignal("ControlsLayout"):Connect(loadCustom)
	loadCustom()
	local function refresh()
		local touch = Ui.touch()
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
		for i, name in visible do
			local b = actions[name] :: TextButton
			local s = slots[math.min(i, #slots)]
			local a = math.rad(s[2])
			b.Size = UDim2.fromOffset(if i == 1 then size + 8 else size, if i == 1 then size + 8 else size)
			local c = custom[name]
			-- posizione scelta dal giocatore (ControlsLayout), se no l'arco attorno al salto
			b.Position = if c then UDim2.fromOffset(c[1], c[2]) else UDim2.fromOffset(-jx + math.cos(a) * s[1], -jy - math.sin(a) * s[1])
			b.TextSize = if small then 11 else 15
			local tag = b:FindFirstChild("Etichetta") :: TextLabel?
			if tag then
				tag.TextSize = if small then 13 else 16
				tag.Size = UDim2.new(1.4, 0, 0, if small then 15 else 18)
			end
		end
	end
	-- Modifica dei tasti: ⚙ sotto il meteo; si trascinano i pulsanti, "Done" salva (Progression,
	-- attributo ControlsLayout), "Reset" torna all'arco. Mirko: "su alcuni telefoni la UI fa
	-- schifo, ci starebbe un'impostazione per spostare i tasti"
	local gear = Instance.new("TextButton")
	gear.Name = "ModificaTasti"
	gear.AnchorPoint = Vector2.new(1, 0)
	gear.Position = UDim2.new(1, -12, 0, 84)
	gear.Size = UDim2.fromOffset(44, 44)
	gear.Text = "⚙"
	gear.TextScaled = true
	gear.Font = Enum.Font.GothamBlack
	gear.TextColor3 = Color3.new(1, 1, 1)
	gear.BackgroundColor3 = Theme.CARD
	gear.BackgroundTransparency = 0.2
	gear.Parent = gui
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0.5, 0)
	gc.Parent = gear
	local panel = Instance.new("Frame")
	panel.Name = "PannelloModifica"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 70)
	panel.Size = UDim2.fromOffset(360, 96)
	panel.BackgroundColor3 = Theme.CARD
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = gui
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 12)
	pc.Parent = panel
	local info = Instance.new("TextLabel")
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromOffset(10, 6)
	info.Size = UDim2.new(1, -20, 0, 30)
	info.Font = Enum.Font.GothamBold
	info.TextScaled = true
	info.TextColor3 = Color3.new(1, 1, 1)
	info.Text = "Drag the buttons and MENU where you like"
	info.Parent = panel
	local function panelButton(text: string, color: Color3, x: number): TextButton
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(x, 0, 1, -8)
		b.Size = UDim2.new(0.42, 0, 0, 44)
		b.Text = text
		b.Font = Enum.Font.GothamBlack
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = color
		b.Parent = panel
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = b
		return b
	end
	local reset = panelButton("Reset", Theme.BAD, 0.26)
	local done = panelButton("Done", Theme.GOOD, 0.74)
	local function setEditing(on: boolean)
		editing = on
		ClientState.editingControls = on
		panel.Visible = on
		gear.Visible = not on
		last = ""
	end
	gear.Activated:Connect(function()
		setEditing(true)
	end)
	reset.Activated:Connect(function()
		custom = {}
		;(ClientState :: any).controlsCustom = custom
		last = ""
	end)
	done.Activated:Connect(function()
		setEditing(false)
		local remote = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("SaveControls")
		if remote then
			local any = next(custom) ~= nil
			(remote :: RemoteEvent):FireServer(if any then game:GetService("HttpService"):JSONEncode(custom) else nil)
		end
	end)
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
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled and editing then
			setEditing(false)
		end
	end)

	-- Solo il controllo del contesto a 10 Hz; nessuna animazione per-frame aggiunta.
	-- l'ingranaggio sta sotto il meteo dell'HUD, che ora si apre e si chiude (prima a una quota
	-- fissa: col meteo aperto ci finiva sopra)
	local function placeGear()
		local hud = player.PlayerGui:FindFirstChild("ClimbHUD")
		local meteo = hud and hud:FindFirstChild("Meteo") :: GuiObject?
		if meteo and meteo.Visible and meteo.AbsoluteSize.Y > 0 then
			local su = gui:FindFirstChildOfClass("UIScale")
			local s = if su and su.Scale > 0 then su.Scale else 1
			local inset = if gui.IgnoreGuiInset then game:GetService("GuiService"):GetGuiInset() else Vector2.zero
			gear.Position = UDim2.new(1, -12, 0, (meteo.AbsolutePosition.Y + meteo.AbsoluteSize.Y + inset.Y) / s + 8)
		else
			gear.Position = UDim2.new(1, -12, 0, 50)
		end
	end
	task.spawn(function()
		while gui.Parent do
			refresh()
			placeGear()
			task.wait(0.1)
		end
	end)
end
return MobileControls
