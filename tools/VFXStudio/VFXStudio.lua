--!strict
--[[
	VFX Studio — plugin per Roblox Studio (Hardcore Climbing & Survival)

	Un pannello laterale per creare e ritoccare effetti visivi:
	  * CREA          preset pronti di particelle (esplosione, fuoco, fumo, scintille, aura magica,
	                  neve, gas tossico, portale, fulmini, polvere di stelle) messi sull'oggetto
	                  selezionato (o su un supporto invisibile davanti alla camera)
	  * MODIFICA      colore, velocita', grandezza, tasso, durata, luce, apertura e trasparenza
	                  di tutti i ParticleEmitter selezionati (anche quelli dentro i modelli),
	                  "Emetti ora" per provarli, accendi/spegni
	  * RAGGI E SCIE  Beam tra due oggetti selezionati e Trail su una parte, con preset
	                  (laser, fulmine, energia, catena / spada, vento, magia, fuoco)

	SICUREZZA: il plugin usa solo le API native di Roblox Studio. Niente HttpService, niente
	loadstring, niente require di moduli presi da internet, niente InsertService: tutte le
	texture sono quelle installate con Studio (rbxasset://textures/particles/...).
	Ogni modifica passa da ChangeHistoryService: si annulla con Ctrl+Z.

	Installazione: vedi tools/VFXStudio/LEGGIMI.md
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

------------------------------------------------------------------------------------------
-- Texture native (cartella content/textures/particles di Studio)

local TEX = {
	sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	fireSparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	core = "rbxasset://textures/particles/explosion01_core_main.dds",
	implosion = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	shockwave = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	blastSmoke = "rbxasset://textures/particles/explosion01_smoke_main.dds",
	glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	square = "rbxasset://textures/particles/SquareParticle.png",
}

------------------------------------------------------------------------------------------
-- Utilita'

local function seq(...: number): NumberSequence
	local values = { ... }
	if #values == 1 then
		return NumberSequence.new(values[1])
	end
	local keys = {}
	for i, v in values do
		table.insert(keys, NumberSequenceKeypoint.new((i - 1) / (#values - 1), v))
	end
	return NumberSequence.new(keys)
end

local function colors(...: Color3): ColorSequence
	local values = { ... }
	if #values == 1 then
		return ColorSequence.new(values[1])
	end
	local keys = {}
	for i, c in values do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#values - 1), c))
	end
	return ColorSequence.new(keys)
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Annullabile con Ctrl+Z (API nuova; se manca si usa il vecchio SetWaypoint)
local function recorded(name: string, fn: () -> ())
	local ok, id = pcall(function()
		return ChangeHistoryService:TryBeginRecording(name)
	end)
	local success, err = pcall(fn)
	if ok and id then
		ChangeHistoryService:FinishRecording(id, if success then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	else
		ChangeHistoryService:SetWaypoint(name)
	end
	if not success then
		warn("[VFX Studio] " .. tostring(err))
	end
end

------------------------------------------------------------------------------------------
-- Preset di particelle: ogni preset puo' avere piu' emettitori (es. esplosione = nucleo +
-- fumo + scintille + onda). burst = particelle emesse in un colpo (Rate 0, "Emetti ora")

type EmitterDef = { [string]: any }
type Preset = { name: string, color: Color3, burst: number?, emitters: { EmitterDef } }

local PRESETS: { Preset } = {
	{
		name = "Esplosione",
		color = rgb(255, 150, 60),
		burst = 1,
		emitters = {
			{ Name = "Nucleo", Texture = TEX.core, Color = colors(rgb(255, 245, 200), rgb(255, 150, 50), rgb(120, 40, 20)), Size = seq(2, 8), Transparency = seq(0, 0.2, 1), Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(0.5, 2), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), _burst = 6 },
			{ Name = "Fumo", Texture = TEX.blastSmoke, Color = colors(rgb(90, 80, 75), rgb(40, 38, 36)), Size = seq(3, 10), Transparency = seq(0.2, 1), Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(4, 9), Drag = 3, SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), _burst = 14 },
			{ Name = "Scintille", Texture = TEX.fireSparks, Color = colors(rgb(255, 220, 120), rgb(255, 120, 40)), Size = seq(0.4, 0), Lifetime = NumberRange.new(0.5, 1.1), Speed = NumberRange.new(25, 45), Drag = 2, Acceleration = Vector3.new(0, -30, 0), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), _burst = 40 },
			{ Name = "Onda", Texture = TEX.shockwave, Color = colors(rgb(255, 230, 190)), Size = seq(1, 16), Transparency = seq(0.3, 1), Lifetime = NumberRange.new(0.35, 0.35), Speed = NumberRange.new(0, 0), LightEmission = 0.6, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, _burst = 1 },
		},
	},
	{
		name = "Fuoco",
		color = rgb(255, 120, 40),
		emitters = {
			{ Name = "Fiamme", Texture = TEX.fire, Color = colors(rgb(255, 230, 140), rgb(255, 110, 30), rgb(160, 30, 10)), Size = seq(1.6, 2.4, 0.4), Transparency = seq(0.1, 0.3, 1), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(3, 6), Rate = 40, LightEmission = 1, SpreadAngle = Vector2.new(12, 12), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60), Acceleration = Vector3.new(0, 6, 0) },
			{ Name = "Braci", Texture = TEX.fireSparks, Color = colors(rgb(255, 200, 90)), Size = seq(0.2, 0), Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(4, 8), Rate = 12, LightEmission = 1, SpreadAngle = Vector2.new(30, 30), Acceleration = Vector3.new(0, 4, 0) },
			{ Name = "Fumo", Texture = TEX.smoke, Color = colors(rgb(70, 66, 62)), Size = seq(1.5, 4), Transparency = seq(0.6, 1), Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(3, 5), Rate = 8, SpreadAngle = Vector2.new(15, 15), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20) },
		},
	},
	{
		name = "Fumo",
		color = rgb(150, 150, 155),
		emitters = {
			{ Name = "Fumo", Texture = TEX.smoke, Color = colors(rgb(170, 168, 165), rgb(110, 108, 106)), Size = seq(2, 6), Transparency = seq(0.4, 1), Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(2, 4), Rate = 10, SpreadAngle = Vector2.new(20, 20), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-15, 15), Drag = 0.5 },
		},
	},
	{
		name = "Scintille",
		color = rgb(255, 220, 110),
		emitters = {
			{ Name = "Scintille", Texture = TEX.sparkles, Color = colors(rgb(255, 245, 190), rgb(255, 190, 70)), Size = seq(0.5, 0), Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(10, 20), Rate = 30, LightEmission = 1, SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -25, 0), Drag = 1 },
		},
	},
	{
		name = "Aura magica",
		color = rgb(150, 90, 255),
		emitters = {
			{ Name = "Aura", Texture = TEX.glow, Color = colors(rgb(190, 140, 255), rgb(110, 60, 255)), Size = seq(2.5, 3.5, 0), Transparency = seq(0.5, 0.2, 1), Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.5, 1.5), Rate = 14, LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40) },
			{ Name = "Scintille", Texture = TEX.sparkles, Color = colors(rgb(220, 190, 255)), Size = seq(0.35, 0), Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(1, 3), Rate = 20, LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 3, 0) },
		},
	},
	{
		name = "Neve",
		color = rgb(235, 245, 255),
		emitters = {
			{ Name = "Neve", Texture = TEX.smoke, Color = colors(rgb(250, 252, 255)), Size = seq(0.3, 0.5), Transparency = seq(0.1), Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(6, 10), Rate = 60, SpreadAngle = Vector2.new(25, 25), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60), EmissionDirection = Enum.NormalId.Bottom },
		},
	},
	{
		name = "Gas tossico",
		color = rgb(130, 220, 70),
		emitters = {
			{ Name = "Gas", Texture = TEX.smoke, Color = colors(rgb(170, 240, 90), rgb(120, 70, 170)), Size = seq(3, 9), Transparency = seq(0.55, 0.75, 1), Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.5, 2), Rate = 12, SpreadAngle = Vector2.new(180, 30), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-10, 10), Acceleration = Vector3.new(0, 0.6, 0), LightEmission = 0.2 },
			{ Name = "Bolle", Texture = TEX.glow, Color = colors(rgb(190, 255, 120)), Size = seq(0.4, 0.8, 0), Transparency = seq(0.3, 1), Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(1, 2), Rate = 6, LightEmission = 0.8, SpreadAngle = Vector2.new(40, 40) },
		},
	},
	{
		name = "Portale",
		color = rgb(80, 180, 255),
		emitters = {
			{ Name = "Vortice", Texture = TEX.vortex, Color = colors(rgb(120, 210, 255), rgb(60, 90, 255)), Size = seq(6, 6), Transparency = seq(0.6, 0.2, 0.6), Lifetime = NumberRange.new(1.5, 1.5), Speed = NumberRange.new(0, 0), Rate = 3, LightEmission = 1, RotSpeed = NumberRange.new(180, 180), Rotation = NumberRange.new(0, 360) },
			{ Name = "Risucchio", Texture = TEX.implosion, Color = colors(rgb(160, 230, 255)), Size = seq(3, 0.5), Transparency = seq(0.4, 1), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(-6, -3), Rate = 18, LightEmission = 1, SpreadAngle = Vector2.new(180, 180) },
		},
	},
	{
		name = "Fulmini",
		color = rgb(170, 200, 255),
		emitters = {
			{ Name = "Scariche", Texture = TEX.square, Color = colors(rgb(230, 240, 255), rgb(140, 170, 255)), Size = seq(0.15, 0.05), Squash = seq(6), Lifetime = NumberRange.new(0.05, 0.12), Speed = NumberRange.new(30, 60), Rate = 50, LightEmission = 1, SpreadAngle = Vector2.new(180, 180) },
			{ Name = "Bagliore", Texture = TEX.glow, Color = colors(rgb(170, 200, 255)), Size = seq(3, 5), Transparency = seq(0.5, 1), Lifetime = NumberRange.new(0.1, 0.2), Speed = NumberRange.new(0, 0), Rate = 8, LightEmission = 1 },
		},
	},
	{
		name = "Polvere di stelle",
		color = rgb(255, 240, 180),
		emitters = {
			{ Name = "Stelle", Texture = TEX.sparkles, Color = colors(rgb(255, 250, 220), rgb(170, 200, 255)), Size = seq(0, 0.6, 0), Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.5, 1.5), Rate = 25, LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90) },
		},
	},
}

