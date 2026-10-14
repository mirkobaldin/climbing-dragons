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
local GRADE_COLORS = { S = Color3.fromRGB(255, 215, 94), A = Color3.fromRGB(127, 224, 138), B = Color3.fromRGB(143, 200, 255), C = Color3.fromRGB(201, 201, 201) }
-- colori per rarita' (tessere e nome): grigio, blu, viola, oro
local RARITY_COLORS: { [string]: { Color3 } } = {
	Comune = { Color3.fromRGB(120, 130, 145), Color3.fromRGB(52, 58, 70) },
	Raro = { Color3.fromRGB(70, 150, 240), Color3.fromRGB(24, 52, 110) },
	Epico = { Color3.fromRGB(175, 90, 245), Color3.fromRGB(62, 24, 110) },
	Leggendario = { Color3.fromRGB(255, 190, 60), Color3.fromRGB(130, 64, 10) },
}
local PREVIEW_KIND = { "Dragons", "DragonsYoung", "DragonsAdult" }

local function preview(kind: string, element: string): Instance?
	local f = RS:FindFirstChild("Previews")
	local sub = f and f:FindFirstChild(kind)
	return sub and sub:FindFirstChild(element)
end

-- il drago nello stadio giusto (l'adulto ha il suo modello), visto di tre quarti dalla parte della
-- testa (ossa del collo: attributi Ruolo, DragonModels.markBones)
local function dragonView(parent: Instance, d: any, spin: boolean): ViewportFrame
	local stage = math.clamp(d.stage or 1, 1, 3)
	local object = preview(PREVIEW_KIND[stage], d.element) or preview("Dragons", d.element)
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(200, 200, 210)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	vf.LightDirection = Vector3.new(-0.5, -1, -0.7)
	vf.Parent = parent
	if not object then
		return vf
	end
	local clone = object:Clone() :: Model
	clone.Parent = vf
	local cf, size = clone:GetBoundingBox()
	local center = cf.Position
	local radius = size.Magnitude / 2
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
		local flat = Vector3.new((head :: Vector3).X - center.X, 0, (head :: Vector3).Z - center.Z)
		if flat.Magnitude > 0.1 then
			front = flat.Unit
		end
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = vf
	vf.CurrentCamera = camera
	local dist = radius / math.tan(math.rad(15)) * 0.78
	local function aim(a: number)
		local dir = (CFrame.fromAxisAngle(Vector3.yAxis, a) * front) + Vector3.new(0, 0.42, 0)
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

local function label(parent: Instance, str: string, size: number, color: Color3?, bold: boolean?, align: Enum.TextXAlignment?): TextLabel
	local l = Theme.label(parent, str, size, color, bold)
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Font = if bold then Enum.Font.GothamBlack else Enum.Font.GothamBold
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size
	c.MinTextSize = math.max(9, math.floor(size * 0.55))
	c.Parent = l
	return l
end

local function bar(parent: Instance, k: number, color: Color3): Frame
	local back = Theme.frame(parent, Color3.fromRGB(14, 16, 24), 0.1)
	Theme.corner(back, 6)
	local fill = Theme.frame(back, color, 0)
	fill.Size = UDim2.fromScale(math.clamp(k, 0, 1), 1)
	Theme.corner(fill, 6)
	return back
end

-- pulsante grande colorato (facile da premere col pollice)
local function bigButton(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0.4
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Parent = parent
	Theme.corner(b, 12)
	Theme.gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 185), 90)
	Theme.stroke(b, Color3.new(1, 1, 1), 2, 0.55)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 24
	c.MinTextSize = 12
	c.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	return b
