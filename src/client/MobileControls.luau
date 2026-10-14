--!strict
-- Comandi del telefono: ad arco attorno al tasto del salto di Roblox, nell'angolo in basso a
-- destra (sotto il pollice). Prima stavano in una fila staccata dal bordo, verso il centro, e
-- Ride / Fire finivano a meta' schermo sotto il riquadro del meteo. Dal computer si provano con
-- gli attributi SimTouch = true e SimViewport = Vector2.new(844, 354) sul giocatore.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("UiView"))
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
	Fire = Color3.fromRGB(226, 72, 44),
	Shoot = Color3.fromRGB(226, 72, 44),
	Glide = Color3.fromRGB(46, 156, 222),
	Ride = Color3.fromRGB(214, 160, 40),
	Throw = Color3.fromRGB(232, 128, 40),
	Mine = Color3.fromRGB(150, 104, 66),
	Grapple = Color3.fromRGB(32, 168, 150),
	Climb = Color3.fromRGB(70, 170, 80),
	JumpOff = Color3.fromRGB(200, 170, 40),
	Piton = Color3.fromRGB(140, 90, 210),
	Release = Color3.fromRGB(90, 110, 140),
	Run = Color3.fromRGB(60, 110, 220),
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
	extra("Glide", "Glide")
	extra("Ride", "Ride")
	extra("Fire", "Fire", "act_shoot")

	actions.Run.Activated:Connect(function()
		actions.Run.Text = if Sprint.toggle() then "Walk" else "Run"
	end)
	actions.Climb.Activated:Connect(function()
		Climbing.grabNearest()
	end)
	actions.JumpOff.Activated:Connect(Climbing.jumpOff)
	actions.Release.Activated:Connect(Climbing.releaseRope)
	actions.Throw.Activated:Connect(function()
		task.spawn(PickaxeThrow.activate)
	end)
	actions.Shoot.Activated:Connect(function()
		if TrainingFX.shoot then
			TrainingFX.shoot()
		end
	end)
	actions.Glide.Activated:Connect(function()
		Glider.toggle(true)
	end)
	actions.Ride.Activated:Connect(DragonRide.toggle)
	actions.Fire.Activated:Connect(DragonRide.fire)
	local function activateTool(name: string)
		local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if tool and tool.Name == name then
			tool:Activate()
		end
	end
	actions.Grapple.Activated:Connect(function()
		activateTool(Config.GRAPPLE_NAME)
	end)
	actions.Mine.Activated:Connect(function()
		activateTool(Config.PICKAXE_NAME)
	end)
	local function tap(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	actions.Piton.InputBegan:Connect(function(input)
		if tap(input) then
			Climbing.aimBegin()
		end
	end)
	actions.Piton.InputEnded:Connect(function(input)
		if tap(input) then
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
		local corner = b:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0.5, 0)
		end
		Ui.tint(b, COLORS[name] or Color3.fromRGB(60, 110, 220), true)
	end

	local vp = Vector2.new(844, 390)
	Ui.viewportChanged(function(size)
		vp = size
	end)
	local last = ""
	local function refresh()
		local touch = Ui.touch()
		gui.Enabled = touch
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
		actions.Glide.Text = if Glider.isGliding() then "Close" else "Glide"
		actions.Ride.Text = if riding then "Land" else "Ride"
		local visible = {}
		for _, name in ORDER do
			actions[name].Visible = available[name] == true
			if available[name] then
				table.insert(visible, name)
			end
		end
		local key = table.concat(visible, "|") .. tostring(vp)
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
		}
		for i, name in visible do
			local b = actions[name] :: TextButton
			local s = slots[math.min(i, #slots)]
			local a = math.rad(s[2])
			b.Size = UDim2.fromOffset(if i == 1 then size + 8 else size, if i == 1 then size + 8 else size)
			b.Position = UDim2.fromOffset(-jx + math.cos(a) * s[1], -jy - math.sin(a) * s[1])
			b.TextSize = if small then 11 else 15
		end
	end
	-- Solo il controllo del contesto a 10 Hz; nessuna animazione per-frame aggiunta.
	task.spawn(function()
		while gui.Parent do
			refresh()
			task.wait(0.1)
		end
	end)
end
return MobileControls