------------------------------------------------------------------------------------------
-- Preset di raggi (Beam) e scie (Trail)

local BEAMS = {
	{ name = "Laser", color = rgb(255, 60, 60), props = { Texture = TEX.glow, Width0 = 0.4, Width1 = 0.4, LightEmission = 1, TextureSpeed = 2, Segments = 2, FaceCamera = true } },
	{ name = "Fulmine", color = rgb(170, 200, 255), props = { Texture = TEX.square, Width0 = 0.25, Width1 = 0.1, LightEmission = 1, TextureSpeed = 6, Segments = 24, CurveSize0 = 2, CurveSize1 = -2, FaceCamera = true } },
	{ name = "Energia", color = rgb(120, 240, 200), props = { Texture = TEX.sparkles, Width0 = 1.2, Width1 = 0.6, LightEmission = 1, TextureSpeed = 1.5, TextureLength = 2, TextureMode = Enum.TextureMode.Wrap, Segments = 12, FaceCamera = true } },
	{ name = "Catena", color = rgb(150, 150, 160), props = { Texture = TEX.square, Width0 = 0.3, Width1 = 0.3, LightEmission = 0, TextureSpeed = 0, Segments = 16, CurveSize0 = 1.5, CurveSize1 = 1.5, FaceCamera = true } },
}