end

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
	top.Size = UDim2.new(1, 0, 0, 44)
	local tabDragons = bigButton(top, "Dragons", Color3.fromRGB(150, 70, 220))
	tabDragons.Size = UDim2.new(0, 170, 1, 0)
	local tabNest = bigButton(top, "Nest", Color3.fromRGB(60, 70, 90))
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
	local gridBox = Theme.frame(body, Color3.fromRGB(10, 12, 20), 0.35)
	gridBox.Size = UDim2.new(0.6, -8, 1, 0)
	Theme.corner(gridBox, 12)
	local grid = Theme.scroll(gridBox)
	grid.Size = UDim2.new(1, -12, 1, -12)
	grid.Position = UDim2.fromOffset(6, 6)
	grid.ScrollBarThickness = 8
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.Parent = grid
	local detail = Theme.frame(body, Color3.fromRGB(16, 18, 30), 0.1)
	detail.AnchorPoint = Vector2.new(1, 0)
	detail.Position = UDim2.fromScale(1, 0)
	detail.Size = UDim2.new(0.4, 0, 1, 0)
	Theme.corner(detail, 12)
	Theme.stroke(detail, Color3.new(1, 1, 1), 2, 0.75)

	local tab = "Dragons"
	local autoTab = true -- finche' non scegli tu: uovo pronto (o nessun drago) -> Nest
	local selected: number? = nil
	local confirmSell: number? = nil
	local lastData: any = nil
	local render: () -> ()

	local function setTab(name: string)
		tab = name
		tabDragons.BackgroundColor3 = if name == "Dragons" then Color3.fromRGB(150, 70, 220) else Color3.fromRGB(60, 70, 90)
		tabNest.BackgroundColor3 = if name == "Nest" then Color3.fromRGB(230, 150, 40) else Color3.fromRGB(60, 70, 90)
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
		local width = math.max(grid.AbsoluteSize.X - 12, 160)
		local cols = math.clamp(math.floor(width / 128), 3, 5)
		local cell = (width - (cols - 1) * 8) / cols
		layout.CellSize = UDim2.fromOffset(cell, cell * aspect)
	end

	-- pannello di destra: il drago scelto
	local function showDetail(data: any, d: any?)
		for _, c in detail:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if not d then
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
		local name = label(detail, (if d.shiny then "✦ " else "") .. Names.dragon(d.element), 26, Color3.new(1, 1, 1), true)
		name.Position = UDim2.new(0, 14, 0, 8)
		name.Size = UDim2.new(1, -90, 0, 30)
		local rar = label(detail, Names.t(d.rarity) .. "  ·  " .. Names.t(stage.name), 17, colors[1], true)
		rar.Position = UDim2.new(0, 14, 0, 38)
		rar.Size = UDim2.new(1, -90, 0, 20)
		local ovr = label(detail, tostring(overall(d)), 34, GRADE_COLORS[grade], true, Enum.TextXAlignment.Right)
		ovr.AnchorPoint = Vector2.new(1, 0)
		ovr.Position = UDim2.new(1, -12, 0, 6)
		ovr.Size = UDim2.new(0, 70, 0, 38)
		local gr = label(detail, grade, 16, GRADE_COLORS[grade], true, Enum.TextXAlignment.Right)
		gr.AnchorPoint = Vector2.new(1, 0)
		gr.Position = UDim2.new(1, -12, 0, 42)
		gr.Size = UDim2.new(0, 70, 0, 18)
		-- palco col modello che gira
		local stageBox = Theme.frame(detail, colors[2], 0)
		stageBox.Position = UDim2.new(0, 10, 0, 64)
		stageBox.Size = UDim2.new(1, -20, 0.42, -20)
		Theme.corner(stageBox, 12)
		Theme.gradient(stageBox, colors[1], colors[2], 90)
		local vf = dragonView(stageBox, d, true)
		vf.Size = UDim2.fromScale(1, 1)
		-- livello ed esperienza
		local info = Theme.frame(detail, Color3.new(), 1)
		info.Position = UDim2.new(0, 14, 0.42, 50)
		info.Size = UDim2.new(1, -28, 0.58, -130)
		local lv = label(info, string.format("Lv. %d / %d", level, DragonConfig.MAX_LEVEL), 20, Color3.new(1, 1, 1), true)
		lv.Size = UDim2.new(0.5, 0, 0, 24)
		local state = label(info, if following then "Following you" else "Resting", 15, if following then Theme.GOOD else Theme.MUTED, true, Enum.TextXAlignment.Right)
		state.Position = UDim2.new(0.5, 0, 0, 2)
		state.Size = UDim2.new(0.5, 0, 0, 20)
		local xpBar = bar(info, level / DragonConfig.MAX_LEVEL, Theme.BLUE)
		xpBar.Position = UDim2.new(0, 0, 0, 28)
		xpBar.Size = UDim2.new(1, 0, 0, 10)
		-- tre righe: attacco, cosa fa in monta / come evolve
		local rows = {
			{ "Power", tostring(math.floor(DragonConfig.attack(d))) },
			{ "Coins/min at home", tostring((EconomyConfig.ROOST_RATE[d.rarity] or 1) * d.stage) },
		}
		if nextStage then
			local stones = data.stones or 0
			table.insert(rows, {
				"Evolve",
				if not maxed then string.format("reach Lv %d", DragonConfig.MAX_LEVEL)
					else string.format("%d / %d stones", math.min(stones, nextStage.stones), nextStage.stones),
			})
		else
			local el = UpgradeConfig.RIDE_ELEMENT[d.element]
			table.insert(rows, { "Ride attack", if el then el.text else "fire ball" })
		end
		for k, r in rows do
			local y = 46 + (k - 1) * 30
			local key = label(info, r[1], 15, Theme.MUTED, true)
			key.Position = UDim2.new(0, 0, 0, y)
			key.Size = UDim2.new(0.42, 0, 0, 24)
			local val = label(info, r[2], 16, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Right)
			val.Position = UDim2.new(0.42, 0, 0, y)
			val.Size = UDim2.new(0.58, 0, 0, 24)
		end
		-- pulsanti grandi in fondo
		local row = Theme.frame(detail, Color3.new(), 1)
		row.AnchorPoint = Vector2.new(0, 1)
		row.Position = UDim2.new(0, 10, 1, -10)
		row.Size = UDim2.new(1, -20, 0, 56)
		local follow = bigButton(row, if following then "Rest" else "Follow", if following then Color3.fromRGB(90, 100, 120) else Color3.fromRGB(60, 180, 80))
		follow.Activated:Connect(function()
			act(if following then "unequip" else "equip", d.id)
		end)
		local middle: TextButton
		if nextStage then
			local ready = maxed and (data.stones or 0) >= nextStage.stones
			middle = bigButton(row, "Evolve", if ready then Color3.fromRGB(170, 80, 240) else Color3.fromRGB(80, 70, 100))
			middle.Activated:Connect(function()
				act("evolve", d.id)
			end)
		else
			middle = bigButton(row, "Ride", Color3.fromRGB(50, 130, 230))
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
		local sell = bigButton(row, if confirmSell == d.id then "Sure?" else "Sell " .. price, Color3.fromRGB(215, 60, 55))
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
		tile.BackgroundColor3 = colors[1]
		tile.Parent = grid
		Theme.corner(tile, 12)
		Theme.gradient(tile, colors[1], colors[2], 90)
		local isSel = selected == d.id
		Theme.stroke(tile, if isSel then Color3.new(1, 1, 1) elseif following then Theme.GOOD else colors[1], if isSel then 4 else 2.5, 0)
		local vf = dragonView(tile, d, false)
		vf.Position = UDim2.fromScale(0.03, 0.04)
		vf.Size = UDim2.fromScale(0.94, 0.74)
		local lv = label(tile, "Lv " .. tostring(d.level or 1), 15, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Left)
		lv.Position = UDim2.new(0, 6, 1, -24)
		lv.Size = UDim2.new(0.6, 0, 0, 20)
		local stageTag = label(tile, ({ "Baby", "Young", "Adult" })[math.clamp(d.stage or 1, 1, 3)], 13, Color3.fromRGB(255, 235, 200), true, Enum.TextXAlignment.Right)
		stageTag.Position = UDim2.new(0.4, -6, 1, -24)
		stageTag.Size = UDim2.new(0.6, 0, 0, 20)
		if following then
			local tick = label(tile, "✓", 20, Theme.GOOD, true, Enum.TextXAlignment.Right)
			tick.Position = UDim2.new(1, -30, 0, 2)
			tick.Size = UDim2.fromOffset(26, 24)
		end
		if d.shiny then
			local sh = label(tile, "✦", 18, Color3.fromRGB(255, 230, 120), true)
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
		local tile = Theme.frame(grid, colors[1], 0)
		tile.LayoutOrder = index
		Theme.corner(tile, 12)
		Theme.gradient(tile, colors[1], colors[2], 90)
		local vf = Theme.viewport(tile, preview("Eggs", egg.element), UDim2.fromScale(0.8, 0.5), true)
		vf.Position = UDim2.fromScale(0.1, 0.04)
		local name = label(tile, Names.t(egg.element) .. " egg", 15, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
		name.Position = UDim2.fromScale(0.04, 0.55)
		name.Size = UDim2.fromScale(0.92, 0.13)
		local left = math.max(0, egg.readyAt - os.time())
		local time = label(tile, "", 14, Theme.ACCENT, true, Enum.TextXAlignment.Center)
		time.Position = UDim2.fromScale(0.04, 0.69)
		time.Size = UDim2.fromScale(0.92, 0.11)
		local hatch = bigButton(tile, "Hatch!", Color3.fromRGB(60, 180, 80))
		hatch.Position = UDim2.fromScale(0.08, 0.8)
		hatch.Size = UDim2.fromScale(0.84, 0.17)
		hatch.Visible = left <= 0
		time.Visible = left > 0
		time.Text = string.format("Ready in %d:%02d", left // 60, left % 60)
		table.insert(timers, { label = time, hatch = hatch, readyAt = egg.readyAt })
		hatch.Activated:Connect(function()
			act("hatch", index)
		end)
	end

	render = function()
		table.clear(timers)
		Ui.clear(grid)
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
			tabDragons.BackgroundColor3 = if tab == "Dragons" then Color3.fromRGB(150, 70, 220) else Color3.fromRGB(60, 70, 90)
			tabNest.BackgroundColor3 = if tab == "Nest" then Color3.fromRGB(230, 150, 40) else Color3.fromRGB(60, 70, 90)
		end
		counters.Text = string.format("💎 %d stones   ·   🐉 %d/%d following", data.stones or 0, #data.equipped, data.maxEquipped or 1)
		tabDragons.Text = string.format("Dragons %d", #data.dragons)
		tabNest.Text = string.format("Nest %d/%d", #data.nest, data.nestSlots or 0)
		if tab == "Nest" then
			sizeGrid(1.35)
			for index, egg in data.nest do
				eggTile(egg, index)
			end
			if #data.nest == 0 then
				local t = label(grid, if (data.nestSlots or 0) > 0 then "Find eggs and bring them to your nest" else "Buy the Tent to unlock the nest", 18, Theme.MUTED, true, Enum.TextXAlignment.Center)
				t.Size = UDim2.new(1, 0, 0, 60)
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
