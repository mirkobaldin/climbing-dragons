--!strict
-- Schermata di morte (rifatta il 16/10 sullo screenshot "130321" di Mirko): niente pannellone blu
-- arrotondato, contorno rosa, pulsante verde lucido ne' "YOU FELL". Ora:
--   * lo scenario resta visibile ma scuro e quasi senza colore (ColorCorrection locale + velo
--     a gradiente), nessuna scheda o cerchio dietro al testo
--   * "YOU DIED" grande, sotto la causa VERA (server/Survival: caduta coi metri, nemico col nome,
--     freddo, gas, meteora, frana, vuoto...), un testo neutro se non si sa
--   * ornamenti scolpiti ai lati e separatori sottili, statistiche della vita in una riga
--   * RESPAWN: pulsante a forma netta con cornice, si abbassa quando lo premi
--   * il consiglio dipende dalla causa
-- La rinascita resta sul server (Remotes.Respawn). HUD, comandi del telefono, montepremi e
-- annunci si nascondono finche' la schermata e' aperta e tornano al respawn.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local Ui = require(Shared:WaitForChild("UiView"))
local UiAssets = require(Shared:WaitForChild("UiAssets"))
local UiKit = require(script.Parent.UiKit)
local player = Players.LocalPlayer
local DeathScreen = {}

-- consiglio per causa (la prima voce che compare nel testo della causa)
local TIPS: { { string } } = {
	{ "Fell", "Place pitons before hard parts: the rope catches you. With the Paraglider, press Space while falling." },
	{ "void", "Stay on the marked paths and tunnels: base camps are respawn points." },
	{ "Hit by a meteor", "Meteor shower: watch the glow on the ground and step aside." },
	{ "Hit by a", "Fight back: throw your ice axe or call your dragon's attack before they reach you." },
	{ "boulder", "Rockslide warning? Move sideways, not down." },
	{ "avalanche", "Avalanche: run sideways and get behind rocks or into a cave." },
	{ "Froze", "Stay near fires, craft the Thermal Suit or drink a Thermos when it's cold." },
	{ "gas", "Toxic gas: don't stay in the green clouds, walk out of them fast." },
}
local GENERIC = "Base camps are respawn points: discover them while you climb."

local function setBackpack(on: boolean)
	pcall(function()
		local hud = player.PlayerGui:FindFirstChild("ClimbHUD")
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, on and not (hud and hud:GetAttribute("CustomToolBar")))
	end)
end

local function tipFor(cause: string): string
	for _, t in TIPS do
		if string.find(cause, t[1], 1, true) then
			return t[2]
		end
	end
	return GENERIC
end

-- ornamento laterale: immagine renderizzata se caricata (death_ornament), altrimenti una lama
-- sottile d'oro con un rombo (mai un riquadro)
local function ornament(parent: Instance, flip: boolean): GuiObject
	local img = Instance.new("ImageLabel")
	img.Name = if flip then "OrnamentoDx" else "OrnamentoSx"
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.ImageColor3 = Color3.new(1, 1, 1)
	img.Parent = parent
	if Ui.asset(img, "death_ornament") then
		img.Rotation = if flip then 180 else 0
		return img
	end
	img.Image = ""
	img.Visible = true
	local blade = Instance.new("Frame")
	blade.BorderSizePixel = 0
	blade.AnchorPoint = Vector2.new(0.5, 0.5)
	blade.Position = UDim2.fromScale(0.5, 0.5)
	blade.Size = UDim2.new(0, 2, 0.9, 0)
	blade.BackgroundColor3 = Color3.fromRGB(196, 150, 70)
	blade.Parent = img
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = blade
	local gem = Instance.new("Frame")
	gem.BorderSizePixel = 0
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.5)
	gem.Size = UDim2.fromOffset(12, 12)
	gem.Rotation = 45
	gem.BackgroundColor3 = Color3.fromRGB(150, 32, 36)
	gem.Parent = img
	UiKit.edge(gem, Color3.fromRGB(220, 170, 90), 1, 0)
	return img
end

