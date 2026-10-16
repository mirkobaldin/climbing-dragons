--!strict
-- Crafting del menu unico, impaginato come il mockup scelto da Mirko il 15/10 (artifacts
-- ui-mockup "Crafting"): in alto i filtri (All, Equipment, Tools, Consumables, Materials), la
-- ricerca e l'ordinamento; a sinistra le carte (stato Owned / Craftable / Missing materials,
-- icona, nome, descrizione, materiali "ne hai / ne servono"); a destra la scheda dell'oggetto
-- scelto con i materiali che servono, quanti ne mancano, Craft e View materials.
-- Il server controlla tutto (Remotes.Craft, server/Progression).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Gear = require(Shared:WaitForChild("Gear"))
local Names = require(Shared:WaitForChild("Names"))
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local player = Players.LocalPlayer
local CraftingUI = {}

local FILTERS = { "All", "Equipment", "Tools", "Consumables", "Materials" }
local SORTS = { "Default", "Name", "Craftable first" }

-- quanti ne hai: minerali (Ores) o materiali dei nemici (Materiali)
function CraftingUI.count(name: string): number
	for _, folder in { "Ores", "Materiali" } do
		local f = player:FindFirstChild(folder)
		local v = f and f:FindFirstChild(name)
		if v and v:IsA("IntValue") then
			return v.Value
		end
	end
	return 0
end

function CraftingUI.itemName(name: string): string
	local icons = RS:FindFirstChild("DropIcone")
	local map = icons and icons:FindFirstChild("Nomi")
	local shown = map and map:GetAttribute(name)
	if type(shown) == "string" then
		return shown
	end
	local fixed = { Pelliccia_Yeti = "Yeti Fur", Cristallo_Ghiaccio = "Ice Crystal", Nucleo_Glaciale = "Glacial Core" }
	return fixed[name] or Names.t(name)
end

-- icona di un minerale o materiale (immagine caricata, o il modellino dei drop)
function CraftingUI.materialIcon(image: ImageLabel, name: string)
	if Gear.MONSTER_MATERIALS[name] then
		-- i drop dei nemici: il modellino di ReplicatedStorage.DropIcone (o il nome scritto)
		for _, child in image:GetChildren() do
			if child:IsA("ViewportFrame") or child.Name == "IconFallback" then
				child:Destroy()
			end
		end
		image.Image = ""
		local icons = RS:FindFirstChild("DropIcone")
		local model = icons and icons:FindFirstChild(name)
		if model then
			Theme.viewport(image, model, UDim2.fromScale(1, 1), false)
		else
			local l = Theme.label(image, CraftingUI.itemName(name), 12, Theme.TEXT, true)
			l.Name = "IconFallback"
			l.Size = UDim2.fromScale(1, 1)
			l.TextWrapped = true
			l.TextXAlignment = Enum.TextXAlignment.Center
		end
	else
		Theme.assetPreview(image, "ore_" .. name, Theme.oreModel(name))
	end
end

local function sortedCost(cost: { [string]: number }): { string }
	local list = {}
	for name in cost do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

local function recipeIcon(image: ImageLabel, recipe: Gear.Recipe)
	if recipe.gives then
		CraftingUI.materialIcon(image, recipe.id)
	else
		Theme.itemIcon(image, recipe.id, Theme.itemModel(if recipe.id == "Chiodi" then "Pitons" else recipe.id, Theme.ACCENT))
	end
end