local TRAILS = {
	{ name = "Spada", color = rgb(230, 240, 255), props = { Lifetime = 0.2, LightEmission = 1, Transparency = seq(0.1, 1), WidthScale = seq(1, 0), Texture = TEX.glow } },
	{ name = "Vento", color = rgb(255, 255, 255), props = { Lifetime = 0.5, LightEmission = 0.4, Transparency = seq(0.6, 1), WidthScale = seq(1, 0.2), Texture = TEX.smoke } },
	{ name = "Magia", color = rgb(170, 110, 255), props = { Lifetime = 0.6, LightEmission = 1, Transparency = seq(0, 1), WidthScale = seq(1, 0), Texture = TEX.sparkles } },
	{ name = "Fuoco", color = rgb(255, 140, 40), props = { Lifetime = 0.35, LightEmission = 1, Transparency = seq(0, 1), WidthScale = seq(1, 0.3), Texture = TEX.fire } },
}

------------------------------------------------------------------------------------------
-- Selezione: dove mettere gli effetti e quali emettitori modificare

-- Primo oggetto selezionato a cui si puo' attaccare un effetto (parte o attacco). Se non c'e'
-- niente si crea un supporto invisibile e ancorato davanti alla camera.
local function targetForEffect(): Instance
	for _, inst in Selection:Get() do
		if inst:IsA("BasePart") or inst:IsA("Attachment") then
			return inst
		elseif inst:IsA("Model") then
			local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
			if p then
				return p
			end
		end
	end
	local holder = Instance.new("Part")
	holder.Name = "SupportoVFX"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -14)
	holder.Parent = workspace
	return holder