-- separatore: linea che sfuma ai lati con un rombo al centro
local function separator(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = "Separatore"
	f.BackgroundTransparency = 1
	f.Parent = parent
	-- separatore di Codex in tre pezzi: lame ai lati che si allungano, gemma fissa al centro
	local left, gemId, right = UiAssets.get("frame_separator_left"), UiAssets.get("frame_separator_gem"), UiAssets.get("frame_separator_right")
	if left and gemId and right then
		for i, id in { left, gemId, right } do
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = id
			img.ScaleType = Enum.ScaleType.Stretch
			img.AnchorPoint = Vector2.new(if i == 1 then 0 elseif i == 2 then 0.5 else 1, 0.5)
			img.Position = UDim2.fromScale(if i == 1 then 0 elseif i == 2 then 0.5 else 1, 0.5)
			img.Size = if i == 2 then UDim2.fromOffset(20, 12) else UDim2.new(0.5, -10, 0, 12)
			img.Parent = f
		end
		return f
	end
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.new(1, 0, 0, 1)
	line.BackgroundColor3 = Color3.fromRGB(196, 150, 70)
	line.Parent = f
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = line
	local gem = Instance.new("Frame")
	gem.BorderSizePixel = 0
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.5)
	gem.Size = UDim2.fromOffset(7, 7)
	gem.Rotation = 45
	gem.BackgroundColor3 = Color3.fromRGB(220, 170, 90)
	gem.Parent = f
	return f
end

-- pulsante netto con cornice: bordo chiaro in alto/sinistra e scuro in basso/destra (rilievo);
-- premuto scende di 2 px e la luce si inverte (si "abbassa")
local function sharpButton(parent: Instance, text: string, primary: boolean): TextButton
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = if primary then Color3.fromRGB(112, 22, 28) else Color3.fromRGB(22, 26, 36)
	b.BorderSizePixel = 0
	b:SetAttribute("UiNative", true)
	b.Parent = parent
	local face = Instance.new("Frame")
	face.Name = "Faccia"
	face.BorderSizePixel = 0
	face.BackgroundColor3 = b.BackgroundColor3
	face.Size = UDim2.fromScale(1, 1)
	face.Parent = b
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150))
	grad.Parent = face
	local frame = UiKit.edge(face, Color3.fromRGB(214, 168, 88), 2, 0)
	frame.Name = "Filo"
	-- cornice di Codex (oro scolpito); il principale tinto di rosso scuro
	local framed = UiKit.Cornici.apply(face, if primary then "frame_button_primary_normal" else "frame_button_secondary_normal", {
		color = if primary then Color3.fromRGB(255, 170, 160) else nil,
	}) ~= nil
	if framed then
		frame.Transparency = 1
		face.BackgroundTransparency = 1
	end
	-- luce in alto e ombra in basso (spessore)
	local top = Instance.new("Frame")
	top.BorderSizePixel = 0
	top.BackgroundColor3 = Color3.new(1, 1, 1)
	top.BackgroundTransparency = 0.75
	top.Visible = not framed
	top.Size = UDim2.new(1, -6, 0, 2)
	top.Position = UDim2.fromOffset(3, 3)
	top.Parent = face
	local shadow = Instance.new("Frame")
	shadow.Name = "Ombra"
	shadow.BorderSizePixel = 0
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.35
	shadow.Size = UDim2.new(1, 0, 0, 5)
	shadow.Position = UDim2.new(0, 3, 1, 0)
	shadow.ZIndex = 0
	shadow.Parent = b
	local label = UiKit.label(face, text, "button", 24)
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextColor3 = Color3.fromRGB(250, 236, 214)
	b.BackgroundTransparency = 1
	local function press(on: boolean)
		face.Position = UDim2.fromOffset(0, if on then 2 else 0)
		if framed then
			UiKit.Cornici.apply(face, (if primary then "frame_button_primary" else "frame_button_secondary") .. (if on then "_pressed" else "_normal"), {
				color = if primary then Color3.fromRGB(255, 170, 160) else nil,
			})
		end
		shadow.Size = UDim2.new(1, 0, 0, if on then 2 else 5)
		top.BackgroundTransparency = if on then 0.92 else 0.75
		grad.Rotation = if on then 270 else 90
	end
	b.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			press(true)
		end
	end)
	b.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			press(false)
		end
	end)
	b.MouseEnter:Connect(function()
		frame.Color = Color3.fromRGB(255, 214, 130)
	end)
	b.MouseLeave:Connect(function()
		frame.Color = Color3.fromRGB(214, 168, 88)
		press(false)
	end)
	b:SetAttribute("Testo", text)
	return b
