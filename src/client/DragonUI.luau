--!strict
-- Menu dei draghi (scheda "Dragons" del menu), rifatto sul modello dei menu dei pet di Roblox
-- (Mirko: "troppe cose da cliccare, sul telefono fai fatica, immagini sfocate e non la forma
-- adulta"):
--   in alto: due schede (Dragons / Nest) e i contatori (pietre, draghi al seguito)
--   a sinistra: griglia di tessere grandi colorate per rarita', col modello 3D dello stadio vero
--   a destra: il drago scelto SEMPRE visibile (niente schede che si aprono sopra): modello che
--   gira, livello, statistiche e tre pulsanti grandi (Follow, Ride o Evolve, Sell)
-- La logica resta sul server (Remotes.DragonAction, Remotes.DragonRide).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local DragonConfig = require(Shared:WaitForChild("DragonConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local UpgradeConfig = require(Shared:WaitForChild("UpgradeConfig"))
local Names = require(Shared:WaitForChild("Names"))
local Ui = require(Shared:WaitForChild("UiView"))
local Theme = require(script.Parent.Theme)
local UiGlow = require(script.Parent.UiGlow)
local UiKit = require(script.Parent.UiKit)
local player = Players.LocalPlayer
local DragonUI = {}

-- uova nel nido: il conto alla rovescia si aggiorna da solo ogni secondo (DragonUI.tick)
type Timer = { label: TextLabel, hatch: GuiObject, readyAt: number }
local timers: { Timer } = {}

-- voto complessivo (40-99, come le carte FIFA)
local MAX_ATTACK = DragonConfig.attack({ stage = #DragonConfig.STAGES, level = DragonConfig.MAX_LEVEL, atk = 1.5 })
local function overall(d: any): number
	return math.clamp(math.floor(40 + 59 * math.sqrt(DragonConfig.attack(d) / MAX_ATTACK) + 0.5), 40, 99)
end
local GRADE_COLORS = Theme.GRADE
-- colori per rarita' (tessere e nome): grigio, blu, viola, oro
local RARITY_COLORS = Theme.RARITY
local PREVIEW_KIND = { "Dragons", "DragonsYoung", "DragonsAdult" }

local function preview(kind: string, element: string): Instance?
	local f = RS:FindFirstChild("Previews")
	local sub = f and f:FindFirstChild(kind)
	return sub and sub:FindFirstChild(element)
end

-- il drago nello stadio giusto (l'adulto ha il suo modello) su un altare di pietra con l'anello di
-- rune del suo elemento, visto di tre quarti dalla parte della testa (ossa del collo: attributi
-- Ruolo, DragonModels.markBones). Prima fluttuava su un fondo piatto dentro un bordo bianco
local function part(parent: Instance, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, transparency: number?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.Anchored = true
	p.Parent = parent
	return p
end

local function dragonView(parent: Instance, d: any, spin: boolean): ViewportFrame
	local stage = math.clamp(d.stage or 1, 1, 3)
	local object = preview(PREVIEW_KIND[stage], d.element) or preview("Dragons", d.element)
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	-- luce calda di tre quarti davanti e ambiente basso: il drago ha volume (prima tutto chiaro e
	-- piatto)
	vf.Ambient = Color3.fromRGB(150, 145, 165)
	vf.LightColor = Color3.fromRGB(255, 236, 205)
	vf.Parent = parent
	if not object then
		return vf
	end
	local world = Instance.new("WorldModel")
	world.Parent = vf
	local clone = object:Clone() :: Model
	for _, child in clone:GetDescendants() do
		if child:IsA("LuaSourceContainer") then child:Destroy() end
	end
	clone.Parent = world
	local cf, size = clone:GetBoundingBox()
	-- davanti: verso la testa
	local front = -clone:GetPivot().LookVector
	local head: Vector3? = nil
	local best = -1
	for _, b in clone:GetDescendants() do
		if b:IsA("Bone") and b:GetAttribute("Ruolo") == "neck" then
			local i = (b:GetAttribute("Indice") or 0) :: number
			if i > best then
				best, head = i, b.WorldPosition
			end
		end
	end
	if head then
		local flat = Vector3.new((head :: Vector3).X - cf.Position.X, 0, (head :: Vector3).Z - cf.Position.Z)
		if flat.Magnitude > 0.1 then
			front = flat.Unit
		end
	end
	-- altare: il drago poggia sopra (base del riquadro = piano dell'altare)
	local foot = math.max(size.X, size.Z) * 0.42
	local h = size.Y * 0.16
	local bottom = cf.Position.Y - size.Y / 2
	local top = bottom
	local base = Vector3.new(cf.Position.X, bottom - h / 2, cf.Position.Z)
	local up = CFrame.Angles(0, 0, math.pi / 2)
	local e = DragonConfig.element(d.element)
	local rune = if e then e.glow else Color3.fromRGB(255, 200, 90)
	part(world, Enum.PartType.Cylinder, Vector3.new(h, foot * 2, foot * 2), CFrame.new(base) * up, Color3.fromRGB(46, 44, 54), Enum.Material.Slate)
	part(world, Enum.PartType.Cylinder, Vector3.new(h * 0.35, foot * 2.25, foot * 2.25), CFrame.new(base - Vector3.new(0, h * 0.5, 0)) * up, Color3.fromRGB(34, 32, 40), Enum.Material.Slate)
	part(world, Enum.PartType.Cylinder, Vector3.new(h * 0.18, foot * 2.06, foot * 2.06), CFrame.new(Vector3.new(base.X, top - h * 0.05, base.Z)) * up, Color3.fromRGB(176, 128, 64), Enum.Material.Metal)
	part(world, Enum.PartType.Cylinder, Vector3.new(h * 0.06, foot * 1.7, foot * 1.7), CFrame.new(Vector3.new(base.X, top + h * 0.02, base.Z)) * up, rune, Enum.Material.Neon, 0.25)
	part(world, Enum.PartType.Cylinder, Vector3.new(h * 0.08, foot * 1.55, foot * 1.55), CFrame.new(Vector3.new(base.X, top + h * 0.04, base.Z)) * up, Color3.fromRGB(40, 38, 48), Enum.Material.Slate)
	-- camera: drago + altare tutti dentro, un po' dall'alto
	local center = Vector3.new(cf.Position.X, (bottom - h + cf.Position.Y + size.Y / 2) / 2, cf.Position.Z)
	local radius = math.max(size.Magnitude / 2, foot * 1.2) * 1.02
	vf.LightDirection = -(front * 0.6 + Vector3.new(0, 1, 0) + front:Cross(Vector3.yAxis) * 0.5).Unit
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = vf
	vf.CurrentCamera = camera
	local dist = radius / math.tan(math.rad(15)) * 0.74
	local function aim(a: number)
		local dir = (CFrame.fromAxisAngle(Vector3.yAxis, a) * front) + Vector3.new(0, 0.38, 0)
		camera.CFrame = CFrame.lookAt(center + dir.Unit * dist, center)
	end
	aim(math.rad(35))
	if spin then
		task.spawn(function()
			local a = math.rad(35)
			while vf.Parent do
				a += 0.012
				aim(a)
				task.wait(1 / 30)
			end
		end)
	end
	return vf
end

-- alone dietro il drago (cerchio sfumato del colore della rarita')
local function halo(parent: Instance, color: Color3)
	local g = Instance.new("Frame")
	g.Name = "Alone"
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, 0.45)
	g.Size = UDim2.fromScale(0.8, 0.8)
	g.BackgroundColor3 = color
	g.BackgroundTransparency = 0.7
	g.BorderSizePixel = 0
	g.Parent = parent
	-- Ellisse contenuta nel palco, senza vincoli che ne allarghino i bordi.
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
	grad.Parent = g
end

local function label(parent: Instance, str: string, size: number, color: Color3?, bold: boolean?, align: Enum.TextXAlignment?): TextLabel
	local l = Theme.label(parent, str, size, color, bold)
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Font = if bold then Enum.Font.GothamBlack else Enum.Font.GothamBold
	Theme.fitText(l, size, false)
	return l
end

local function bar(parent: Instance, k: number, color: Color3): Frame
	local back = Theme.frame(parent, Theme.CARD, 0.1)
	Theme.corner(back, 6)
	local fill = Theme.frame(back, color, 0)
	fill.Size = UDim2.fromScale(math.clamp(k, 0, 1), 1)
	Theme.corner(fill, 6)
	return back
end

-- pulsante grande colorato (facile da premere col pollice)
-- (stile unico del menu, client/UiKit: azione principale oro, secondaria a bordo, vendita rossa)
local function bigButton(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 140, 0, 52)
	button.Text = text
	button.Parent = parent
	local kind = if color == Theme.BAD then "danger" elseif color == Theme.DISABLED then "disabled"
		elseif color == Theme.GOOD or color == Theme.PURPLE or color == Theme.ACCENT then "primary" else "secondary"
	UiKit.button(button, kind)
	button.Text = string.upper(text)
	return button
end

-- (la usa anche client/DragonReveal per la schiusa e l'evoluzione)
DragonUI.view = dragonView

function DragonUI.mount(container: Frame, status: (string, boolean) -> ()): () -> ()
	-- il vecchio impianto (titolo e due colonne del modello in StarterGui) resta nascosto
	for _, n in { "Header", "Body" } do
		local old = container:FindFirstChild(n)
		if old and old:IsA("GuiObject") then
			old.Visible = false
		end
	end
	local root = Theme.frame(container, Color3.new(), 1)
	root.Name = "MenuDraghi"
	root.Size = UDim2.fromScale(1, 1)

	local function act(kind: string, arg: any)
		local ok, message = (RS.Remotes:WaitForChild("DragonAction") :: RemoteFunction):InvokeServer(kind, arg)
		status(message or "", ok)
	end

	-- barra in alto: schede e contatori
	local top = Theme.frame(root, Color3.new(), 1)
	top.Name = "Tabs"
	top.Size = UDim2.new(1, 0, 0, 44)
	local tabDragons = bigButton(top, "Dragons", Theme.PURPLE)
	tabDragons.Size = UDim2.new(0, 170, 1, 0)
	local tabNest = bigButton(top, "Nest", Theme.DISABLED)
	tabNest.Position = UDim2.new(0, 180, 0, 0)
	tabNest.Size = UDim2.new(0, 150, 1, 0)
	local counters = label(top, "", 18, Theme.ACCENT, true, Enum.TextXAlignment.Right)
	counters.AnchorPoint = Vector2.new(1, 0)
	counters.Position = UDim2.new(1, -4, 0, 6)
	counters.Size = UDim2.new(1, -350, 1, -12)

	-- corpo: griglia a sinistra, drago scelto a destra
	local body = Theme.frame(root, Color3.new(), 1)
	body.Position = UDim2.new(0, 0, 0, 54)
	body.Size = UDim2.new(1, 0, 1, -54)
	local gridBox = Theme.frame(body, Theme.CARD, 0.35)
	gridBox.Size = UDim2.new(0.42, -8, 1, 0)
	Theme.corner(gridBox, 12)
	local grid = Theme.scroll(gridBox)
	grid.Size = UDim2.new(1, -12, 1, -12)
	grid.Position = UDim2.fromOffset(6, 6)
	grid.ScrollBarThickness = 8
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.Parent = grid
	-- fondo scuro stile Black Ops 2 (carbone, fumo, brace): prima riquadri blu e verdi pieni
	UiKit.panel(gridBox, { transparency = 0.3, ticks = false })
	grid.ZIndex = 2
	local detailBack = Theme.frame(body, Theme.DARK, 1)
	detailBack.Name = "FondoScheda"
	UiKit.panel(detailBack, { transparency = 0.25 })
	local detailScroll = Theme.scroll(body)
	detailScroll.Name = "DragonDetails"
	detailScroll.BackgroundTransparency = 1
	detailScroll.ScrollBarThickness = 6
	local detail = Theme.frame(detailScroll, Theme.DARK, 1)
	detail.Size = UDim2.new(1, -8, 0, 490)
	detailScroll.AnchorPoint = Vector2.new(1, 0)
	detailScroll.Position = UDim2.fromScale(1, 0)
	detailScroll.Size = UDim2.new(0.58, 0, 1, 0)
	detailScroll.ZIndex = 2
	-- piede fisso coi pulsanti (Follow, Evolve/Ride, Sell): fuori dallo scorrimento, sempre
	-- dentro lo schermo (prima stavano in fondo alla scheda e sul telefono si perdevano)
	local dFoot = Theme.frame(body, Color3.new(), 1)
	dFoot.Name = "PiedeDrago"
	dFoot.AnchorPoint = Vector2.new(1, 1)
	dFoot.ZIndex = 3
	local footH = 56

	-- telefono (attributo ShortUI della schermata, schermi bassi): schede basse, tessere e palco piccoli
	local function short(): boolean
		local gui = container:FindFirstAncestorWhichIsA("ScreenGui")
		return gui ~= nil and gui:GetAttribute("ShortUI") == true
	end
	-- misure in pixel LOGICI (AbsoluteSize diviso la scala della schermata). Prima si usavano i
	-- pixel veri: col computer a scala 1,5 le celle uscivano dalla griglia, che andava a capo con
	-- due colonne e un grande vuoto a destra (Mirko 16/10)
	local function uiScale(): number
		local gui = container:FindFirstAncestorWhichIsA("ScreenGui")
		local su = gui and gui:FindFirstChild("ScalaUI")
		return if su and su:IsA("UIScale") and su.Scale > 0 then su.Scale else 1
	end
	local function arrange()
		local tabH = if short() then 34 else 44
		top.Size = UDim2.new(1, 0, 0, tabH)
		body.Position = UDim2.new(0, 0, 0, tabH + 8)
		body.Size = UDim2.new(1, 0, 1, -(tabH + 8))
  local narrow = body.AbsoluteSize.X / uiScale() < 520
  -- collezione a sinistra e scheda a destra a meta' (stessa impaginazione su telefono e computer)
  local gridShare = 0.5
  footH = if short() then 46 else 56
  gridBox.Position = UDim2.fromScale(0, 0)
  gridBox.Size = if narrow then UDim2.new(1, 0, 0.30, -4) else UDim2.new(gridShare, -8, 1, 0)
  detailScroll.Position = if narrow then UDim2.fromScale(1, 0.30) else UDim2.fromScale(1, 0)
  detailScroll.Size = if narrow then UDim2.new(1, 0, 0.70, -(footH + 8)) else UDim2.new(1 - gridShare, 0, 1, -(footH + 8))
  detailBack.AnchorPoint = detailScroll.AnchorPoint
  detailBack.Position = detailScroll.Position
  detailBack.Size = detailScroll.Size + UDim2.fromOffset(0, footH + 8)
  dFoot.Position = UDim2.new(1, -6, 1, -4)
  dFoot.Size = UDim2.new(if narrow then 1 else 1 - gridShare, -12, 0, footH)
  tabDragons.Size = UDim2.new(0.3, -4, 1, 0)
  tabNest.Position = UDim2.fromScale(0.3, 0)
  tabNest.Size = UDim2.new(0.25, -4, 1, 0)
  counters.Size = UDim2.new(0.45, -8, 1, -4)
 end
 body:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
 arrange()

	local tab = "Dragons"
	local autoTab = true -- finche' non scegli tu: uovo pronto (o nessun drago) -> Nest
	local selected: number? = nil
	local confirmSell: number? = nil
	local lastData: any = nil
	local render: () -> ()

	local function setTab(name: string)
		tab = name
		UiKit.tab(tabDragons, name == "Dragons")
		UiKit.tab(tabNest, name == "Nest")
		render()
	end
	tabDragons.Activated:Connect(function()
		autoTab = false
		setTab("Dragons")
	end)
	tabNest.Activated:Connect(function()
		autoTab = false
		setTab("Nest")
	end)

	-- celle della griglia: 3-5 colonne secondo la larghezza
	local function sizeGrid(aspect: number)
		-- tessere che riempiono tutta la larghezza: 2-5 colonne di almeno 130 px
		local width = math.max(grid.AbsoluteSize.X / uiScale() - 14, 160)
		local cols = math.clamp(math.floor((width + 8) / 138), 2, 5)
		local cell = math.floor((width - (cols - 1) * 8) / cols)
		layout.CellSize = UDim2.fromOffset(cell, math.max(if aspect > 1.3 then 190 else 150, math.floor(cell * aspect)))
	end

	-- pannello di destra: il drago scelto
	local function showDetail(data: any, d: any?)
		for _, c in detail:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if not d then
			for _, c in dFoot:GetChildren() do
				c:Destroy()
			end
			local hint = label(detail, "Hatch an egg to get your first dragon!", 20, Theme.MUTED, true, Enum.TextXAlignment.Center)
			hint.Position = UDim2.fromScale(0.05, 0.4)
			hint.Size = UDim2.fromScale(0.9, 0.2)
			return
		end
		local colors = RARITY_COLORS[d.rarity] or RARITY_COLORS.Comune
		local stage = DragonConfig.STAGES[d.stage] or DragonConfig.STAGES[1]
		local nextStage = DragonConfig.STAGES[d.stage + 1]
		local following = table.find(data.equipped, d.id) ~= nil
		local level = d.level or 1
		local maxed = level >= DragonConfig.MAX_LEVEL
		local grade = DragonConfig.grade(d)
		-- nome e rarita'
		local named = type(d.name) == "string" and d.name ~= ""
		local name = label(detail, (if d.shiny then "✦ " else "") .. (if named then d.name else Names.dragon(d.element)), 26, Color3.new(1, 1, 1), true)
		name.Position = UDim2.new(0, 14, 0, 8)
		name.Size = UDim2.new(1, -90, 0, 30)
		local rar = label(detail, Names.t(d.rarity) .. "  ·  " .. Names.t(stage.name) .. (if named then "  ·  " .. Names.dragon(d.element) else ""), 17, colors[1], true)
		rar.Position = UDim2.new(0, 14, 0, 38)
		rar.Size = UDim2.new(1, -90, 0, 20)
		local ovr = label(detail, tostring(overall(d)), 34, GRADE_COLORS[grade], true, Enum.TextXAlignment.Right)
		ovr.AnchorPoint = Vector2.new(1, 0)
		ovr.Position = UDim2.new(1, -12, 0, 6)
		ovr.Size = UDim2.new(0, 70, 0, 38)
		local element = DragonConfig.element(d.element)
		local tone = Theme.ELEMENT[d.element] or Theme.BLUE
		-- larghezza vera della scheda in pixel logici (senza la scala della schermata)
		local gui = detail:FindFirstAncestorWhichIsA("ScreenGui")
		local su = gui and gui:FindFirstChild("ScalaUI")
		local scale = if su and su:IsA("UIScale") and su.Scale > 0 then su.Scale else 1
		local W = math.max(260, detailScroll.AbsoluteSize.X / scale - 8)
		local wide = W >= 470 or short()
		-- palco QUADRATO (prima una striscia larga e bassa): a sinistra, statistiche a destra;
		-- sulle schede strette il quadrato sta in mezzo e le statistiche sotto
		local S = if wide then math.floor(math.min(270, W * 0.46)) else math.floor(math.min(230, W - 20))
		if short() then
			S = math.min(math.floor(W * 0.42), 156) -- telefono: palco a sinistra, statistiche accanto
		end
		-- il drago scelto e' il centro della scena: niente riquadro, solo l'alone fermo, e il
		-- modello un po' piu' grande del palco (esce dai bordi, non e' chiuso in una carta)
		local stageBox = Theme.frame(detail, Theme.DARK, 1)
		stageBox.ClipsDescendants = false
		stageBox.Name = "Palco"
		stageBox.Position = if wide then UDim2.fromOffset(10, 66) else UDim2.new(0.5, -S / 2, 0, 66)
		stageBox.Size = UDim2.fromOffset(S, S)
		-- sfondo: la valle col ghiacciaio dell'illustrazione del caricamento (bg_loading, gia'
		-- caricata), al posto del fondo nero con la "bolla grigia" (Mirko 16/10: "fa schifo").
		-- Il drago esce un po' dal quadro, che sfuma in basso nel pannello
		local valley = Instance.new("ImageLabel")
		valley.Name = "Valle"
		valley.BackgroundTransparency = 1
		valley.Size = UDim2.fromScale(1, 1)
		valley.ZIndex = 1
		valley.Parent = stageBox
		if Ui.asset(valley, "bg_drago_valle") then
			valley.ScaleType = Enum.ScaleType.Crop
		elseif Ui.asset(valley, "bg_loading") then
			-- solo la parte destra (cima e ghiacciaio, senza lo scalatore), quadrata
			valley.ScaleType = Enum.ScaleType.Stretch
			valley.ImageRectOffset = Vector2.new(440, 0)
			valley.ImageRectSize = Vector2.new(576, 576)
		else
			valley:Destroy()
			halo(stageBox, tone)
		end
		if valley.Parent then
			local fade = Instance.new("UIGradient")
			fade.Rotation = 90
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.7, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			})
			fade.Parent = valley
			UiKit.edge(valley, UiKit.LINE, 1, 0.75)
		end
		local view = dragonView(stageBox, d, true)
		view.AnchorPoint = Vector2.new(0.5, 0.5)
		view.Position = UDim2.fromScale(0.5, 0.48)
		view.Size = UDim2.fromScale(1.18, 1.18)
		view.ZIndex = 3
		local rows = {
			{"Grade", grade, "elem_" .. d.element},
			{"Power", tostring(math.floor(DragonConfig.attack(d))), "item_UpgradeUncino"},
			{"Level", string.format("%d / %d", level, DragonConfig.MAX_LEVEL), "icon_quest"},
			{"Coins/min at home", tostring((EconomyConfig.ROOST_RATE[d.rarity] or 1) * d.stage), "icon_coin"},
		}
		if nextStage then
			table.insert(rows, {"Evolve", if not maxed then string.format("Reach Lv %d", DragonConfig.MAX_LEVEL)
				else string.format("%d / %d stones", math.min(data.stones or 0, nextStage.stones), nextStage.stones), "ore_Cristallo"})
		else
			local attack = UpgradeConfig.RIDE_ELEMENT[d.element]
			table.insert(rows, {"Ride attack", if attack then attack.text else "—", "elem_" .. d.element})
		end
		table.insert(rows, {"Status", if following then "Following" else "Resting", "elem_" .. d.element})
		-- statistiche: righe semplici (nome a sinistra, valore a destra, una linea sottile sotto),
		-- niente riquadri dentro riquadri
		local statsX = if wide then 10 + S + 14 else 10
		local statsY = if wide then 66 else 66 + S + 10
		local statsW = if wide then W - S - 34 else W - 20
		local rowH = if wide then math.floor(S / #rows) else 38
		local twoCols = not wide and statsW >= 360
		local perCol = if twoCols then math.ceil(#rows / 2) else #rows
		local colW = if twoCols then (statsW - 12) / 2 else statsW
		for i, r in rows do
			local col = if twoCols and i > perCol then 1 else 0
			local line = Theme.frame(detail, Theme.DARK, 1)
			line.Position = UDim2.fromOffset(statsX + col * (colW + 12), statsY + ((i - 1) % perCol) * rowH)
			line.Size = UDim2.fromOffset(colW, rowH)
			local sep = Theme.frame(line, Theme.DARK3, 0.2)
			sep.AnchorPoint = Vector2.new(0, 1)
			sep.Position = UDim2.fromScale(0, 1)
			sep.Size = UDim2.new(1, 0, 0, 1)
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 0, 0.5, 0)
			icon.Size = UDim2.fromOffset(20, 20)
			icon.Parent = line
			Ui.asset(icon, r[3])
			local key = label(line, r[1], 14, Theme.MUTED, false)
			key.AnchorPoint = Vector2.new(0, 0.5)
			key.Position = UDim2.new(0, 26, 0.5, 0)
			key.Size = UDim2.new(0.5, -26, 0, 22)
			local value = label(line, r[2], 18, if i == 1 then GRADE_COLORS[grade] else Theme.TEXT, true, Enum.TextXAlignment.Right)
			value.AnchorPoint = Vector2.new(1, 0.5)
			value.Position = UDim2.new(1, 0, 0.5, 0)
			value.Size = UDim2.new(0.5, 0, 0, 24)
		end
		local statsBottom = statsY + perCol * rowH
		local abilityY = math.max(66 + (if wide then S else 0), statsBottom) + 12
		-- abilita' speciale: fondo scuro con una barra del colore dell'elemento a sinistra (prima
		-- un riquadro verde pieno)
		local ability = Theme.frame(detail, Theme.DARK2, 0.25)
		ability.Name = "SpecialAbility"
		ability.Position = UDim2.fromOffset(10, abilityY)
		ability.Size = UDim2.new(1, -20, 0, 84)
		Theme.corner(ability, 10)
		local accent = Theme.frame(ability, tone, 0)
		accent.Size = UDim2.new(0, 5, 1, 0)
		local abilityIcon = Instance.new("ImageLabel")
		abilityIcon.BackgroundTransparency = 1
		abilityIcon.Position = UDim2.fromOffset(16, 10)
		abilityIcon.Size = UDim2.fromOffset(30, 30)
		abilityIcon.Parent = ability
		Ui.asset(abilityIcon, "elem_" .. d.element)
		local heading = label(ability, "Special ability", 18, tone, true)
		heading.Position = UDim2.fromOffset(52, 10)
		heading.Size = UDim2.new(1, -60, 0, 28)
		local description = label(ability, if element then element.ability else "—", 17, Theme.TEXT, false)
		description.Position = UDim2.fromOffset(16, 42)
		description.Size = UDim2.new(1, -28, 0, 36)
		Theme.fitText(description, 17, true)
		-- nome del drago (Mirko 15/10: "puoi dargli un nome dopo un certo livello")
		local nameRow = Theme.frame(detail, Theme.DARK2, 0.25)
		nameRow.Name = "NomeDrago"
		nameRow.Position = UDim2.fromOffset(10, abilityY + 84 + 10)
		nameRow.Size = UDim2.new(1, -20, 0, 48)
		Theme.corner(nameRow, 10)
		if level >= DragonConfig.NAME_LEVEL then
			local box = Instance.new("TextBox")
			box.PlaceholderText = if named then "New name..." else "Give your dragon a name..."
			box.Text = ""
			box.ClearTextOnFocus = false
			box.Font = Enum.Font.GothamBold
			box.TextSize = 17
			box.TextColor3 = Theme.TEXT
			box.PlaceholderColor3 = Theme.MUTED
			box.TextXAlignment = Enum.TextXAlignment.Left
			box.BackgroundTransparency = 1
			box.Position = UDim2.fromOffset(14, 0)
			box.Size = UDim2.new(1, -150, 1, 0)
			box.Parent = nameRow
			local ok = bigButton(nameRow, "Name", Theme.ACCENT)
			ok.AnchorPoint = Vector2.new(1, 0.5)
			ok.Position = UDim2.new(1, -6, 0.5, 0)
			ok.Size = UDim2.new(0, 124, 1, -10)
			Theme.action(ok, "main")
			ok.Activated:Connect(function()
				if box.Text ~= "" then
					local okName, message = (RS.Remotes:WaitForChild("DragonAction") :: RemoteFunction):InvokeServer("rename", d.id, box.Text)
					status(message or "", okName)
				end
			end)
		else
			local hintName = label(nameRow, string.format("🔒  Reach level %d to give your dragon a name", DragonConfig.NAME_LEVEL), 16, Theme.MUTED, true)
			hintName.Position = UDim2.fromOffset(14, 0)
			hintName.Size = UDim2.new(1, -28, 1, 0)
		end
		local rowY = abilityY + 84 + 12 + 48
		detail.Size = UDim2.new(1, -8, 0, rowY + 16)
		-- pulsanti grandi nel piede fisso
		for _, c in dFoot:GetChildren() do
			c:Destroy()
		end
		local row = Theme.frame(dFoot, Color3.new(), 1)
		row.Size = UDim2.fromScale(1, 1)
		local follow = bigButton(row, if following then "Rest" else "Follow", if following then Theme.DISABLED else Theme.GOOD)
		follow.Activated:Connect(function()
			act(if following then "unequip" else "equip", d.id)
		end)
		local middle: TextButton
		if nextStage then
			local ready = maxed and (data.stones or 0) >= nextStage.stones
			middle = bigButton(row, "Evolve", if ready then Theme.PURPLE else Theme.DISABLED)
			UiKit.button(middle, if ready then "primary" else "disabled")
			middle.Text = "EVOLVE"
			middle.Activated:Connect(function()
				act("evolve", d.id)
			end)
		else
			middle = bigButton(row, "Ride", Theme.BLUE)
			middle.Activated:Connect(function()
				local remote = RS.Remotes:FindFirstChild("DragonRide") :: RemoteEvent?
				if remote then
					remote:FireServer(d.id)
					local gui = container:FindFirstAncestorWhichIsA("ScreenGui")
					if gui then
						gui:SetAttribute("MenuOpen", false)
					end
				end
			end)
		end
		local price = (EconomyConfig.DRAGON_PRICES[d.rarity] or 20) * d.stage
		local sell = bigButton(row, if confirmSell == d.id then "Sure?" else "Sell " .. price, Theme.BAD)
		sell.Activated:Connect(function()
			if confirmSell == d.id then
				confirmSell = nil
				selected = nil
				act("sell", d.id)
			else
				confirmSell = d.id
				sell.Text = "Sure?"
			end
		end)
		for i, b in { follow, middle, sell } do
			b.Position = UDim2.new((i - 1) / 3, if i == 1 then 0 else 4, 0, 0)
			b.Size = UDim2.new(1 / 3, -6, 1, 0)
		end
	end

	-- una tessera della griglia
	local function dragonTile(data: any, d: any, index: number)
		local following = table.find(data.equipped, d.id) ~= nil
		local colors = RARITY_COLORS[d.rarity] or RARITY_COLORS.Comune
		local tile = Instance.new("TextButton")
		tile.Name = "Drago" .. d.id
		tile.Text = ""
		tile.AutoButtonColor = true
		tile.LayoutOrder = (if following then 0 else 1000) + index
		-- tessera scura con un bagliore del colore della rarita' dal basso (prima arancio/blu pieno)
		tile.BackgroundColor3 = Theme.DARK2
		tile.BackgroundTransparency = 0.15
		tile.Parent = grid
		Theme.corner(tile, 12)
		Theme.gradient(tile, Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 135, 145), 90)
		tile.ClipsDescendants = true
		local glow = Theme.frame(tile, colors[1], 0)
		glow.Name = "Bagliore"
		glow.AnchorPoint = Vector2.new(0.5, 1)
		glow.Position = UDim2.fromScale(0.5, 1)
		glow.Size = UDim2.fromScale(1, 0.6)
		local gg = Instance.new("UIGradient")
		gg.Rotation = 90
		gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.45) })
		gg.Parent = glow
		local strip = Theme.frame(tile, colors[1], 0)
		strip.AnchorPoint = Vector2.new(0, 1)
		strip.Position = UDim2.fromScale(0, 1)
		strip.Size = UDim2.new(1, 0, 0, 3)
  local abilityIcon = Instance.new("ImageLabel")
  abilityIcon.Name = "AbilityIcon"
  abilityIcon.BackgroundTransparency = 1
  abilityIcon.Position = UDim2.fromOffset(6, 30)
  abilityIcon.Size = UDim2.fromOffset(28, 28)
  abilityIcon.ZIndex = 3
  abilityIcon.Parent = tile
  Ui.asset(abilityIcon, "elem_" .. d.element)
  local isSel = selected == d.id
		-- scelto: bordo d'accento, segno a sinistra e un po' piu' vicino (stati di client/UiKit)
		UiKit.physical(tile)
		UiKit.select(tile, isSel)
		local vf = dragonView(tile, d, false)
		vf.Position = UDim2.fromScale(0.03, 0.04)
		vf.Size = UDim2.fromScale(0.94, 0.74)
		local lv = label(tile, "Lv " .. tostring(d.level or 1), 15, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Left)
		lv.Position = UDim2.new(0, 6, 1, -24)
		lv.Size = UDim2.new(0.6, 0, 0, 20)
		local stageTag = label(tile, ({ "Baby", "Young", "Adult" })[math.clamp(d.stage or 1, 1, 3)], 13, colors[1], true, Enum.TextXAlignment.Right)
		stageTag.Position = UDim2.new(0.4, -6, 1, -24)
		stageTag.Size = UDim2.new(0.6, 0, 0, 20)
		if following then
			local tick = label(tile, "✓", 20, Theme.GOOD, true, Enum.TextXAlignment.Right)
			tick.Position = UDim2.new(1, -30, 0, 2)
			tick.Size = UDim2.fromOffset(26, 24)
		end
		if d.shiny then
			local rainbow = Instance.new("UIGradient")
			rainbow.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.PINK), ColorSequenceKeypoint.new(0.33, Theme.ACCENT), ColorSequenceKeypoint.new(0.66, Theme.TEAL), ColorSequenceKeypoint.new(1, Theme.PURPLE)})
			rainbow.Parent = strip
			local sh = label(tile, "✦", 18, Theme.ACCENT, true)
			sh.Position = UDim2.fromOffset(6, 2)
			sh.Size = UDim2.fromOffset(24, 24)
		end
		tile.Activated:Connect(function()
			confirmSell = nil
			selected = d.id
			render()
		end)
	end

	-- una tessera del nido (uovo, tempo, Hatch)
	local function eggTile(egg: any, index: number)
		local colors = RARITY_COLORS[egg.rarity] or RARITY_COLORS.Comune
		local tile = Theme.frame(grid, Theme.DARK2, 0.15)
		tile.LayoutOrder = index
		Theme.corner(tile, 12)
		local glow = Theme.frame(tile, colors[1], 0)
		glow.AnchorPoint = Vector2.new(0.5, 0)
		glow.Position = UDim2.fromScale(0.5, 0)
		glow.Size = UDim2.fromScale(1, 0.45)
		local gg = Instance.new("UIGradient")
		gg.Rotation = 90
		gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		gg.Parent = glow
		UiGlow.rays(glow, colors[1], 6, 12).Position = UDim2.fromScale(0.5, 0.6)
		local vf = Theme.viewport(tile, preview("Eggs", egg.element), UDim2.fromScale(0.8, 0.28), true)
		vf.Position = UDim2.fromScale(0.1, 0.04)
		local name = label(tile, Names.t(egg.element) .. " egg", 15, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
		name.Position = UDim2.fromScale(0.04, 0.58)
		name.Size = UDim2.fromScale(0.92, 0.13)
  local element = DragonConfig.element(egg.element)
  local ability = label(tile, if element then element.ability else "", 12, Theme.TEXT, true)
  ability.Name = "HatchAbility"
  ability.Position = UDim2.fromScale(0.04, 0.33)
  ability.Size = UDim2.fromScale(0.92, 0.24)
  Theme.fitText(ability, 12, true)
		local left = math.max(0, egg.readyAt - os.time())
		local time = label(tile, "", 14, Theme.ACCENT, true, Enum.TextXAlignment.Center)
		time.Position = UDim2.fromScale(0.04, 0.69)
		time.Size = UDim2.fromScale(0.92, 0.11)
		local hatch = bigButton(tile, "Hatch!", Theme.GOOD)
		hatch.Position = UDim2.new(0.08, 0, 1, -54)
		hatch.Size = UDim2.new(0.84, 0, 0, 48)
		hatch.Visible = left <= 0
		time.Visible = left > 0
		time.Text = string.format("Ready in %d:%02d", left // 60, left % 60)
		table.insert(timers, { label = time, hatch = hatch, readyAt = egg.readyAt })
		-- un tocco solo: il secondo (prima che arrivino i dati nuovi) schiudeva l'uovo dopo
		local pressed = false
		hatch.Activated:Connect(function()
			if pressed then
				return
			end
			pressed = true
			hatch.Text = "HATCHING..."
			act("hatch", index)
		end)
	end

	render = function()
		table.clear(timers)
		Ui.clear(grid)
		local oldEmpty = gridBox:FindFirstChild("Vuoto")
		if oldEmpty then
			oldEmpty:Destroy()
		end
		local raw = player:GetAttribute("DragonData")
		if type(raw) ~= "string" then
			return
		end
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok or type(data) ~= "table" then
			return
		end
		lastData = data
		if autoTab then
			local ready = #data.dragons == 0
			for _, egg in data.nest do
				if egg.readyAt <= os.time() then
					ready = true
				end
			end
			tab = if ready then "Nest" else "Dragons"
			UiKit.tab(tabDragons, tab == "Dragons")
			UiKit.tab(tabNest, tab == "Nest")
		end
		counters.Text = string.format("%d stones · %d/%d", data.stones or 0, #data.equipped, data.maxEquipped or 1)
		tabDragons.Text = string.format("Dragons %d", #data.dragons)
		tabNest.Text = string.format("Nest %d/%d", #data.nest, data.nestSlots or 0)
		if tab == "Nest" then
			sizeGrid(1.35)
			for index, egg in data.nest do
				eggTile(egg, index)
			end
			if #data.nest == 0 then
				-- fuori dalla griglia: dentro prendeva la misura di una tessera e si troncava
				local t = label(gridBox, if (data.nestSlots or 0) > 0 then "Find eggs and bring them to your nest" else "Buy the Tent to unlock the nest", 18, Theme.MUTED, true, Enum.TextXAlignment.Center)
				t.Name = "Vuoto"
				t.AnchorPoint = Vector2.new(0.5, 0.5)
				t.Position = UDim2.fromScale(0.5, 0.45)
				t.Size = UDim2.new(1, -40, 0, 60)
				t.TextWrapped = true
				t.TextTruncate = Enum.TextTruncate.None
				t.ZIndex = 4
			end
		else
			sizeGrid(1.15)
			for index, d in data.dragons do
				dragonTile(data, d, index)
			end
		end
		-- il drago scelto (se non c'e' piu', il primo al seguito o il primo della lista)
		local chosen = nil
		for _, d in data.dragons do
			if d.id == selected then
				chosen = d
			end
		end
		if not chosen then
			for _, d in data.dragons do
				if not chosen or table.find(data.equipped, d.id) then
					chosen = d
					if table.find(data.equipped, d.id) then
						break
					end
				end
			end
			selected = chosen and chosen.id
		end
		showDetail(data, chosen)
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if lastData then
			sizeGrid(if tab == "Nest" then 1.35 else 1.15)
		end
	end)
	return render
end

-- ogni secondo dal menu: aggiorna i timer; true se un uovo e' appena pronto (serve rifare la lista)
function DragonUI.tick(): boolean
	local now = os.time()
	local ready = false
	for _, t in timers do
		local left = math.max(0, t.readyAt - now)
		if left <= 0 and not t.hatch.Visible then
			ready = true
		end
		t.label.Text = if left <= 0 then "Ready!" else string.format("Ready in %d:%02d", left // 60, left % 60)
	end
	return ready
end

return DragonUI
