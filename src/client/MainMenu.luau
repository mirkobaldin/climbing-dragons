--!strict
-- Controller del menu: struttura e carte provengono dai modelli StarterGui.
local CAS = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Shared = RS:WaitForChild("Shared")
local DragonConfig = require(Shared:WaitForChild("DragonConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Names = require(Shared:WaitForChild("Names"))
local Gear = require(Shared:WaitForChild("Gear"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local Ui = require(Shared:WaitForChild("UiView"))
local Theme = require(script.Parent.Theme)
local CraftingUI = require(script.Parent.CraftingUI)
local DragonUI = require(script.Parent.DragonUI)
local UpgradeUI = require(script.Parent.UpgradeUI)
local player = Players.LocalPlayer
local remotes = RS:WaitForChild("Remotes")
local MainMenu = {}
local ORES = { "Carbone", "Ferro", "Oro", "Cristallo", "Rubino", "Cosmico" }

local function oreCount(ore: string): number
	local f = player:FindFirstChild("Ores")
	local v = f and f:FindFirstChild(ore)
	return if v and v:IsA("IntValue") then v.Value else 0
end
local function preview(kind: string, element: string): Instance?
	local f = RS:FindFirstChild("Previews")
	local sub = f and f:FindFirstChild(kind)
	return sub and sub:FindFirstChild(element)
end
-- lista a righe: schede alte in pixel (UiView), spazio in fondo per arrivare all'ultima
local function rows(list: ScrollingFrame)
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Parent = list
	end
	local l = layout :: UIListLayout
	l.Padding = UDim.new(0, 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ElasticBehavior = Enum.ElasticBehavior.Always
	if not list:FindFirstChild("Margine") then
		local pad = Instance.new("UIPadding")
		pad.Name = "Margine"
		pad.PaddingTop = UDim.new(0, 2)
		pad.PaddingBottom = UDim.new(0, 24)
		pad.PaddingRight = UDim.new(0, 4)
		pad.Parent = list
	end
end
-- riquadro a tessere dentro una lista (zaino): griglia a celle fisse, alta quanto serve
local function tiles(parent: Instance, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Tessere"
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, -12, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = order
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(136, 148)
	g.CellPadding = UDim2.fromOffset(10, 10)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	f.Parent = parent
	return f
end
local function mountShop(container: Frame, status: (string, boolean) -> ()): () -> ()
	local list = Ui.node(container, "List")
	rows(list)
	local sub = "Buy"
	local render: () -> ()
	local function call(action: string, id: string?, amount: any?)
		local ok, message = (remotes:WaitForChild("Shop") :: RemoteFunction):InvokeServer(action, id, amount)
		status(message or "", ok)
		render()
	end
	local function card(order: number): any
		local c = Ui.template("ItemCard", list)
		c.LayoutOrder = order
		c.SellActions.Visible, c.Buy.Visible = false, false
		c.Coin.Visible = false
		return c
	end
	render = function()
		Ui.clear(list)
		for _, name in { "Buy", "Sell", "Robux" } do
			Ui.selected(Ui.node(container, "Tabs/" .. name), name == sub, Theme.ACCENT, Theme.CARD)
		end
		if sub == "Buy" then
			for k, item in ShopConfig.ITEMS do
				local c = card(k)
				local egg = item.id == "MysteryEgg" or item.id == "RareEgg"
				Theme.itemIcon(c.Icon, item.id, if egg then preview("Eggs", "Cosmico") else Theme.itemModel(item.id, item.color))
				c.Title.Text, c.Description.Text = item.name, item.description
				c.Cost.Text = string.format("%d coins", item.price)
				Ui.asset(c.Coin, "icon_coin")
				c.Buy.Visible = true
				c.Buy.Activated:Connect(function()
					call("buy", item.id)
				end)
			end
		elseif sub == "Sell" then
			for k, ore in ORES do
				local c = card(k)
				Theme.assetPreview(c.Icon, "ore_" .. ore, Theme.oreModel(ore))
				c.Title.Text = string.format("%s  x%d", Names.t(ore), oreCount(ore))
				c.Cost.Text = string.format("%d coins each", EconomyConfig.ORE_PRICES[ore] or 1)
				Ui.asset(c.Coin, "icon_coin")
				c.SellActions.Visible = true
				c.SellActions.One.Activated:Connect(function()
					call("sellOre", ore, 1)
				end)
				c.SellActions.All.Activated:Connect(function()
					call("sellOre", ore, "all")
				end)
			end
			local c = card(99)
			local raw = player:GetAttribute("CarryingEgg")
			local element, rarity = "", ""
			if type(raw) == "string" then
				local a, b = string.match(raw, "^(.-)|(.*)$")
				element, rarity = a or "", b or ""
			end
			Theme.assetPreview(c.Icon, "icon_egg", preview("Eggs", element))
			c.Title.Text = if element ~= "" then Names.t(rarity) .. " " .. Names.t(element) .. " Egg" else "Carried egg"
			c.Description.Text = if rarity ~= ""
				then string.format("%d coins", EconomyConfig.EGG_PRICES[rarity] or 10)
				else "Bring an egg here to sell it"
			c.Buy.Visible, c.Buy.Text = element ~= "", "Sell egg"
			c.Buy.Activated:Connect(function()
				call("sellEgg")
			end)
		else
			local entries = {
				{ "EggFinder", "Egg Finder", "Compass to the nearest egg", "pass_" },
				{ "FastIncubation", "Fast Incubation x2", "Eggs hatch in half the time", "pass_" },
				{ "ExtraDragon", "+1 Dragon Follower", "Bring two dragons with you", "pass_" },
				{ "ExtraIncubator", "Big Nest", "+2 nest slots", "pass_" },
				{ "Revive", "Mountain Rescue", "Respawn where you fell", "prod_" },
				{ "InstantHatch", "Instant Hatch", "Every egg in your nest ready now", "prod_" },
				{ "Coins1000", "1000 Coins", "A boost for your house", "prod_" },
				{ "TrainingX2", "Training XP x2", "Double training XP, forever", "pass_" },
				{ "TrainingBoost", "Training Boost x3", "Triple training XP for 15 minutes", "prod_" },
			}
			for k, e in entries do
				local c = card(k)
				Ui.asset(c.Icon, e[4] .. e[1])
				c.Title.Text, c.Description.Text = e[2], e[3]
				local owned = player:GetAttribute("Pass_" .. e[1]) == true
				local available = (DragonConfig.GAMEPASSES[e[1]] or ShopConfig.DEV_PRODUCTS[e[1]] or 0) > 0
				c.Buy.Visible = true
				c.Buy.Text = if owned then "Owned" elseif available then "Buy (Robux)" else "Coming soon"
				c.Buy.Activated:Connect(function()
					if not owned and available then
						call("robux", e[1])
					end
				end)
			end
		end
	end
	for _, name in { "Buy", "Sell", "Robux" } do
		Ui.node(container, "Tabs/" .. name).Activated:Connect(function()
			sub = name
			render()
		end)
	end
	return render
end
local function mountInventory(container: Frame): () -> ()
	local list = Ui.node(container, "List")
	rows(list)
	return function()
		Ui.clear(list)
		local summary = Ui.template("TextCard", list)
		summary.LayoutOrder = 0
		local grid = tiles(list, 1)
		local house = EconomyConfig.HOUSES[(player:GetAttribute("HouseLevel") or 0) :: number]
		summary.Text.Text = string.format(
			"%d coins\nHouse: %s\nDragons at home: %d coins/min\nPitons: %d · Warmth: %d%%",
			player:GetAttribute("Coins") or 0,
			if house then Names.t(house.name) else "none (buy the Tent on your plot)",
			player:GetAttribute("RoostRate") or 0,
			player:GetAttribute("Pitons") or 0,
			math.floor((player:GetAttribute("Warmth") or 100) :: number)
		)
		local order = 0
		local function item(title: string, count: string, asset: string, model: Instance?, id: string?): any
			order += 1
			local c = Ui.template("InventoryCard", grid)
			c.LayoutOrder = order
			c.Title.Text, c.Count.Text = title, count
			if asset == "" and Theme.ITEM_ICONS[id or ""] then
				Theme.itemIcon(c.Icon, id :: string, model)
			else
				Theme.assetPreview(c.Icon, asset, model)
			end
			return c
		end
		for _, ore in ORES do
			item(Names.t(ore), "x" .. oreCount(ore), "ore_" .. ore, Theme.oreModel(ore))
		end
		local mats = player:FindFirstChild("Materiali")
		local icons = RS:FindFirstChild("DropIcone")
		local names = icons and icons:FindFirstChild("Nomi")
		local drops = if mats then mats:GetChildren() else {}
		table.sort(drops, function(a, b)
			return a.Name < b.Name
		end)
		for _, v in drops do
			if v:IsA("IntValue") and v.Value > 0 then
				local shown = names and names:GetAttribute(v.Name)
				item(
					if type(shown) == "string" then shown else Names.t(v.Name),
					"x" .. v.Value,
					"",
					icons and icons:FindFirstChild(v.Name)
				)
			end
		end
		for _, recipe in Gear.RECIPES do
			local owned = Gear.has(player, recipe.id)
			local c = item(
				recipe.name,
				if owned then "Owned" else "",
				"",
				Theme.itemModel(if recipe.id == "Chiodi" then "Pitons" else recipe.id, Theme.ACCENT),
				recipe.id
			)
			-- attrezzi che non hai ancora: sbiaditi (si fanno al banco, scheda Crafting)
			c.Count.TextColor3 = Theme.GOOD
			c.Icon.ImageTransparency = if owned then 0 else 0.6
			c.Title.TextTransparency = if owned then 0 else 0.4
		end
	end
end
-- colori delle schede del menu (pulsanti della colonna e sfondo della finestra)
local MENU_COLORS: { [string]: Color3 } = {
	Store = Color3.fromRGB(230, 170, 40),
	Backpack = Color3.fromRGB(205, 110, 50),
	Dragons = Color3.fromRGB(150, 70, 220),
	Crafting = Color3.fromRGB(215, 65, 55),
	Upgrades = Color3.fromRGB(60, 175, 90),
	Teleport = Color3.fromRGB(40, 170, 220),
}

function MainMenu.start()
	local gui = Ui.screen("MainMenu")
	local column, window = Ui.node(gui, "Column"), Ui.node(gui, "Window")
	-- colonna del menu: pulsanti tondi a icona (prima pillole lunghe in una lista a scorrimento)
	column.ScrollingEnabled = false
	column.ScrollBarThickness = 0
	-- griglia: una colonna se c'e' spazio, altrimenti due o tre (schermi bassi)
	local list = column:FindFirstChildOfClass("UIListLayout")
	if list then
		list:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(78, 78)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.Parent = column
	for k, n in { "Store", "Backpack", "Dragons", "Crafting", "Upgrades", "Teleport" } do
		column[n].LayoutOrder = k
	end
	-- Hide/Show: fuori dalla griglia, sopra le icone (sul telefono a sinistra della fila)
	local toggle = column.NascondiIcone
	toggle.Parent = gui
	toggle.Visible = true
	Ui.text(toggle, 16, true)
	toggle.TextColor3 = Color3.fromRGB(240, 240, 242)
	if not column.Teleport:FindFirstChild("Icon") then
		local icon = column.Store.Icon:Clone()
		icon.Parent = column.Teleport
		Ui.asset(icon, "icon_teleport")
	end
	for _, n in { "Store", "Backpack", "Dragons", "Crafting", "Upgrades", "Teleport" } do
		local btn = column[n]
		btn:SetAttribute("UiAsset", "btn_round_normal")
		Ui.skin(btn, "btn_round_normal")
		-- un colore per pulsante: prima erano tutti blu scuro uguali
		Ui.tint(btn, MENU_COLORS[n], true)
		btn.TextSize = 12
		btn.TextScaled = false
		btn.Size = UDim2.fromOffset(78, 78)
		local icon = btn:FindFirstChild("Icon")
		if icon then
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.fromScale(0.5, 0.12)
			icon.Size = UDim2.fromScale(0.56, 0.56)
			icon.ZIndex = 3
		end
		local caption = btn:FindFirstChild("AssetCaption")
		if caption then
			-- scritta piu' grande e un po' piu' larga del pulsante (si rimpicciolisce se non ci sta):
			-- "Crafting (N)" a 13 px era illeggibile
			caption.Position = UDim2.fromScale(-0.04, 0.7)
			caption.Size = UDim2.fromScale(1.08, 0.28)
			caption.TextScaled = true
			local fit = caption:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
			fit.MaxTextSize = 14
			fit.MinTextSize = 10
			fit.Parent = caption
			caption.TextStrokeTransparency = 0.3
			caption.Font = Enum.Font.GothamBlack
			caption.TextXAlignment = Enum.TextXAlignment.Center
			caption.ZIndex = 4
		end
	end
	column.Teleport.Text = if UIS.TouchEnabled then "Travel" else "Travel (T)"
	local content = window.Content
	-- la finestra sopra l'HUD (prima il meteo le restava disegnato sopra)
	local hudGui = player.PlayerGui:FindFirstChild("ClimbHUD")
	if hudGui and hudGui:IsA("ScreenGui") then
		gui.DisplayOrder = math.max(gui.DisplayOrder, hudGui.DisplayOrder + 1)
	end
	-- impaginazione interna in pixel: titolo, chiusura, contenuto, stato
	Ui.px(window.Title, 0.5, 0, 0, 12, 420, 46, 0.5, 0)
	window.Title.TextXAlignment = Enum.TextXAlignment.Center
	Ui.px(window.Close, 1, -12, 0, 10, 50, 50, 1, 0)
	local closeLimit = window.Close:FindFirstChild("SizeLimit")
	if closeLimit then
		closeLimit:Destroy()
	end
	Ui.px(window.Status, 0, 18, 1, -8, 600, 28, 0, 1)
	window.Status.Size = UDim2.new(1, -36, 0, 28)
	Ui.text(window.Status, 15, true)
	content.Position = UDim2.fromOffset(18, 70)
	content.Size = UDim2.new(1, -36, 1, -110)
	local windowLimit = window:FindFirstChild("SizeLimit")
	if windowLimit then
		windowLimit:Destroy()
	end
	for _, tabbed in { content.Store, content.Upgrades } do
		tabbed.Tabs.Size = UDim2.new(1, 0, 0, 44)
		for _, b in tabbed.Tabs:GetChildren() do
			if b:IsA("GuiObject") then
				b.Size = UDim2.new(1 / 3, -8, 1, 0)
				local lim = b:FindFirstChild("SizeLimit")
				if lim then
					lim:Destroy()
				end
			end
		end
		tabbed.List.Position = UDim2.fromOffset(0, 54)
		tabbed.List.Size = UDim2.new(1, 0, 1, -54)
	end
	local dragonsTab = content.Dragons
	dragonsTab.Header.Size = UDim2.new(1, 0, 0, 24)
	Ui.fit(dragonsTab.Header, 16, 11, true)
	dragonsTab.Header.TextXAlignment = Enum.TextXAlignment.Left
	dragonsTab.Body.Position = UDim2.fromOffset(0, 30)
	dragonsTab.Body.Size = UDim2.new(1, 0, 1, -30)
	for _, side in { dragonsTab.Body.Nest, dragonsTab.Body.Dragons } do
		side.Title.Size = UDim2.new(1, 0, 0, 26)
		Ui.text(side.Title, 17, true)
		side.Title.TextXAlignment = Enum.TextXAlignment.Left
		side.List.Position = UDim2.fromOffset(0, 30)
		side.List.Size = UDim2.new(1, 0, 1, -30)
		rows(side.List)
	end
	rows(content.Crafting.List)
	rows(content.Upgrades.List)
	-- pulsanti delle sotto-schede (Buy / Sell, Upgrades / Bounties...) con testo leggibile
	for _, d in content:GetDescendants() do
		if d:IsA("TextButton") and d.Parent and d.Parent.Name == "Tabs" then
			Ui.text(d, 18, true)
		end
	end
	Ui.text(window.Title, 24, true)
	Ui.skin(window.Title, "panel_header")
	local caption = window.Title:FindFirstChild("AssetCaption")
	if caption and caption:IsA("TextLabel") then
		caption.TextXAlignment = Enum.TextXAlignment.Center
	end
	local function status(message: string, ok: boolean)
		window.Status.Text = message
		window.Status.TextColor3 = if ok then Theme.GOOD else Theme.BAD
	end
	local names = { "Store", "Backpack", "Dragons", "Crafting", "Upgrades" }
	local keys = { Enum.KeyCode.B, Enum.KeyCode.I, Enum.KeyCode.G, Enum.KeyCode.N, Enum.KeyCode.U }
	local refreshers: { [string]: () -> () } = {}
	local current: string? = nil
	local function open(name: string?)
		if not name or current == name then
			window.Visible = false
			current = nil
			gui:SetAttribute("MenuOpen", false)
			return
		end
		current = name
		-- finestra e titolo del colore della scheda (sfondo sfumato sotto la cornice)
		local tone = MENU_COLORS[name] or Color3.fromRGB(60, 110, 220)
		Ui.tint(window, tone, false, 0.012)
		local fill = window:FindFirstChild("Tinta") :: Frame?
		if fill then
			fill.BackgroundTransparency = 0.5
		end
		Ui.tint(window.Title, tone, false, 0.1)
		gui:SetAttribute("MenuOpen", true)
		window.Title.Text = if name == "Store" then "Shop" else name
		window.Status.Text = ""
		for _, n in names do
			content[n].Visible = n == name
		end
		if not refreshers[name] then
			local c = content[name]
			refreshers[name] = if name == "Store"
				then mountShop(c, status)
				elseif name == "Backpack" then mountInventory(c)
				elseif name == "Dragons" then DragonUI.mount(c, status)
				elseif name == "Upgrades" then UpgradeUI.mount(c, status)
				else CraftingUI.mount(c, status)
		end
		refreshers[name]()
		Ui.open(window)
	end
	-- una scheda puo' chiudere il menu mettendo MenuOpen a false (es. Ride nel menu draghi)
	gui:GetAttributeChangedSignal("MenuOpen"):Connect(function()
		if gui:GetAttribute("MenuOpen") ~= true and current then
			open(current)
		end
	end)
	for k, name in names do
		local b = column[name]
		b.Text = (if name == "Store" then "Shop" else name)
			.. (if UIS.TouchEnabled then "" else " (" .. keys[k].Name .. ")")
		b.Activated:Connect(function()
			open(name)
		end)
		CAS:BindAction("Menu" .. name, function(_, state)
			if state == Enum.UserInputState.Begin then
				open(name)
			end
			return Enum.ContextActionResult.Pass
		end, false, keys[k], if name == "Backpack" then Enum.KeyCode.V else keys[k])
	end
	window.Close.Activated:Connect(function()
		open(nil)
	end)
	column.Teleport.Activated:Connect(function()
		open(nil)
		local teleport = player.PlayerGui:FindFirstChild("Teletrasporto")
		if teleport then
			Ui.open(Ui.node(teleport, "Panel"))
		end
	end)
	local expanded = true
	local function showIcons()
		column.Visible = expanded
		toggle.Text = if expanded then "Hide" else "Menu"
	end
	toggle.Activated:Connect(function()
		expanded = not expanded
		showIcons()
	end)
	showIcons()
	local logical, compact = Vector2.new(1280, 680), false
	Ui.viewportChanged(function(vp)
		-- stessa scala dell'HUD (pixel logici). Computer: icone in colonna sotto il pannello del
		-- drago (attributo LeftBottom dell'HUD), finestra a destra della colonna. Telefono: icone
		-- in fila in alto fra i pannelli di sinistra e il meteo (in basso ci sono joystick e salto),
		-- finestra a tutto schermo.
		logical = Ui.fitScale(gui, vp)
		compact = Ui.compact(vp)
		local hud = player.PlayerGui:FindFirstChild("ClimbHUD")
		local function place()
			local cell = if compact then 58 else 78
			local step = cell + 8
			grid.CellSize = UDim2.fromOffset(cell, cell)
			for _, n in { "Store", "Backpack", "Dragons", "Crafting", "Upgrades", "Teleport" } do
				column[n].Size = UDim2.fromOffset(cell, cell)
				local cap = column[n]:FindFirstChild("AssetCaption")
				local fit = cap and cap:FindFirstChildOfClass("UITextSizeConstraint")
				if fit then
					fit.MaxTextSize = if compact then 12 else 14
				end
			end
			local wx, wy, ww, wh
			if compact then
				local x0 = 272
				local room = logical.X - 230 - (x0 + 66)
				local cols = math.clamp(math.floor(room / step), 3, 6)
				Ui.px(toggle, 0, x0, 0, 8, 58, 28)
				Ui.px(column, 0, x0 + 66, 0, 8, cols * step, math.ceil(6 / cols) * step)
				wx, wy, ww, wh = 8, 8, logical.X - 16, logical.Y - 16
			else
				local top = ((hud and hud:GetAttribute("LeftBottom")) or 300) :: number
				Ui.px(toggle, 0, 16, 0, top, 96, 30)
				local rowsFit = math.clamp(math.floor((logical.Y - top - 40 - 16 + 8) / step), 1, 6)
				local cols = math.ceil(6 / rowsFit)
				Ui.px(column, 0, 16, 0, top + 38, cols * step, math.ceil(6 / cols) * step)
				local x = math.max(356, 16 + cols * step) + 14
				ww = math.min(logical.X - x - 16, 1060)
				wx, wy, wh = x + (logical.X - x - 16 - ww) / 2, 16, logical.Y - 32
			end
			window.AnchorPoint = Vector2.zero
			window.Position = UDim2.fromOffset(wx, wy)
			window.Size = UDim2.fromOffset(ww, wh)
			-- draghi: nido e collezione affiancati, uno sopra l'altro se la finestra e' stretta
			local narrow = ww < 720
			local body = content.Dragons.Body
			body.Nest.Position = UDim2.fromScale(0, 0)
			body.Nest.Size = UDim2.fromScale(if narrow then 1 else 0.34, if narrow then 0.36 else 1)
			body.Dragons.Position = UDim2.fromScale(if narrow then 0 else 0.36, if narrow then 0.39 else 0)
			body.Dragons.Size = UDim2.fromScale(if narrow then 1 else 0.64, if narrow then 0.61 else 1)
		end
		place()
		if hud and not hud:GetAttribute("MenuBound") then
			hud:SetAttribute("MenuBound", true)
			hud:GetAttributeChangedSignal("LeftBottom"):Connect(place)
		end
	end)
	for eventName, tabName in { OpenShop = "Store", OpenCrafting = "Crafting", OpenDragons = "Dragons" } do
		(remotes:WaitForChild(eventName) :: RemoteEvent).OnClientEvent:Connect(function()
			if current ~= tabName then
				open(tabName)
			end
		end)
	end
	local function refreshOpen()
		if current and refreshers[current] then
			refreshers[current]()
		end
	end
	for _, attr in { "Coins", "DragonData", "CarryingEgg", "HouseLevel", "Pitons" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshOpen)
	end
	for id in DragonConfig.GAMEPASSES do
		player:GetAttributeChangedSignal("Pass_" .. id):Connect(refreshOpen)
	end
	for _, folderName in { "Ores", "Materiali" } do
		task.spawn(function()
			local folder = player:WaitForChild(folderName, 120)
			if not folder then
				return
			end
			local function watch(v: Instance)
				if v:IsA("IntValue") then
					v.Changed:Connect(refreshOpen)
				end
			end
			for _, v in folder:GetChildren() do
				watch(v)
			end
			folder.ChildAdded:Connect(function(v)
				watch(v)
				refreshOpen()
			end)
			folder.ChildRemoved:Connect(refreshOpen)
		end)
	end
	task.spawn(function()
		while gui.Parent do
			task.wait(1)
			if current == "Dragons" and DragonUI.tick() then
				refreshOpen() -- un uovo e' pronto: compare il pulsante Hatch
			end
		end
	end)
end
return MainMenu