end

function DeathScreen.start()
	local gui = Ui.screen("DeathScreen")
	gui.DisplayOrder = 50 -- sopra HUD, menu, montepremi e comandi del telefono
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	-- il vecchio impianto del modello (pannellone, immagine di fondo, velo pieno) resta spento
	for _, n in { "Panel", "Background", "Shade" } do
		local o = gui:FindFirstChild(n)
		if o and o:IsA("GuiObject") then
			o.Visible = false
		end
	end

	-- velo: scuro ai bordi e in basso, il centro appena oscurato (si vede dove sei caduto)
	local veil = Instance.new("Frame")
	veil.Name = "Velo"
	veil.BorderSizePixel = 0
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0.35
	veil.Size = UDim2.fromScale(1, 1)
	veil.Parent = gui
	local vg = Instance.new("UIGradient")
	vg.Rotation = 90
	vg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.4, 0.55),
		NumberSequenceKeypoint.new(0.6, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	vg.Parent = veil

	local root = Instance.new("Frame")
	root.Name = "Contenuto"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Parent = gui
	local leftOrn = ornament(root, false)
	local rightOrn = ornament(root, true)
	local title = UiKit.label(root, "YOU DIED", "title", 72)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = Color3.fromRGB(214, 56, 52)
	title.TextStrokeColor3 = Color3.fromRGB(30, 4, 6)
	title.TextStrokeTransparency = 0.2
	local cause = UiKit.label(root, "", "name", 26)
	cause.TextXAlignment = Enum.TextXAlignment.Center
	cause.TextColor3 = Color3.fromRGB(240, 226, 204)
	cause.TextStrokeTransparency = 0.4
	local sep1 = separator(root)
	local stats = UiKit.label(root, "", "stat", 18)
	stats.TextXAlignment = Enum.TextXAlignment.Center
	stats.TextColor3 = Color3.fromRGB(214, 206, 192)
	stats.RichText = true
	local tip = UiKit.label(root, "", "body", 16)
	tip.TextXAlignment = Enum.TextXAlignment.Center
	tip.TextWrapped = true
	tip.TextColor3 = Color3.fromRGB(196, 190, 180)
	local sep2 = separator(root)
	local respawn = sharpButton(root, "RESPAWN", true)
	respawn.Name = "Respawn"
	local revive = sharpButton(root, "REVIVE HERE", false)
	revive.Name = "Revive"
	revive.Visible = ShopConfig.DEV_PRODUCTS.Revive > 0
	respawn.Activated:Connect(function()
		(RS.Remotes:WaitForChild("Respawn") :: RemoteEvent):FireServer()
	end)
	revive.Activated:Connect(function()
		(RS.Remotes:WaitForChild("Shop") :: RemoteFunction):InvokeServer("robux", "Revive")
	end)

	local P = Ui.px
	Ui.viewportChanged(function(vp)
		local logical = Ui.fitScale(gui, vp)
		local compact = logical.Y < 520
		local w = math.min(640, logical.X - 40)
		local h = math.min(if compact then 330 else 430, logical.Y - 16)
		P(root, 0.5, 0, 0.5, 0, w, h, 0.5, 0.5)
		local titleH = if compact then 62 else 86
		P(title, 0, 0, 0, 0, w, titleH)
		title.TextSize = if compact then 56 else 76
		P(cause, 0, 0, 0, titleH, w, if compact then 28 else 34)
		cause.TextSize = if compact then 21 else 26
		local y = titleH + (if compact then 34 else 44)
		P(sep1, 0.5, 0, 0, y, math.min(420, w - 80), 10, 0.5, 0)
		y += if compact then 14 else 20
		P(stats, 0, 0, 0, y, w, 24)
		stats.TextSize = if compact then 15 else 18
		y += if compact then 28 else 34
		P(tip, 0.5, 0, 0, y, math.min(520, w - 60), if compact then 40 else 48, 0.5, 0)
		tip.TextSize = if compact then 14 else 16
		y += if compact then 44 else 56
		P(sep2, 0.5, 0, 0, y, math.min(300, w - 120), 10, 0.5, 0)
		y += if compact then 16 else 22
		local bw, bh = if compact then 220 else 260, if compact then 50 else 60
		if revive.Visible then
			P(respawn, 0.5, -8, 0, y, bw, bh, 1, 0)
			P(revive, 0.5, 8, 0, y, bw, bh, 0, 0)
		else
			P(respawn, 0.5, 0, 0, y, bw, bh, 0.5, 0)
		end
		-- ornamenti ai lati del titolo, alti quanto il blocco del titolo e della causa
		local oh = titleH + (if compact then 30 else 40)
		local ow = math.floor(oh * 0.42)
		P(leftOrn, 0.5, -(w / 2) + 4, 0, 0, ow, oh)
		P(rightOrn, 0.5, w / 2 - ow - 4, 0, 0, ow, oh)
	end)

	-- scenario scuro e quasi senza colore (solo sul tuo schermo)
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "MorteSchermata"
	grade.Enabled = false
	grade.Parent = Lighting
	local hiddenGuis: { [ScreenGui]: boolean } = {}
	local deaths = 0
	local function hideGameplay(on: boolean)
		if on then
			for _, n in { "CombatHUD", "MobileControls", "Montepremi", "AnnuncioEvento", "SuggerimentiTutorial", "MirinoPiccozza", "MirinoMonta", "BussolaCasa", "MainMenu", "AdminButtons", "Teletrasporto" } do
				local g = player.PlayerGui:FindFirstChild(n)
				if g and g:IsA("ScreenGui") and g.Enabled then
					hiddenGuis[g] = true
					g.Enabled = false
				end
			end
		else
			for g in hiddenGuis do
				if g.Parent then
					g.Enabled = true
				end
			end
			table.clear(hiddenGuis)
		end
	end

	local function show()
		deaths += 1
		local raw = player:GetAttribute("DeathCause")
		local text = if type(raw) == "string" and raw ~= "" then raw else "You died"
		-- "You died" e' gia' il titolo: sotto un testo neutro
		cause.Text = if text == "You died" then "Your climb ends here" else text
		tip.Text = tipFor(text)
		local s = player:GetAttribute("DeathStats")
		local maxY, alive = 0, 0
		if type(s) == "string" then
			local a, b = string.match(s, "^(%d+)|(%d+)$")
			maxY, alive = tonumber(a) or 0, tonumber(b) or 0
		end
		local function stat(label: string, value: string): string
			return string.format('<font color="#9A9184">%s</font>  %s', label, value)
		end
		stats.Text = table.concat({
			stat("HEIGHT", string.format("%d m", maxY)),
			stat("TIME ALIVE", string.format("%d:%02d", alive // 60, alive % 60)),
			stat("DEATHS", tostring(deaths)),
		}, "     ·     ")
		gui.Enabled = true
		setBackpack(false)
		hideGameplay(true)
		grade.Enabled = true
		grade.Saturation, grade.Brightness, grade.Contrast = 0, 0, 0
		TweenService:Create(grade, TweenInfo.new(0.8), { Saturation = -0.65, Brightness = -0.12, Contrast = 0.08 }):Play()
		root.Position = UDim2.new(0.5, 0, 0.5, 12)
		TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		title.TextTransparency = 1
		TweenService:Create(title, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	end
	local function onCharacter(character: Model)
		gui.Enabled = false
		grade.Enabled = false
		hideGameplay(false)
		setBackpack(true)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			-- la causa arriva dal server subito dopo la morte: un attimo di attesa
			task.wait(0.4)
			if player.Character == character and humanoid.Health <= 0 then
				show()
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	-- la causa puo' arrivare un attimo dopo: se cambia mentre la schermata e' aperta, si aggiorna
	player:GetAttributeChangedSignal("DeathCause"):Connect(function()
		local raw = player:GetAttribute("DeathCause")
		if gui.Enabled and type(raw) == "string" then
			cause.Text = if raw == "You died" then "Your climb ends here" else raw
			tip.Text = tipFor(raw)
		end
	end)
end
return DeathScreen