end

-- Tutti gli emettitori nella selezione (anche dentro modelli e cartelle)
local function selectedEmitters(): { ParticleEmitter }
	local list, seen = {}, {}
	local function add(e: Instance)
		if e:IsA("ParticleEmitter") and not seen[e] then
			seen[e] = true
			table.insert(list, e)
		end
	end
	for _, inst in Selection:Get() do
		add(inst)
		for _, d in inst:GetDescendants() do
			add(d)
		end
	end
	return list
end

-- Crea un preset di particelle: un Attachment con dentro gli emettitori
local function createPreset(preset: Preset)
	recorded("VFX: " .. preset.name, function()
		local target = targetForEffect()
		local holder: Instance = target
		if target:IsA("BasePart") then
			local a = Instance.new("Attachment")
			a.Name = "VFX_" .. preset.name
			a.Parent = target
			holder = a
		end
		local created = {}
		for _, def in preset.emitters do
			local e = Instance.new("ParticleEmitter")
			for k, v in def do
				if k ~= "_burst" then
					(e :: any)[k] = v
				end
			end
			if preset.burst then
				e.Rate = 0
				e:SetAttribute("VFX_Burst", def._burst or 20)
			end
			e.Parent = holder
			table.insert(created, e)
		end
		Selection:Set(created)
		-- prova subito i preset a colpo
		if preset.burst then
			for _, e in created do
				e:Emit((e:GetAttribute("VFX_Burst") :: number?) or 20)
			end
		end
	end)
end

------------------------------------------------------------------------------------------
-- Interfaccia (colori del tema di Studio, si aggiorna se cambi tema)

local toolbar = plugin:CreateToolbar("VFX Studio")
local toggle = toolbar:CreateButton("VFX Studio", "Apri il pannello degli effetti visivi", TEX.sparkles)
toggle.ClickableWhenViewportHidden = true

local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 340, 600, 300, 420)
local widget = plugin:CreateDockWidgetPluginGui("VFXStudio_Pannello", info)
widget.Title = "VFX Studio"
widget.Name = "VFXStudio"

toggle.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggle:SetActive(widget.Enabled)
end)

local studio = settings().Studio
local themed: { { inst: Instance, prop: string, color: Enum.StudioStyleGuideColor, modifier: Enum.StudioStyleGuideModifier? } } = {}
local function theme(inst: Instance, prop: string, color: Enum.StudioStyleGuideColor, modifier: Enum.StudioStyleGuideModifier?)
	table.insert(themed, { inst = inst, prop = prop, color = color, modifier = modifier })
	;(inst :: any)[prop] = studio.Theme:GetColor(color, modifier or Enum.StudioStyleGuideModifier.Default)
end
studio.ThemeChanged:Connect(function()
	for _, t in themed do
		(t.inst :: any)[t.prop] = studio.Theme:GetColor(t.color, t.modifier or Enum.StudioStyleGuideModifier.Default)
	end
end)