-- ctx: { sub = function(text), open = function(page, filter) } dal menu (MainMenu)
function CraftingUI.mount(container: Frame, status: (string, boolean) -> (), ctx: any?): () -> ()
	local old = container:FindFirstChild("List")
	if old and old:IsA("GuiObject") then
		old.Visible = false -- la vecchia lista del modello in StarterGui
	end
	local root = Theme.frame(container, Color3.new(), 1)
	root.Name = "CraftingNuovo"
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = false

	local filter = "All"
	local sortMode = 1
	local query = ""
	local selected: string? = nil
	local render: () -> ()

	-- barra dei filtri
	local bar = Theme.frame(root, Color3.new(), 1)
	bar.Name = "Filtri"
	bar.Size = UDim2.new(1, 0, 0, 44)
	bar.ClipsDescendants = false
	local chips: { [string]: TextButton } = {}
	for i, f in FILTERS do
		local b = Instance.new("TextButton")
		b.Name = f
		b.Text = f
		b.LayoutOrder = i
		b.Parent = bar
		chips[f] = b
		b.Activated:Connect(function()
			filter = f
			render()
		end)
	end
	local search = Instance.new("TextBox")
	search.Name = "Cerca"
	search.PlaceholderText = "Search..."
	search.Text = ""
	search.ClearTextOnFocus = false
	UiKit.text(search, "body")
	search.TextColor3 = UiKit.TEXT
	search.PlaceholderColor3 = UiKit.DIM
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.BackgroundColor3 = UiKit.INK
	search.BackgroundTransparency = 0.35
	search.Parent = bar
	UiKit.edge(search, UiKit.LINE, 1, 0.7)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.Parent = search
	search:GetPropertyChangedSignal("Text"):Connect(function()
		query = string.lower(search.Text)
		render()
	end)
	local sortBtn = Instance.new("TextButton")
	sortBtn.Name = "Ordina"
	sortBtn.Text = "⇅"
	sortBtn.Parent = bar
	UiKit.button(sortBtn, "secondary")
	sortBtn.Text = "SORT"
	sortBtn.TextSize = 16
	sortBtn.Activated:Connect(function()
		sortMode = sortMode % #SORTS + 1
		status("Sorted by: " .. SORTS[sortMode], true)
		render()
	end)

	-- griglia delle carte
	local gridBox = Theme.frame(root, Color3.new(), 1)
	gridBox.Name = "Carte"
	gridBox.ClipsDescendants = true
	local list = Theme.scroll(gridBox)
	list.ScrollBarThickness = 6
	local lpad = Instance.new("UIPadding")
	lpad.PaddingTop, lpad.PaddingLeft, lpad.PaddingRight, lpad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 10), UDim.new(0, 16)
	lpad.Parent = list
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	-- scheda a destra
	local detail = Theme.frame(root, Theme.DARK, 1)
	detail.Name = "Scheda"
	UiKit.panel(detail, { transparency = 0.22 })
	local dIcon = Instance.new("ImageLabel")
	dIcon.BackgroundTransparency = 1
	dIcon.Position = UDim2.fromOffset(14, 14)
	dIcon.Size = UDim2.fromOffset(104, 104)
	dIcon.ZIndex = 3
	dIcon.Parent = detail
	local dTitle = UiKit.label(detail, "", "name", 26)
	dTitle.Position = UDim2.fromOffset(128, 18)
	dTitle.Size = UDim2.new(1, -140, 0, 34)
	dTitle.ZIndex = 3
	local dText = UiKit.label(detail, "", "body")
	dText.TextTruncate = Enum.TextTruncate.None
	dText.Position = UDim2.fromOffset(128, 56)
	dText.Size = UDim2.new(1, -140, 0, 62)
	dText.TextYAlignment = Enum.TextYAlignment.Top
	dText.TextWrapped = true
	dText.TextScaled = false
	dText.ZIndex = 3
	local line = UiKit.rule(detail, 128, 16)
	line.ZIndex = 3
	local need = UiKit.label(detail, "Required materials", "section")
	need.Position = UDim2.fromOffset(16, 138)
	need.Size = UDim2.new(1, -32, 0, 26)
	need.ZIndex = 3
	local rowsBox = Theme.scroll(detail)
	rowsBox.Position = UDim2.fromOffset(14, 170)
	rowsBox.Size = UDim2.new(1, -28, 1, -170 - 168)
	rowsBox.ZIndex = 3
	rowsBox.ScrollBarThickness = 4
	local rowsList = Theme.list(rowsBox, 6)
	rowsList.Name = "Righe"
	local alert = Instance.new("TextLabel")
	alert.Name = "Avviso"
	alert.AnchorPoint = Vector2.new(0, 1)
	alert.Position = UDim2.new(0, 14, 1, -114)
	alert.Size = UDim2.new(1, -28, 0, 44)
	UiKit.text(alert, "button", 18)
	alert.ZIndex = 3
	alert.Parent = detail
	local alertStroke = UiKit.edge(alert, UiKit.BAD, 1, 0.2)
	local craft = Instance.new("TextButton")
	craft.Name = "Crea"
	craft.AnchorPoint = Vector2.new(0, 1)
	craft.Position = UDim2.new(0, 14, 1, -60)
	craft.Size = UDim2.new(1, -28, 0, 48)
	craft.ZIndex = 3
	craft.Parent = detail
	local view = Instance.new("TextButton")
	view.Name = "VediMateriali"
	view.AnchorPoint = Vector2.new(0, 1)
	view.Position = UDim2.new(0, 14, 1, -12)
	view.Size = UDim2.new(1, -28, 0, 40)
	view.Text = "View materials"
	view.ZIndex = 3
	view.Parent = detail
	UiKit.button(view, "secondary")
	view.Activated:Connect(function()
		if ctx and ctx.open then
			ctx.open("Backpack", "Materials")
		end
	end)

	local function state(recipe: Gear.Recipe): (string, number, string?)
		-- "owned", "ready", "missing"; quanti ne mancano in tutto; il primo che manca
		if not recipe.consumable and Gear.has(player, recipe.id) then
			return "owned", 0, nil
		end
		local missing, first = 0, nil
		for _, name in sortedCost(recipe.cost) do
			local lack = recipe.cost[name] - CraftingUI.count(name)
			if lack > 0 then
				missing += lack
				first = first or name
			end
		end
		return if missing > 0 then "missing" else "ready", missing, first
	end

	local function find(id: string?): Gear.Recipe?
		return if id then Gear.find(id) else nil
	end

	local function showDetail()
		local recipe = find(selected)
		if not recipe then
			return
		end
		local r = recipe :: Gear.Recipe
		recipeIcon(dIcon, r)
		dTitle.Text = r.name
		dText.Text = r.description .. (if r.station == "Ovunque" then "" else "\n<font color=\"#8fd3ff\">Crafted at a Workbench</font>")
		for _, c in rowsBox:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, name in sortedCost(r.cost) do
			local have, want = CraftingUI.count(name), r.cost[name]
			local enough = have >= want
			local row = Theme.frame(rowsBox, UiKit.RAISED, 0.3)
			row.LayoutOrder = i
			row.Size = UDim2.new(1, 0, 0, if UiKit.compact then 36 else 42)
			row.ZIndex = 3
			local flag = Theme.frame(row, if enough then UiKit.GOOD else UiKit.BAD, 0)
			flag.Size = UDim2.new(0, 3, 1, 0)
			flag.ZIndex = 4
			local ic = Instance.new("ImageLabel")
			ic.BackgroundTransparency = 1
			ic.Position = UDim2.fromOffset(8, 4)
			ic.Size = UDim2.fromOffset(34, 34)
			ic.ZIndex = 4
			ic.Parent = row
			CraftingUI.materialIcon(ic, name)
			local n = UiKit.label(row, CraftingUI.itemName(name), "name", 17)
			n.Position = UDim2.fromOffset(50, 0)
			n.Size = UDim2.new(0.42, -50, 1, 0)
			n.ZIndex = 4
			local ok = have >= want
			local q = UiKit.label(row, string.format("%s %d / %d", if ok then "✔" else "✖", have, want), "stat", 17)
			q.TextColor3 = if ok then UiKit.GOOD else UiKit.BAD
			q.Position = UDim2.new(0.42, 0, 0, 0)
			q.Size = UDim2.new(0.22, 0, 1, 0)
			q.ZIndex = 4
			if not ok then
				local m = UiKit.label(row, string.format("Need %d more", want - have), "status")
				m.TextColor3 = UiKit.BAD
				m.TextXAlignment = Enum.TextXAlignment.Right
				m.Position = UDim2.new(0.64, 0, 0, 0)
				m.Size = UDim2.new(0.36, -8, 1, 0)
				m.ZIndex = 4
			end
		end
		local st, missing, first = state(r)
		if st == "owned" then
			alert.Text = "YOU OWN THIS"
			alert.BackgroundColor3 = Color3.fromRGB(18, 52, 30)
			alert.TextColor3 = UiKit.GOOD
			alertStroke.Color = UiKit.GOOD
		elseif st == "ready" then
			alert.Text = "READY TO CRAFT"
			alert.BackgroundColor3 = Color3.fromRGB(18, 52, 30)
			alert.TextColor3 = UiKit.GOOD
			alertStroke.Color = UiKit.GOOD
		else
			local lack = r.cost[first :: string] - CraftingUI.count(first :: string)
			alert.Text = string.upper(string.format("Missing %d %s%s", lack, CraftingUI.itemName(first :: string),
				if missing > lack then string.format("  (+%d more)", missing - lack) else ""))
			alert.BackgroundColor3 = Color3.fromRGB(70, 18, 26)
			alert.TextColor3 = Color3.fromRGB(255, 170, 176)
			alertStroke.Color = UiKit.BAD
		end
		alert.BackgroundTransparency = 0.15
		local short = string.lower((string.gsub(r.name, "%s*%b()", "")))
		local words = string.split(short, " ")
		craft.Text = if st == "owned" then "Owned" else "Craft " .. words[#words]
		local can = st == "ready"
		UiKit.button(craft, if can then "primary" else "disabled")
	end

	craft.Activated:Connect(function()
		local recipe = find(selected)
		if not recipe then
			return
		end
		local st = state(recipe :: Gear.Recipe)
		if st ~= "ready" then
			status(if st == "owned" then "You already have it" else "You're missing materials", false)
			return
		end
		local ok, message = (RS.Remotes:WaitForChild("Craft") :: RemoteFunction):InvokeServer((recipe :: Gear.Recipe).id)
		status(message or "", ok)
		render()
	end)

	local function card(recipe: Gear.Recipe, order: number)
		local st, _, _ = state(recipe)
		local c = Instance.new("TextButton")
		c.Name = recipe.id
		c.Text = ""
		c.AutoButtonColor = false
		c.LayoutOrder = order
		c:SetAttribute("UiNative", true)
		c.Parent = list
		local on = recipe.id == selected
		UiKit.card(c, on)
		c.Activated:Connect(function()
			selected = recipe.id
			render()
		end)
		-- TELEFONO in orizzontale: carta bassa, icona a sinistra, nome e stato, materiali sotto
		-- (le carte alte 244 non ci stavano nemmeno una per volta in 245 px di lista)
		if grid.CellSize.Y.Offset < 150 then
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.Position = UDim2.fromOffset(6, 6)
			icon.Size = UDim2.fromOffset(54, 54)
			icon.ZIndex = 3
			icon.Parent = c
			recipeIcon(icon, recipe)
			local title = UiKit.label(c, recipe.name, "name", 16)
			title.Position = UDim2.fromOffset(66, 4)
			title.Size = UDim2.new(1, -72, 0, 22)
			title.ZIndex = 3
			-- stato scritto (non solo il colore): segno + parola
			local tag = UiKit.label(c, if st == "owned" then "✔ OWNED" elseif st == "ready" then "◆ CRAFTABLE" else "✖ MISSING MATERIALS", "status", 12)
			tag.TextColor3 = if st == "owned" then UiKit.GOOD elseif st == "ready" then UiKit.ICE else Color3.fromRGB(255, 150, 158)
			tag.Position = UDim2.fromOffset(66, 26)
			tag.Size = UDim2.new(1, -72, 0, 16)
			tag.ZIndex = 3
			local names = sortedCost(recipe.cost)
			local row = Theme.frame(c, Color3.new(), 1)
			row.AnchorPoint = Vector2.new(0, 1)
			row.Position = UDim2.new(0, 6, 1, -6)
			row.Size = UDim2.new(1, -12, 0, 28)
			row.ZIndex = 3
			local rl = Theme.list(row, 4, true)
			rl.HorizontalAlignment = Enum.HorizontalAlignment.Left
			for i, name in names do
				local have, want = CraftingUI.count(name), recipe.cost[name]
				local chip = Theme.frame(row, UiKit.INK, 0.3)
				chip.LayoutOrder = i
				chip.Size = UDim2.new(1 / math.max(#names, 3), -4, 1, 0)
				chip.ZIndex = 3
				local cflag = Theme.frame(chip, if have >= want then UiKit.GOOD else UiKit.BAD, 0)
				cflag.AnchorPoint = Vector2.new(0, 1)
				cflag.Position = UDim2.fromScale(0, 1)
				cflag.Size = UDim2.new(1, 0, 0, 2)
				cflag.ZIndex = 4
				local ic = Instance.new("ImageLabel")
				ic.BackgroundTransparency = 1
				ic.Position = UDim2.fromOffset(2, 3)
				ic.Size = UDim2.fromOffset(20, 20)
				ic.ZIndex = 4
				ic.Parent = chip
				CraftingUI.materialIcon(ic, name)
				local q = UiKit.label(chip, string.format("%d/%d", have, want), "stat", 13)
				q.TextColor3 = if have >= want then UiKit.GOOD else UiKit.BAD
				q.TextTruncate = Enum.TextTruncate.None
				q.Position = UDim2.fromOffset(24, 0)
				q.Size = UDim2.new(1, -24, 1, 0)
				q.ZIndex = 4
			end
			return
		end
		-- carte strette (telefono): icona e testi piu' piccoli
		local small = grid.CellSize.X.Offset < 200
		-- stato in alto a destra
		if st ~= "missing" then
			local badge = Instance.new("TextLabel")
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, -8, 0, 8)
			badge.Size = UDim2.fromOffset(if st == "owned" then 64 else 82, 22)
			badge.Text = if st == "owned" then "Owned" else "Craftable"
			UiKit.text(badge, "status")
			badge.TextColor3 = if st == "owned" then UiKit.GOOD else UiKit.ICE
			badge.BackgroundColor3 = UiKit.INK
			badge.BackgroundTransparency = 0.25
			badge.ZIndex = 4
			badge.Parent = c
			UiKit.edge(badge, badge.TextColor3, 1, 0.3)
		end
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, if small then 26 else 14)
		icon.Size = if small then UDim2.fromOffset(72, 72) else UDim2.fromOffset(92, 92)
		icon.ZIndex = 3
		icon.Parent = c
		recipeIcon(icon, recipe)
		local title = UiKit.label(c, recipe.name, "name", if small then 17 else 19)
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.Position = UDim2.fromOffset(8, 106)
		title.Size = UDim2.new(1, -16, 0, 24)
		title.ZIndex = 3
		local desc = UiKit.label(c, recipe.description, "secondary")
		desc.TextXAlignment = Enum.TextXAlignment.Center
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextTruncate = Enum.TextTruncate.AtEnd
		desc.TextWrapped = true
		desc.Position = UDim2.fromOffset(10, 134)
		desc.Size = UDim2.new(1, -20, 0, 48)
		desc.ZIndex = 3
		if st == "missing" then
			local miss = Instance.new("TextLabel")
			miss.AnchorPoint = Vector2.new(0.5, 1)
			miss.Position = UDim2.new(0.5, 0, 1, -46)
			miss.Size = UDim2.new(1, -20, 0, 20)
			miss.Text = "Missing materials"
			UiKit.text(miss, "status")
			miss.TextColor3 = Color3.fromRGB(255, 150, 158)
			miss.BackgroundColor3 = Color3.fromRGB(70, 18, 26)
			miss.BackgroundTransparency = 0.2
			miss.ZIndex = 4
			miss.Parent = c
		end
		-- materiali in fila in fondo: icona e "ne hai/ne servono"
		local names = sortedCost(recipe.cost)
		local row = Theme.frame(c, Color3.new(), 1)
		row.AnchorPoint = Vector2.new(0.5, 1)
		row.Position = UDim2.new(0.5, 0, 1, -8)
		row.Size = UDim2.new(1, -14, 0, 34)
		row.ZIndex = 3
		local rl = Theme.list(row, 4, true)
		rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		for i, name in names do
			local have, want = CraftingUI.count(name), recipe.cost[name]
			local chip = Theme.frame(row, UiKit.INK, 0.3)
			chip.LayoutOrder = i
			chip.Size = UDim2.new(1 / #names, -4, 1, 0)
			chip.ZIndex = 3
			local enoughChip = have >= want
			local cflag = Theme.frame(chip, if enoughChip then UiKit.GOOD else UiKit.BAD, 0)
			cflag.AnchorPoint = Vector2.new(0, 1)
			cflag.Position = UDim2.fromScale(0, 1)
			cflag.Size = UDim2.new(1, 0, 0, 2)
			cflag.ZIndex = 4
			local ic = Instance.new("ImageLabel")
			ic.BackgroundTransparency = 1
			ic.Position = UDim2.fromOffset(2, 5)
			ic.Size = if #names >= 3 then UDim2.fromOffset(20, 20) else UDim2.fromOffset(26, 26)
			ic.ZIndex = 4
			ic.Parent = chip
			CraftingUI.materialIcon(ic, name)
			local q = UiKit.label(chip, string.format("%d/%d", have, want), "stat", if #names >= 3 then 12 else 14)
			q.TextColor3 = if have >= want then UiKit.GOOD else UiKit.BAD
			q.TextTruncate = Enum.TextTruncate.None
			q.Position = UDim2.fromOffset(if #names >= 3 then 22 else 28, 0)
			q.Size = UDim2.new(1, if #names >= 3 then -22 else -30, 1, 0)
			q.ZIndex = 4
		end
	end

	local function layout()
		local gui = container:FindFirstAncestorWhichIsA("ScreenGui")
		local su = gui and gui:FindFirstChild("ScalaUI") :: UIScale?
		local k = if su and su.Scale > 0 then su.Scale else 1
		local w = root.AbsoluteSize.X / k
		if w < 50 then
			return
		end
		local narrow = w < 760
		local low = root.AbsoluteSize.Y / k < 420 -- telefono in orizzontale
		-- pagina stretta (telefono piccolo in verticale): la scheda va SOTTO la griglia
		local stacked = w < 600
		-- filtri: chip larghe quanto il testo, ricerca e ordina a destra
		local x = 0
		local barH = if low then 34 else 40
		local top = barH + (if low then 8 else 14)
		bar.Size = UDim2.new(1, 0, 0, barH + 4)
		local chipW = if stacked then math.max(58, math.floor((w - 74 - 4 * 8) / 5)) elseif low then 92 elseif narrow then 92 else 128
		for _, f in FILTERS do
			local b = chips[f]
			b.Position = UDim2.fromOffset(x, 2)
			b.Size = UDim2.fromOffset(chipW, barH)
			x += chipW + (if low then 6 else 8)
		end
		local searchW = math.max(120, math.min(300, w - x - 82))
		search.Visible = w - x > 180
		search.AnchorPoint = Vector2.new(1, 0)
		search.Position = UDim2.new(1, -74, 0, 2)
		search.Size = UDim2.fromOffset(searchW, barH)
		sortBtn.AnchorPoint = Vector2.new(1, 0)
		sortBtn.Position = UDim2.new(1, 0, 0, 2)
		sortBtn.Size = UDim2.fromOffset(66, barH)
		-- telefono: ricette 58%, scheda 42% (riferimento di Mirko 16/10)
		local detailW = if stacked then w elseif low then math.floor(w * 0.42) else math.clamp(math.floor(w * 0.34), 250, 400)
		local gridH = 268
		local detailH = 360
		if stacked then
			gridBox.Position = UDim2.fromOffset(0, top)
			gridBox.Size = UDim2.new(1, 0, 0, gridH)
			detail.Position = UDim2.fromOffset(0, top + gridH + 10)
			detail.Size = UDim2.new(1, 0, 0, detailH)
		else
			gridBox.Position = UDim2.fromOffset(0, top)
			gridBox.Size = UDim2.new(1, -(detailW + 12), 1, -top)
			detail.Position = UDim2.new(1, -detailW, 0, top)
			detail.Size = UDim2.new(0, detailW, 1, -top)
		end
		local wantH = if stacked then top + gridH + 10 + detailH else 0
		if container:GetAttribute("AltezzaMinima") ~= wantH then
			container:SetAttribute("AltezzaMinima", wantH)
			if ctx and ctx.fit then
				task.defer(ctx.fit)
			end
		end
		-- scheda: su schermi bassi icona e pulsanti piu' piccoli, cosi' si vedono tutti i materiali
		local dh = if stacked then detailH else root.AbsoluteSize.Y / k - top
		local small = dh < 520
		local ic = if low then 52 elseif small then 76 else 104
		dIcon.Position = UDim2.fromOffset(if low then 8 else 14, if low then 8 else 14)
		dIcon.Size = UDim2.fromOffset(ic, ic)
		dTitle.TextSize = if low then 20 else 26
		dTitle.Position = UDim2.fromOffset(ic + (if low then 16 else 24), if low then 6 else if small then 10 else 18)
		dTitle.Size = UDim2.new(1, -(ic + 28), 0, if low then 24 else 34)
		dText.TextSize = if low then 13 else 16
		dText.Position = UDim2.fromOffset(ic + (if low then 16 else 24), if low then 30 else if small then 44 else 56)
		dText.Size = UDim2.new(1, -(ic + 28), 0, if low then 34 else if small then 46 else 62)
		local lineY = ic + (if low then 12 else 22)
		line.Position = UDim2.fromOffset(16, lineY)
		need.Visible = not low
		need.Position = UDim2.fromOffset(16, lineY + 8)
		-- PIEDE FISSO: stato, Craft e View materials sempre dentro la scheda; sul telefono Craft e
		-- View stanno affiancati (Mirko 16/10: il pulsante di creazione spariva)
		local alertH, craftH, viewH = if low then 28 elseif small then 36 else 44, if low then 40 elseif small then 42 else 48, if small then 34 else 40
		local bottom
		if low then
			craft.AnchorPoint = Vector2.new(0, 1)
			craft.Position = UDim2.new(0, 8, 1, -8)
			craft.Size = UDim2.new(0.62, -12, 0, craftH)
			view.AnchorPoint = Vector2.new(1, 1)
			view.Position = UDim2.new(1, -8, 1, -8)
			view.Size = UDim2.new(0.38, -4, 0, craftH)
			view.Text = "MATERIALS"
			alert.Size = UDim2.new(1, -16, 0, alertH)
			alert.Position = UDim2.new(0, 8, 1, -(8 + craftH + 6))
			bottom = 8 + craftH + 6 + alertH + 6
		else
			craft.AnchorPoint = Vector2.new(0, 1)
			view.AnchorPoint = Vector2.new(0, 1)
			view.Position = UDim2.new(0, 14, 1, -12)
			view.Size = UDim2.new(1, -28, 0, viewH)
			view.Text = "VIEW MATERIALS"
			craft.Size = UDim2.new(1, -28, 0, craftH)
			craft.Position = UDim2.new(0, 14, 1, -(12 + viewH + 8))
			alert.Size = UDim2.new(1, -28, 0, alertH)
			alert.Position = UDim2.new(0, 14, 1, -(12 + viewH + 8 + craftH + 8))
			bottom = 12 + viewH + 8 + craftH + 8 + alertH + 8
		end
		alert.TextSize = if low then 14 else 18
		local rowsTop = lineY + (if low then 8 else 40)
		rowsBox.Position = UDim2.fromOffset(if low then 8 else 14, rowsTop)
		rowsBox.Size = UDim2.new(1, if low then -16 else -28, 1, -(rowsTop + bottom))
		local gw = if stacked then w - 18 else w - detailW - 12 - 18
		-- telefono: due colonne di carte strette invece di una sola carta enorme
		local cols = math.clamp(math.floor(gw / 165), 1, 4)
		local cellW = math.floor((gw - (cols - 1) * 12) / cols)
		grid.CellSize = UDim2.fromOffset(cellW, if low then 100 elseif cellW < 200 then 244 else 260)
		grid.CellPadding = UDim2.fromOffset(if low then 8 else 12, if low then 8 else 12)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	render = function()
		layout() -- misure delle carte prima di crearle
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for f, b in chips do
			UiKit.tab(b, f == filter)
			b.TextSize = if UiKit.compact then 14 else 17
		end
		local shown: { Gear.Recipe } = {}
		for _, r in Gear.RECIPES do
			if (filter == "All" or r.category == filter) and (query == "" or string.find(string.lower(r.name), query, 1, true)) then
				table.insert(shown, r)
			end
		end
		local base: { [string]: number } = {}
		for i, r in Gear.RECIPES do
			base[r.id] = i
		end
		table.sort(shown, function(a, b)
			if sortMode == 2 then
				return a.name < b.name
			elseif sortMode == 3 then
				local rank = { ready = 1, missing = 2, owned = 3 }
				local ra, rb = rank[(state(a))], rank[(state(b))]
				if ra ~= rb then
					return ra < rb
				end
			end
			return base[a.id] < base[b.id]
		end)
		if not find(selected) or not table.find(shown, find(selected) :: Gear.Recipe) then
			selected = if shown[1] then shown[1].id else selected
		end
		for i, r in shown do
			card(r, i)
		end
		if ctx and ctx.sub then
			ctx.sub(string.format("%d items", #shown))
		end
		showDetail()
		layout()
	end
	return render
end

return CraftingUI
