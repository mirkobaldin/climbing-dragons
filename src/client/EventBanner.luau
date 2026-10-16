--!strict
-- Annunci degli eventi della mappa (pioggia di meteore, drago selvatico, grande valanga):
-- in alto al centro SOTTO il Prize Pool, per 3 secondi con una dissolvenza breve, poi resta
-- solo un'etichetta piccola con la distanza finche' l'evento e' in corso (toccandola
-- l'annuncio ricompare). Prima l'evento compariva due volte: avviso per 4 s e una riga fissa
-- in mezzo allo schermo per tutto l'evento (Mirko 16/10).
-- Durante il tutorial niente annuncio grande: solo l'etichetta (le istruzioni hanno la precedenza).
-- Dati: attributi del Workspace WorldEvent (testo), WorldEventPos, WorldEventT (server/WorldEvents).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Ui = require(RS:WaitForChild("Shared"):WaitForChild("UiView"))
local UiKit = require(script.Parent.UiKit)
local player = Players.LocalPlayer

local EventBanner = {}
local SHOW_SECONDS = 3

function EventBanner.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AnnuncioEvento"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.DisplayOrder = 6 -- come il Prize Pool (client/Montepremi)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- annuncio: superficie scura, filo d'oro, testo al centro
	local banner = Instance.new("Frame")
	banner.Name = "Annuncio"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundColor3 = UiKit.INK
	banner.BackgroundTransparency = 1
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.Parent = gui
	local stroke = UiKit.edge(banner, UiKit.ACCENT, 1, 1)
	local line = UiKit.label(banner, "", "name", 18)
	line.TextXAlignment = Enum.TextXAlignment.Center
	line.TextColor3 = UiKit.ACCENT
	line.Size = UDim2.fromScale(1, 1)
	line.TextTransparency = 1
	line.TextWrapped = true

	-- etichetta piccola finche' l'evento continua
	local pill = Instance.new("TextButton")
	pill.Name = "EventoInCorso"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Visible = false
	pill.Parent = gui
	UiKit.button(pill, "secondary")
	pill.TextColor3 = UiKit.ACCENT

	local compact = false
	Ui.viewportChanged(function(vp)
		compact = Ui.compact(vp)
		-- stessa misura del Prize Pool (striscia alta 40, ridotta a 0.75 sul telefono)
		local top = if compact then 4 + 30 + 6 else 4 + 40 + 8
		banner.Position = UDim2.new(0.5, 0, 0, top)
		banner.Size = UDim2.fromOffset(math.min(if compact then 360 else 480, vp.X - 24), if compact then 36 else 46)
		line.TextSize = if compact then 15 else 19
		pill.Position = UDim2.new(0.5, 0, 0, top)
		pill.Size = UDim2.fromOffset(if compact then 220 else 280, if compact then 22 else 26)
		pill.TextSize = if compact then 12 else 14
	end)

	local version = 0
	local fade = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
	local function show(text: string)
		version += 1
		local v = version
		line.Text = text
		banner.Visible = true
		pill.Visible = false
		banner.Position -= UDim2.fromOffset(0, 6)
		TweenService:Create(banner, fade, { BackgroundTransparency = 0.12, Position = banner.Position + UDim2.fromOffset(0, 6) }):Play()
		TweenService:Create(line, fade, { TextTransparency = 0 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 0.3 }):Play()
		task.delay(SHOW_SECONDS, function()
			if version ~= v then
				return
			end
			TweenService:Create(banner, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(line, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
			task.wait(0.26)
			if version == v then
				banner.Visible = false
			end
		end)
	end
	local lastShown = ""
	local function onEvent()
		local text = workspace:GetAttribute("WorldEvent")
		if type(text) ~= "string" then
			lastShown = ""
			return
		end
		-- una volta sola per evento (niente ripetizioni), e non sopra le istruzioni del tutorial
		local key = text .. tostring(workspace:GetAttribute("WorldEventT"))
		if key ~= lastShown and type(player:GetAttribute("TutorialText")) ~= "string" then
			lastShown = key
			show(text)
		end
	end
	workspace:GetAttributeChangedSignal("WorldEvent"):Connect(onEvent)
	workspace:GetAttributeChangedSignal("WorldEventT"):Connect(onEvent)
	onEvent()
	pill.Activated:Connect(function()
		local text = workspace:GetAttribute("WorldEvent")
		if type(text) == "string" then
			show(text)
		end
	end)

	local accum = 0
	RunService.RenderStepped:Connect(function(dt)
		accum += dt
		if accum < 0.25 then
			return
		end
		accum = 0
		local pg = player.PlayerGui
		local menu = pg:FindFirstChild("MainMenu")
		local death = pg:FindFirstChild("DeathScreen")
		gui.Enabled = not ((menu and menu:GetAttribute("MenuOpen") == true)
			or (death and death:IsA("ScreenGui") and death.Enabled)
			or player:GetAttribute("HudNascosto") == true or player:GetAttribute("SchiusaInCorso") == true)
		local text = workspace:GetAttribute("WorldEvent")
		if type(text) ~= "string" then
			pill.Visible = false
			return
		end
		local at = workspace:GetAttribute("WorldEventPos")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local short = string.match(text, "^[^:!%.]+") or text
		local dist = if typeof(at) == "Vector3" and root then string.format("  ·  %d m", math.floor((at - root.Position).Magnitude)) else ""
		pill.Text = "◆ " .. string.upper(short) .. dist
		pill.Visible = not banner.Visible
	end)
end

return EventBanner