local C = Enum.StudioStyleGuideColor

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop, p.PaddingBottom = UDim.new(0, px), UDim.new(0, px)
	p.PaddingLeft, p.PaddingRight = UDim.new(0, px), UDim.new(0, px)
	p.Parent = parent
end

local function list(parent: Instance, gap: number)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

local function label(parent: Instance, text: string, size: number?, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, (size or 13) + 6)
	l.AutomaticSize = Enum.AutomaticSize.Y -- i testi lunghi vanno a capo senza essere tagliati
	l.Font = if bold then Enum.Font.SourceSansBold else Enum.Font.SourceSans
	l.TextSize = size or 13
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	theme(l, "TextColor3", if bold then C.BrightText else C.MainText)
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, accent: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.Size = UDim2.new(1, 0, 0, 28)
	b.Font = Enum.Font.SourceSansSemibold
	b.TextSize = 14
	b.Text = text
	if accent then
		b.BackgroundColor3 = accent
		b.TextColor3 = Color3.new(1, 1, 1)
	else
		theme(b, "BackgroundColor3", C.Button)
		theme(b, "TextColor3", C.ButtonText)
	end
	corner(b, 5)
	b.Parent = parent
	return b
end

local function section(parent: Instance, title: string, order: number): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = order
	theme(f, "BackgroundColor3", C.Item)
	corner(f, 6)
	padding(f, 8)
	list(f, 6)
	label(f, title, 15, true).LayoutOrder = 0
	f.Parent = parent
	return f
end

-- campo numerico con etichetta; vuoto = non cambiare
local function field(parent: Instance, name: string, order: number): TextBox
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 24)
	row.LayoutOrder = order
	row.Parent = parent
	local l = label(row, name)
	l.AutomaticSize = Enum.AutomaticSize.None
	l.Size = UDim2.new(0.55, 0, 1, 0)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.45, 0, 1, 0)
	box.Position = UDim2.new(0.55, 0, 0, 0)
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Code
	box.TextSize = 13
	box.Text = ""
	box.PlaceholderText = "—"
	theme(box, "BackgroundColor3", C.InputFieldBackground)
	theme(box, "TextColor3", C.MainText)
	theme(box, "PlaceholderColor3", C.DimmedText)
	corner(box, 4)
	box.Parent = row
	return box
end

-- "a" oppure "a b": restituisce min, max (nil se il campo e' vuoto o non e' un numero)
local function readPair(box: TextBox): (number?, number?)
	local a, b = string.match(box.Text, "^%s*(-?[%d%.]+)%s*[,; ]?%s*(-?[%d%.]*)%s*$")
	local x = a and tonumber(a)
	if not x then
		return nil, nil
	end
	local y = if b and b ~= "" then tonumber(b) else x
	return x, y or x
end

-- Pannello con schede
local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
theme(root, "BackgroundColor3", C.MainBackground)
root.Parent = widget

local tabsBar = Instance.new("Frame")
tabsBar.Size = UDim2.new(1, 0, 0, 34)
tabsBar.BackgroundTransparency = 1
tabsBar.Parent = root
local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.Padding = UDim.new(0, 4)
tabsLayout.Parent = tabsBar
padding(tabsBar, 4)

local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local function showTab(name: string)
	for n, p in pages do
		p.Visible = n == name
		local b = tabButtons[n]
		if n == name then
			b.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
			b.TextColor3 = Color3.new(1, 1, 1)
		else
			b.BackgroundColor3 = studio.Theme:GetColor(C.Button)
			b.TextColor3 = studio.Theme:GetColor(C.ButtonText)
		end
	end
end

local function page(name: string): ScrollingFrame
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1 / 3, -3, 1, 0)
	b.Font = Enum.Font.SourceSansSemibold
	b.TextSize = 14
	b.Text = name
	corner(b, 5)
	b.Parent = tabsBar
	tabButtons[name] = b
	local s = Instance.new("ScrollingFrame")
	s.Position = UDim2.new(0, 0, 0, 36)
	s.Size = UDim2.new(1, 0, 1, -36)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	padding(s, 8)
	list(s, 8)
	s.Visible = false
	s.Parent = root
	pages[name] = s
	b.Activated:Connect(function()
		showTab(name)
	end)
	return s
end

------------------------------------------------------------------------------------------
-- Scheda CREA

local createPage = page("Crea")
label(createPage, "Seleziona una parte, un attacco o un modello e scegli un preset. Senza selezione l'effetto va su un supporto invisibile davanti alla camera.", 13).LayoutOrder = 1
local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Size = UDim2.new(1, 0, 0, 0)
grid.AutomaticSize = Enum.AutomaticSize.Y
grid.LayoutOrder = 2
grid.Parent = createPage
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.5, -4, 0, 34)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid
for i, preset in PRESETS do
	local b = button(grid, preset.name, preset.color:Lerp(Color3.new(0, 0, 0), 0.25))
	b.LayoutOrder = i
	b.Activated:Connect(function()
		createPreset(preset)
	end)
end
local burstInfo = label(createPage, "Esplosione e' un effetto a colpo (Rate 0): si prova con \"Emetti ora\" nella scheda Modifica. Nel gioco: emitter:Emit(emitter:GetAttribute(\"VFX_Burst\")).", 12)
burstInfo.LayoutOrder = 3

------------------------------------------------------------------------------------------
-- Scheda MODIFICA

local editPage = page("Modifica")
local status = label(editPage, "", 13, true)
status.LayoutOrder = 1

local colorSection = section(editPage, "Colore", 2)
local palette = {
	rgb(255, 255, 255), rgb(255, 230, 140), rgb(255, 150, 50), rgb(230, 60, 40), rgb(255, 90, 180), rgb(170, 90, 255),
	rgb(90, 120, 255), rgb(90, 200, 255), rgb(110, 235, 160), rgb(140, 220, 60), rgb(120, 110, 100), rgb(30, 30, 34),
}
local startColor: Color3? = nil
local endColor: Color3? = nil
local preview = Instance.new("Frame")
preview.Size = UDim2.new(1, 0, 0, 16)
preview.LayoutOrder = 5
preview.BackgroundColor3 = Color3.new(1, 1, 1)
corner(preview, 4)
local previewGradient = Instance.new("UIGradient")
previewGradient.Parent = preview
preview.Parent = colorSection
local function refreshPreview()
	local a = startColor or Color3.new(1, 1, 1)
	previewGradient.Color = ColorSequence.new(a, endColor or a)
end
for row, which in { "inizio", "fine" } do
	label(colorSection, "Colore " .. which .. (if which == "fine" then " (facoltativo)" else ""), 12).LayoutOrder = row * 2 - 1
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(1, 0, 0, 22)
	strip.LayoutOrder = row * 2
	strip.Parent = colorSection
	local l = Instance.new("UIGridLayout")
	l.CellSize = UDim2.new(1 / #palette, -3, 1, 0)
	l.CellPadding = UDim2.new(0, 3, 0, 0)
	l.Parent = strip
	for _, c in palette do
		local sw = Instance.new("TextButton")
		sw.Text = ""
		sw.BackgroundColor3 = c
		sw.AutoButtonColor = true
		corner(sw, 4)
		sw.Parent = strip
		sw.Activated:Connect(function()
			if which == "inizio" then
				startColor = c
			else
				endColor = c
			end
			refreshPreview()
		end)
	end
end
refreshPreview()

local valuesSection = section(editPage, "Valori (vuoto = non cambiare; \"min max\" per gli intervalli)", 3)
local fSpeed = field(valuesSection, "Velocita' (min max)", 1)
local fSize = field(valuesSection, "Grandezza (inizio fine)", 2)
local fRate = field(valuesSection, "Tasso (particelle/s)", 3)
local fLife = field(valuesSection, "Durata (min max, s)", 4)
local fLight = field(valuesSection, "Luce emessa (0-1)", 5)
local fSpread = field(valuesSection, "Apertura (gradi)", 6)
local fTransp = field(valuesSection, "Trasparenza (inizio fine)", 7)
local fRot = field(valuesSection, "Rotazione (gradi/s)", 8)

local actions = section(editPage, "Azioni", 4)
local applyBtn = button(actions, "Applica alle particelle selezionate", Color3.fromRGB(0, 120, 215))
applyBtn.LayoutOrder = 1
local readBtn = button(actions, "Leggi valori dalla selezione")
readBtn.LayoutOrder = 2
local emitBtn = button(actions, "Emetti ora (prova)")
emitBtn.LayoutOrder = 3
local enableBtn = button(actions, "Accendi / spegni")
enableBtn.LayoutOrder = 4

local function fmt(n: number): string
	return string.format("%g", math.floor(n * 100 + 0.5) / 100)
end

local function refreshStatus()
	local n = #selectedEmitters()
	status.Text = if n == 0 then "Nessun ParticleEmitter selezionato" else string.format("%d ParticleEmitter selezionat%s", n, if n == 1 then "o" else "i")
end
Selection.SelectionChanged:Connect(refreshStatus)
refreshStatus()

applyBtn.Activated:Connect(function()
	local emitters = selectedEmitters()
	if #emitters == 0 then
		return
	end
	recorded("VFX: modifica particelle", function()
		for _, e in emitters do
			if startColor then
				e.Color = ColorSequence.new(startColor :: Color3, endColor or startColor :: Color3)
			end
			local a, b = readPair(fSpeed)
			if a then
				e.Speed = NumberRange.new(math.min(a, b :: number), math.max(a, b :: number))
			end
			a, b = readPair(fSize)
			if a then
				e.Size = NumberSequence.new(math.max(0, a), math.max(0, b :: number))
			end
			a = readPair(fRate)
			if a then
				e.Rate = math.max(0, a)
			end
			a, b = readPair(fLife)
			if a then
				e.Lifetime = NumberRange.new(math.max(0, math.min(a, b :: number)), math.max(a, b :: number))
			end
			a = readPair(fLight)
			if a then
				e.LightEmission = math.clamp(a, 0, 1)
			end
			a = readPair(fSpread)
			if a then
				e.SpreadAngle = Vector2.new(a, a)
			end
			a, b = readPair(fTransp)
			if a then
				e.Transparency = NumberSequence.new(math.clamp(a, 0, 1), math.clamp(b :: number, 0, 1))
			end
			a = readPair(fRot)
			if a then
				e.RotSpeed = NumberRange.new(-math.abs(a), math.abs(a))
			end
		end
	end)
end)

readBtn.Activated:Connect(function()
	local e = selectedEmitters()[1]
	if not e then
		return
	end
	fSpeed.Text = fmt(e.Speed.Min) .. " " .. fmt(e.Speed.Max)
	local k = e.Size.Keypoints
	fSize.Text = fmt(k[1].Value) .. " " .. fmt(k[#k].Value)
	fRate.Text = fmt(e.Rate)
	fLife.Text = fmt(e.Lifetime.Min) .. " " .. fmt(e.Lifetime.Max)
	fLight.Text = fmt(e.LightEmission)
	fSpread.Text = fmt(e.SpreadAngle.X)
	local t = e.Transparency.Keypoints
	fTransp.Text = fmt(t[1].Value) .. " " .. fmt(t[#t].Value)
	fRot.Text = fmt(math.max(math.abs(e.RotSpeed.Min), math.abs(e.RotSpeed.Max)))
	local ck = e.Color.Keypoints
	startColor = ck[1].Value
	endColor = ck[#ck].Value
	refreshPreview()
end)

emitBtn.Activated:Connect(function()
	for _, e in selectedEmitters() do
		e:Emit((e:GetAttribute("VFX_Burst") :: number?) or 25)
	end
end)

enableBtn.Activated:Connect(function()
	local emitters = selectedEmitters()
	if #emitters == 0 then
		return
	end
	recorded("VFX: accendi/spegni", function()
		local on = not emitters[1].Enabled
		for _, e in emitters do
			e.Enabled = on
		end
	end)
end)

------------------------------------------------------------------------------------------
-- Scheda RAGGI E SCIE

local beamPage = page("Raggi e scie")

local function attachmentOf(inst: Instance, name: string, offset: Vector3?): Attachment?
	if inst:IsA("Attachment") then
		return inst
	end
	local part: BasePart? = nil
	if inst:IsA("BasePart") then
		part = inst
	elseif inst:IsA("Model") then
		part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	if not part then
		return nil
	end
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = offset or Vector3.zero
	a.Parent = part
	return a
end

local beamSection = section(beamPage, "Raggio (Beam) tra due oggetti", 1)
label(beamSection, "Seleziona due parti o attacchi (Ctrl+click), poi scegli lo stile.", 12).LayoutOrder = 1
local fBeamWidth = field(beamSection, "Larghezza (inizio fine)", 2)
local fBeamSpeed = field(beamSection, "Velocita' texture", 3)
for i, def in BEAMS do
	local b = button(beamSection, "Raggio: " .. def.name, def.color:Lerp(Color3.new(0, 0, 0), 0.3))
	b.LayoutOrder = 10 + i
	b.Activated:Connect(function()
		local sel = Selection:Get()
		if #sel < 2 then
			warn("[VFX Studio] Seleziona due oggetti per il raggio")
			return
		end
		recorded("VFX: raggio " .. def.name, function()
			local a0 = attachmentOf(sel[1], "RaggioInizio")
			local a1 = attachmentOf(sel[2], "RaggioFine")
			if not a0 or not a1 then
				error("servono parti, modelli o attacchi")
			end
			local beam = Instance.new("Beam")
			beam.Name = "Raggio_" .. def.name
			for k, v in def.props do
				(beam :: any)[k] = v
			end
			beam.Color = ColorSequence.new(def.color)
			local w0, w1 = readPair(fBeamWidth)
			if w0 then
				beam.Width0, beam.Width1 = w0, w1 :: number
			end
			local sp = readPair(fBeamSpeed)
			if sp then
				beam.TextureSpeed = sp
			end
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Parent = a0.Parent
			Selection:Set({ beam })
		end)
	end)
end

local trailSection = section(beamPage, "Scia (Trail) su una parte", 2)
label(trailSection, "Seleziona la parte che si muove (es. la lama di una spada): la scia nasce tra due attacchi distanti \"Larghezza\".", 12).LayoutOrder = 1
local fTrailWidth = field(trailSection, "Larghezza (studs)", 2)
local fTrailLife = field(trailSection, "Lunghezza (secondi)", 3)
for i, def in TRAILS do
	local b = button(trailSection, "Scia: " .. def.name, def.color:Lerp(Color3.new(0, 0, 0), 0.35))
	b.LayoutOrder = 10 + i
	b.Activated:Connect(function()
		local target = Selection:Get()[1]
		if not target then
			warn("[VFX Studio] Seleziona una parte per la scia")
			return
		end
		recorded("VFX: scia " .. def.name, function()
			local w = readPair(fTrailWidth) or 2
			local a0 = attachmentOf(target, "SciaSopra", Vector3.new(0, w / 2, 0))
			local a1 = attachmentOf(target, "SciaSotto", Vector3.new(0, -w / 2, 0))
			if not a0 or not a1 then
				error("serve una parte o un modello")
			end
			local trail = Instance.new("Trail")
			trail.Name = "Scia_" .. def.name
			for k, v in def.props do
				(trail :: any)[k] = v
			end
			trail.Color = ColorSequence.new(def.color)
			local life = readPair(fTrailLife)
			if life then
				trail.Lifetime = math.max(0.05, life)
			end
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Parent = a0.Parent
			Selection:Set({ trail })
		end)
	end)
end

local cleanSection = section(beamPage, "Pulizia", 3)
local cleanBtn = button(cleanSection, "Togli gli effetti dalla selezione")
cleanBtn.LayoutOrder = 1
cleanBtn.Activated:Connect(function()
	recorded("VFX: togli effetti", function()
		for _, inst in Selection:Get() do
			for _, d in inst:GetDescendants() do
				if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
					d:Destroy()
				end
			end
		end
	end)
end)

showTab("Crea")
