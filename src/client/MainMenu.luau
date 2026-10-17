--!strict
-- Controller del menu: struttura e carte provengono dai modelli StarterGui.
local CAS = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
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
local UiGlow = require(script.Parent.UiGlow)
local Slant = require(script.Parent.Slant)
local UiKit = require(script.Parent.UiKit)
local TravelUI = require(script.Parent.TravelUI)
local ProfileUI = require(script.Parent.ProfileUI)
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
-- lista a carte (negozio, crafting): griglia con 2-6 colonne secondo la larghezza, celle alte h
-- (pixel logici, prima della scala della schermata). Prima erano righe larghe tutto lo schermo
local function cards(list: ScrollingFrame, minW: number, h: number)
	rows(list)
	local old = list:FindFirstChildOfClass("UIListLayout")
	if old then
		old:Destroy()
	end
	local g = list:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.CellPadding = UDim2.fromOffset(10, 10)
	g.Parent = list
	local function size()
		local scale = 1
		local gui = list:FindFirstAncestorWhichIsA("ScreenGui")
		local u = gui and gui:FindFirstChild("ScalaUI")
		if u and u:IsA("UIScale") and u.Scale > 0 then
			scale = u.Scale
		end
		local w = list.AbsoluteSize.X / scale - 14
		if w < 50 then
			return
		end
		local cols = math.clamp(math.floor(w / minW), 1, 6)
		g.CellSize = UDim2.fromOffset(math.floor((w - (cols - 1) * 10) / cols), if gui and gui:GetAttribute("ShortUI") then 166 else h)
	end
	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(size)
	size()
end
-- colori delle carte (a turno): prima erano tutte blu scuro uguali
local CARD_TONES = {
	Theme.BLUE, Theme.PURPLE, Theme.ORANGE,
	Theme.GOOD, Theme.BAD, Theme.TEAL,
}

local function mountShop(container: Frame, status: (string, boolean) -> ()): () -> ()
	local list = Ui.node(container, "List")
	cards(list, 220, 330)
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
		-- carta in rilievo ad angoli vivi (stile unico del menu, client/UiKit)
		local fill = c:FindFirstChild("Tinta")
		if fill then
			fill:Destroy()
		end
		local surface = c:FindFirstChild("AssetSurface")
		if surface and surface:IsA("GuiObject") then
			surface.Visible = false
		end
		-- niente piu' "panel_card" del modello: Theme.paint lo ridipingeva di blu con la sfumatura
		-- chiara a ogni impaginazione (le carte blu della scheda Sell, Mirko 16/10)
		c:SetAttribute("UiAsset", nil)
		for _, g in c:GetChildren() do
			if g:IsA("UIGradient") then
				g:Destroy()
			end
		end
		c.BackgroundColor3 = UiKit.RAISED
		c.BackgroundTransparency = 0.18
		UiKit.edge(c)
		local _ = CARD_TONES
		UiKit.text(c.Title, "name", 19)
		c.Title.TextXAlignment = Enum.TextXAlignment.Center
		UiKit.text(c.Description, "secondary")
		c.Description.TextXAlignment = Enum.TextXAlignment.Center
		UiKit.text(c.Cost, "stat", 19)
		c.Cost.TextColor3 = UiKit.ACCENT
		UiKit.button(c.Buy, "primary")
		UiKit.button(c.SellActions.One, "secondary")
		UiKit.button(c.SellActions.All, "secondary")
		return c
	end
	render = function()
		Ui.clear(list)
		for _, name in { "Buy", "Sell", "Robux" } do
			UiKit.tab(Ui.node(container, "Tabs/" .. name), name == sub)
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
				UiKit.button(c.Buy, if owned or not available then "disabled" else "primary")
				c.Buy.Text = if owned then "OWNED" elseif available then "BUY (ROBUX)" else "COMING SOON"
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
-- Zaino: caselle in griglia come un vero inventario (Mirko 15/10: "solo immagini fisse, non puoi
-- spostare item, rimuoverli ne' niente"). Trascini una casella su un'altra per spostarla (sul
-- telefono tieni premuto un attimo), clic per sceglierla. L'ordine si salva (BagOrder).
-- Mirko 16/10: a destra il personaggio 3D, la scheda dell'oggetto scelto e la BARRA 1-5 (la stessa
-- del gioco, shared/Hotbar): si sceglie un attrezzo e si tocca una casella (o lo si trascina
-- sulla casella col mouse) per metterlo li'; una casella piena si sposta su un'altra o si toglie
-- con "Remove". Nella barra vanno solo gli attrezzi che si tengono in mano.
local INV_FILTERS = { "All", "Ores", "Materials", "Tools", "Eggs" }
local TOOL_ICONS = { "item_Piccozza", "item_Piccone", "item_Rampino", "item_Torcia" }
local function mountInventory(container: Frame, status: (string, boolean) -> (), ctx: any?): () -> ()
	local UIS = game:GetService("UserInputService")
	local HttpService = game:GetService("HttpService")
	local GuiService = game:GetService("GuiService")
	local Hotbar = require(Shared:WaitForChild("Hotbar"))
	local AvatarView = require(script.Parent.AvatarView)
	-- scala delle cornici delle caselle: bordo di circa 9 px invece di 13+ (UiKit.slot la legge
	-- dall'attributo CorniceScala)
	local THIN_SLOT = 0.27
	local list = Ui.node(container, "List") :: ScrollingFrame
	rows(list)
	local old = list:FindFirstChildOfClass("UIListLayout")
	if old then
		old:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(112, 124)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	-- filtri in alto (Mirko 15/10: "nel backpack dei filtri tipo materiali, tool, egg")
	local filter = "All"
	local filterBar = Theme.frame(container, Color3.new(), 1)
	filterBar.Name = "Filtri"
	filterBar.ClipsDescendants = false
	local chips: { [string]: TextButton } = {}
	for _, f in INV_FILTERS do
		local b = Instance.new("TextButton")
		b.Name = f
		b.Text = f
		b.Parent = filterBar
		chips[f] = b
	end

	-- Impaginazione come il riferimento di Diablo IV (Mirko 16/10, 04_RIFERIMENTO_diablo4):
	--   in alto: statistiche a sinistra, personaggio piu' piccolo al centro-destra con le caselle
	--   dell'equipaggiamento attorno (ramponi, tuta, piccone rinforzato | parapendio, sella, chiodi)
	--   sotto: filtri e griglia di caselle piccole e fitte; in fondo: monete, pietre, chiodi
	--   a destra: scheda dell'oggetto scelto e barra 1-5
	local doll = Theme.frame(container, Theme.DARK2, 1)
	doll.Name = "Personaggio"
	doll.ClipsDescendants = false
	UiKit.panel(doll, { border = 10 })
	-- statistiche (le stesse del profilo: client/ProfileUI.stats)
	local statsCol = Theme.frame(doll, Color3.new(), 1)
	statsCol.Name = "Statistiche"
	statsCol.ZIndex = 3
	local whoName = UiKit.label(statsCol, player.DisplayName, "name", 20)
	whoName.ZIndex = 4
	local whoSub = UiKit.label(statsCol, "MOUNTAIN CLIMBER", "status")
	whoSub.TextColor3 = UiKit.ACCENT
	whoSub.ZIndex = 4
	type StatRow = { key: TextLabel, value: TextLabel, line: Frame }
	local statRows: { StatRow } = {}
	for i = 1, 6 do
		local line = Theme.frame(statsCol, UiKit.LINE, 0.85)
		line.ZIndex = 4
		local key = UiKit.label(statsCol, "", "name", 15)
		key.ZIndex = 4
		local value = UiKit.label(statsCol, "", "stat", 17)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.ZIndex = 4
		statRows[i] = { key = key, value = value, line = line }
	end
	local avatarBox = Theme.frame(doll, UiKit.INK, 1)
	avatarBox.Name = "Modello"
	avatarBox.ZIndex = 3
	avatarBox.ClipsDescendants = false
	local avatar = AvatarView.new(avatarBox, function()
		return container.Visible
	end)
	-- caselle dell'equipaggiamento attorno al personaggio (3 a sinistra, 3 a destra)
	local EQUIP = { "Ramponi", "Tuta", "PiccoRinforzato", "Parapendio", "Sella", "Chiodi" }
	local equipSlots: { [string]: TextButton } = {}
	for _, id in EQUIP do
		local b = Instance.new("TextButton")
		b.Name = "Equip_" .. id
		b.Text = ""
		b.AutoButtonColor = false
		b:SetAttribute("UiNative", true)
		b.ZIndex = 4
		b.Parent = doll
		equipSlots[id] = b
	end
	-- monete in fondo (come l'oro e le polveri in fondo all'inventario di Diablo IV)
	local purse = Theme.frame(container, UiKit.INK, 0.25)
	purse.Name = "Monete"
	UiKit.edge(purse, UiKit.LINE, 1, 0.8)
	type PurseEntry = { icon: ImageLabel, text: TextLabel }
	local purseItems: { PurseEntry } = {}
	for i, icon in { "icon_coin", "icon_stone", "item_Pitons" } do
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.ZIndex = 3
		img.Parent = purse
		if not Ui.asset(img, icon) then
			img.Visible = true
			img.Image = ""
			img.BackgroundTransparency = 0
			img.BackgroundColor3 = if i == 2 then Theme.PURPLE else UiKit.DIM
			img.Rotation = 45
		end
		local t = UiKit.label(purse, "0", "stat", 17)
		t.TextColor3 = if i == 1 then UiKit.ACCENT elseif i == 2 then Color3.fromRGB(200, 160, 255) else UiKit.TEXT
		t.ZIndex = 3
		purseItems[i] = { icon = img, text = t }
	end

	-- PANNELLO DI DESTRA: scheda dell'oggetto, barra 1-5 in fondo
	local side = Theme.frame(container, Theme.DARK2, 1)
	side.Name = "SchedaZaino"
	UiKit.panel(side, { border = 10 })
	local info = Theme.frame(side, Color3.new(), 1)
	info.Name = "Oggetto"
	info.ZIndex = 3
	local infoIcon = Instance.new("ImageLabel")
	infoIcon.BackgroundTransparency = 1
	infoIcon.ZIndex = 4
	infoIcon.Parent = info
	local infoTitle = UiKit.label(info, "", "name", 20)
	infoTitle.ZIndex = 4
	local infoKind = UiKit.label(info, "", "status")
	infoKind.ZIndex = 4
	local infoScroll = Theme.scroll(info)
	infoScroll.ZIndex = 4
	infoScroll.ScrollBarThickness = 3
	local infoText = UiKit.label(infoScroll, "", "body", 14)
	infoText.TextWrapped = true
	infoText.TextTruncate = Enum.TextTruncate.None
	infoText.TextYAlignment = Enum.TextYAlignment.Top
	infoText.RichText = true
	infoText.AutomaticSize = Enum.AutomaticSize.Y
	infoText.Size = UDim2.new(1, -6, 0, 20)
	infoText.ZIndex = 4
	local actions = Theme.frame(info, Color3.new(), 1)
	actions.Name = "Azioni"
	actions.ZIndex = 4
	local dropOne = Instance.new("TextButton")
	dropOne.Name = "Butta1"
	dropOne.ZIndex = 5
	dropOne.Parent = actions
	local dropAll = Instance.new("TextButton")
	dropAll.Name = "ButtaTutto"
	dropAll.ZIndex = 5
	dropAll.Parent = actions
	local removeBtn = Instance.new("TextButton")
	removeBtn.Name = "Togli"
	removeBtn.ZIndex = 5
	removeBtn.Parent = actions
	-- barra 1-5 dello zaino (stesse caselle della barra del gioco)
	local barBox = Theme.frame(side, UiKit.INK, 0.3)
	barBox.Name = "BarraAttrezzi"
	barBox.ZIndex = 3
	UiKit.edge(barBox, UiKit.LINE, 1, 0.8)
	local barTitle = UiKit.label(barBox, "HOTBAR", "status")
	barTitle.ZIndex = 4
	local barHint = UiKit.label(barBox, "", "secondary", 13)
	barHint.ZIndex = 4
	barHint.TextXAlignment = Enum.TextXAlignment.Right
	local barSlots: { TextButton } = {}
	for i = 1, Hotbar.SLOTS do
		local b = Instance.new("TextButton")
		b.Name = "Barra" .. i
		b.Text = ""
		b.AutoButtonColor = false
		b:SetAttribute("UiNative", true)
		b.ZIndex = 4
		b.Parent = barBox
		barSlots[i] = b
	end

	type Item = { key: string, title: string, count: number, asset: string, model: Instance?, id: string?, text: string, drop: string?, kind: string, tool: string?, equip: boolean?, missing: boolean? }
	local selectedKey: string? = nil
	local pickedSlot: number? = nil -- casella della barra scelta (per spostarla o toglierla)
	local confirmAll = false
	local items: { Item } = {}
	local allItems: { Item } = {}
	local render: () -> ()

	local function savedOrder(): { string }
		local raw = player:GetAttribute("BagOrder")
		if type(raw) == "string" then
			local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and type(t) == "table" then
				return t
			end
		end
		return {}
	end
	local function toolIcon(img: ImageLabel, name: string, tool: Tool?)
		local k = table.find(Hotbar.DEFAULT, name)
		if k then
			Theme.assetPreview(img, TOOL_ICONS[k], nil)
			img.ImageColor3 = Color3.new(1, 1, 1)
		else
			img.Image = if tool then tool.TextureId else ""
		end
	end
	local function collect(): { Item }
		local out: { Item } = {}
		-- attrezzi da tenere in mano (i Tool veri): sono quelli che vanno nella barra 1-5
		local ownedTools: { [string]: boolean } = {}
		for _, t in Hotbar.owned(player) do
			if not ownedTools[t.Name] then
				ownedTools[t.Name] = true
				table.insert(out, { key = "tool:" .. t.Name, title = t.Name, count = 1, asset = "", tool = t.Name, kind = "Tools",
					text = (if t.ToolTip ~= "" then t.ToolTip .. "\n" else "") .. "A tool you hold: put it in a hotbar slot to use it." })
			end
		end
		for _, ore in ORES do
			local n = oreCount(ore)
			if n > 0 then
				table.insert(out, { key = "ore:" .. ore, title = Names.t(ore), count = n, asset = "ore_" .. ore, model = Theme.oreModel(ore),
					text = string.format("Ore. Sell it at the shop (%d coins each) or use it at the workbench.", EconomyConfig.ORE_PRICES[ore] or 1), drop = ore, kind = "Ores" })
			end
		end
		local mats = player:FindFirstChild("Materiali")
		local icons = RS:FindFirstChild("DropIcone")
		local names = icons and icons:FindFirstChild("Nomi")
		for _, v in (if mats then mats:GetChildren() else {}) do
			if v:IsA("IntValue") and v.Value > 0 then
				local shown = names and names:GetAttribute(v.Name)
				table.insert(out, { key = "mat:" .. v.Name, title = if type(shown) == "string" then shown else Names.t(v.Name), count = v.Value,
					asset = "", model = icons and icons:FindFirstChild(v.Name), text = "Dropped by monsters (or crafted at the Workbench). Used for upgrades.", drop = v.Name, kind = "Materials" })
			end
		end
		for _, recipe in Gear.RECIPES do
			local asTool = Hotbar.RECIPE_TOOL[recipe.id]
			local isGlider = false
			for _, g in Gear.GLIDERS do
				if g.id == recipe.id then
					isGlider = true
				end
			end
			-- (le vele stanno tutte nella casella del parapendio: si vede quella che usi)
			local isEquip = table.find(EQUIP, recipe.id) ~= nil or isGlider
			local owned = Gear.has(player, recipe.id)
			if (owned or isEquip) and not (asTool and ownedTools[asTool]) then
				-- l'equipaggiamento sta nelle caselle attorno al personaggio (anche quello che manca,
				-- spento), non nella griglia
				table.insert(out, { key = "gear:" .. recipe.id, title = recipe.name, count = 1, asset = "", id = recipe.id,
					model = Theme.itemModel(if recipe.id == "Chiodi" then "Pitons" else recipe.id, Theme.ACCENT),
					text = recipe.description .. (if owned then "" else "\n<font color=\"#FF8C94\">Not crafted yet: make it at a Workbench.</font>"),
					kind = "Tools", equip = isEquip, missing = not owned })
			end
		end
		-- uova: quella che porti e quelle nel nido (non si buttano)
		local carried = player:GetAttribute("CarryingEgg")
		if type(carried) == "string" then
			local el, rar = string.match(carried, "^(.-)|(.*)$")
			if el then
				table.insert(out, { key = "egg:carried", title = Names.t(rar or "") .. " " .. Names.t(el) .. " Egg", count = 1, asset = "icon_egg",
					model = preview("Eggs", el), text = "You are carrying it: take it to your nest to hatch it.", kind = "Eggs" })
			end
		end
		local okData, data = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("DragonData") or "{}") :: string)
		if okData and type(data) == "table" then
			for i, egg in data.nest or {} do
				local left = (egg.readyAt or 0) - (data.now or 0)
				table.insert(out, { key = "egg:nest" .. i, title = Names.t(egg.rarity or "") .. " " .. Names.t(egg.element or "") .. " Egg", count = 1,
					asset = "icon_egg", model = preview("Eggs", egg.element or ""),
					text = if left <= 0 then "In your nest: ready to hatch! Open Dragons > Nest." else "In your nest, hatching soon.", kind = "Eggs" })
			end
		end
		-- ordine scelto dal giocatore, i nuovi in fondo
		local rank: { [string]: number } = {}
		for i, k in savedOrder() do
			rank[k] = i
		end
		local base: { [string]: number } = {}
		for i, it in out do
			base[it.key] = i
		end
		table.sort(out, function(a, b)
			return (rank[a.key] or (10000 + base[a.key])) < (rank[b.key] or (10000 + base[b.key]))
		end)
		return out
	end
	local function saveOrder(keys: { string })
		-- le chiavi che ora non si vedono (finite, poi tornano) restano dopo, nel loro ordine
		local seen: { [string]: boolean } = {}
		for _, k in keys do
			seen[k] = true
		end
		for _, k in savedOrder() do
			if not seen[k] and #keys < 120 then
				table.insert(keys, k)
				seen[k] = true
			end
		end
		local json = HttpService:JSONEncode(keys)
		player:SetAttribute("BagOrder", json) -- subito sul client, poi il server lo salva
		local remote = remotes:FindFirstChild("SaveBagOrder") :: RemoteEvent?
		if remote then
			remote:FireServer(json)
		end
	end
	local function chosen(): Item?
		for _, x in allItems do
			if x.key == selectedKey then
				return x
			end
		end
		return nil
	end

	-- BARRA: metti un attrezzo nella casella i (se era gia' in un'altra casella le due si
	-- scambiano; se la casella era piena, quello che c'era esce dalla barra o va al suo posto)
	local function assign(toolName: string, i: number)
		local slots = Hotbar.current(player)
		local from = table.find(slots, toolName)
		if from == i then
			return
		end
		local was = slots[i]
		slots[i] = toolName
		if from then
			slots[from] = was
		end
		Hotbar.save(player, slots)
		status(string.format("%s in slot %d", toolName, i), true)
	end
	local function moveSlot(a: number, b: number)
		local slots = Hotbar.current(player)
		slots[a], slots[b] = slots[b], slots[a]
		Hotbar.save(player, slots)
	end
	local function removeFromBar(i: number)
		local slots = Hotbar.current(player)
		local name = slots[i]
		if name == "" then
			return
		end
		slots[i] = ""
		Hotbar.save(player, slots)
		status(name .. " removed from the hotbar (still in your inventory)", true)
	end
	local function paintBar()
		local layout = Hotbar.layout(player)
		local it = chosen()
		local toolPicked = it and it.tool
		local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
		for i, b in barSlots do
			for _, c in b:GetChildren() do
				if c:IsA("GuiObject") and c.Name ~= "Cornice" then
					c:Destroy()
				end
			end
			local t = layout[i]
			-- destinazione valida (attrezzo scelto) = cornice verde; casella scelta = oro acceso;
			-- attrezzo in mano = oro chiaro (cornici di Codex)
			local target = toolPicked ~= nil or (pickedSlot ~= nil and pickedSlot ~= i)
			b:SetAttribute("CorniceScala", THIN_SLOT)
			if not UiKit.slot(b, if pickedSlot == i then "selected" elseif target then "valid" elseif held and t == held then "hover" else "normal") then
				b.BackgroundColor3 = if pickedSlot == i then Color3.fromRGB(70, 56, 18) elseif t then UiKit.RAISED else UiKit.INK
				b.BackgroundTransparency = if t or pickedSlot == i then 0.05 else 0.4
				local stroke = b:FindFirstChildOfClass("UIStroke") or UiKit.edge(b, UiKit.LINE, 1, 0.7)
				stroke.Color = if target then UiKit.ACCENT elseif held and t == held then UiKit.GOOD else UiKit.LINE
				stroke.Transparency = if target then 0 elseif held and t == held then 0.2 else 0.7
				stroke.Thickness = if target then 2 else 1
			end
			b:SetAttribute("CorniceFissa", true)
			local key = UiKit.label(b, tostring(i), "status", 12)
			key.Position = UDim2.fromOffset(3, 1)
			key.Size = UDim2.fromOffset(14, 14)
			key.ZIndex = 6
			if t then
				local icon = Instance.new("ImageLabel")
				icon.BackgroundTransparency = 1
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Position = UDim2.fromScale(0.5, 0.52)
				icon.Size = UDim2.fromScale(0.72, 0.72)
				icon.ZIndex = 5
				icon.Parent = b
				toolIcon(icon, t.Name, t)
			end
		end
		barHint.Text = if toolPicked then "Tap a slot to put it there"
			elseif pickedSlot then "Tap another slot to swap"
			elseif it and not it.tool then "Only tools you hold go here"
			else "Pick a tool, then a slot"
		barHint.TextColor3 = if it and not it.tool then UiKit.MUTED else UiKit.ACCENT
	end

	local function showInfo()
		local it = chosen()
		local layout = Hotbar.layout(player)
		local inBar: number? = nil
		if it and it.tool then
			for i, t in layout do
				if t.Name == it.tool then
					inBar = i
				end
			end
		end
		removeBtn.Visible = false
		if not it then
			infoIcon.Visible = false
			infoTitle.Text = "Inventory"
			infoKind.Text = ""
			infoText.Text = if Ui.touch() then "Tap an item to see it. Hold and drag it onto another slot to move it."
				else "Click an item to see it. Drag it onto another slot to move it."
			dropOne.Visible, dropAll.Visible = false, false
			paintBar()
			return
		end
		local item = it :: Item
		infoIcon.Visible = true
		if item.tool then
			toolIcon(infoIcon, item.tool, nil)
		elseif item.id and Theme.ITEM_ICONS[item.id] then
			Theme.itemIcon(infoIcon, item.id, item.model)
		else
			Theme.assetPreview(infoIcon, item.asset, item.model)
		end
		infoTitle.Text = if item.drop then string.format("%s  x%d", item.title, item.count) else item.title
		infoKind.Text = if item.tool then (if inBar then string.format("TOOL · IN SLOT %d", inBar) else "TOOL · NOT IN HOTBAR")
			else string.upper(item.kind)
		infoKind.TextColor3 = if item.tool then UiKit.ACCENT else UiKit.MUTED
		local extra = if item.tool then ""
			elseif item.kind == "Tools" then "\n<font color=\"#B0BDD0\">Gear works by itself: it doesn't go in the hotbar.</font>"
			else ""
		infoText.Text = item.text .. extra
		dropOne.Visible = item.drop ~= nil
		dropAll.Visible = item.drop ~= nil
		dropAll.Text = if confirmAll then "SURE?" else "DROP ALL"
		removeBtn.Visible = inBar ~= nil
		paintBar()
	end
	local function drop(amount: any)
		local it = chosen()
		if not it or not it.drop then
			return
		end
		local ok, message = (remotes:WaitForChild("Shop") :: RemoteFunction):InvokeServer("discard", it.key, amount)
		status(message or "", ok)
	end
	UiKit.button(dropOne, "danger")
	dropOne.Text = "DROP 1"
	UiKit.button(dropAll, "danger")
	dropAll.Text = "DROP ALL"
	UiKit.button(removeBtn, "secondary")
	removeBtn.Text = "REMOVE FROM HOTBAR"
	dropOne.Activated:Connect(function()
		confirmAll = false
		drop(1)
	end)
	dropAll.Activated:Connect(function()
		if confirmAll then
			confirmAll = false
			drop("all")
		else
			confirmAll = true
			showInfo()
		end
	end)
	removeBtn.Activated:Connect(function()
		local it = chosen()
		if not it or not it.tool then
			return
		end
		for i, t in Hotbar.layout(player) do
			if t.Name == it.tool then
				removeFromBar(i)
			end
		end
	end)
	-- tocco su una casella della barra: assegna l'attrezzo scelto, oppure sceglie/sposta
	for i, b in barSlots do
		b.Activated:Connect(function()
			local it = chosen()
			if it and it.tool then
				assign(it.tool, i)
				pickedSlot = nil
			elseif it then
				status(it.title .. " can't go in the hotbar: only tools you hold", false)
				selectedKey = nil
			elseif pickedSlot and pickedSlot ~= i then
				moveSlot(pickedSlot, i)
				pickedSlot = nil
			else
				local t = Hotbar.layout(player)[i]
				-- casella piena: mostra l'attrezzo (Remove lo toglie); toccando un'altra casella ci va
				pickedSlot = if t then i else nil
				selectedKey = if t then "tool:" .. t.Name else nil
			end
			render()
		end)
	end

	-- trascinamento: una copia della casella segue il puntatore su una schermata a parte
	local dragGui = Instance.new("ScreenGui")
	dragGui.Name = "TrascinaZaino"
	dragGui.DisplayOrder = 50
	dragGui.ResetOnSpawn = false
	dragGui.Parent = player:WaitForChild("PlayerGui")
	local menuGui = container:FindFirstAncestorWhichIsA("ScreenGui")
	local slots: { GuiObject } = {}
	local function uiScale(): number
		local su = menuGui and menuGui:FindFirstChild("ScalaUI")
		return if su and su:IsA("UIScale") and su.Scale > 0 then su.Scale else 1
	end
	local function hit(list_: { GuiObject }, p: Vector2): number?
		-- le posizioni dell'input sono sotto la barra di Roblox, quelle delle caselle no se la
		-- schermata la ignora
		local inset = if menuGui and menuGui.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero
		local q = p + inset
		for i, s in list_ do
			local a, z = s.AbsolutePosition, s.AbsoluteSize
			if q.X >= a.X and q.X <= a.X + z.X and q.Y >= a.Y and q.Y <= a.Y + z.Y then
				return i
			end
		end
		return nil
	end
	local function startDrag(index: number, slot: GuiObject, input: InputObject)
		local item = items[index]
		local ghost = slot:Clone()
		local ring = ghost:FindFirstChild("AnelloLuce")
		if ring then
			ring:Destroy()
		end
		ghost.Size = UDim2.fromOffset(slot.AbsoluteSize.X, slot.AbsoluteSize.Y)
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.Rotation = 4
		ghost.Parent = dragGui
		slot.BackgroundTransparency = 0.7
		list.ScrollingEnabled = false
		selectedKey = item.key
		paintBar() -- le caselle della barra valide si accendono durante il trascinamento
		local move: RBXScriptConnection
		local finish: RBXScriptConnection
		local function at(p: Vector3)
			ghost.Position = UDim2.fromOffset(p.X, p.Y)
		end
		at(input.Position)
		move = UIS.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
				at(i.Position)
			end
		end)
		finish = UIS.InputEnded:Connect(function(i)
			if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			move:Disconnect()
			finish:Disconnect()
			ghost:Destroy()
			list.ScrollingEnabled = true
			local p = Vector2.new(i.Position.X, i.Position.Y)
			local barTarget = hit(barSlots :: any, p)
			if barTarget then
				if item.tool then
					assign(item.tool, barTarget)
				else
					status(item.title .. " can't go in the hotbar: only tools you hold", false)
				end
			elseif filter == "All" then
				local target = hit(slots, p)
				if target and target ~= index then
					local keys = {}
					for _, x in items do
						table.insert(keys, x.key)
					end
					table.remove(keys, index)
					table.insert(keys, math.min(target, #keys + 1), item.key)
					saveOrder(keys)
				end
			end
			render()
		end)
	end
	-- trascinare una casella della barra (mouse): su un'altra = scambio, fuori dalla barra = togli
	for i, b in barSlots do
		b.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not Hotbar.layout(player)[i] then
				return
			end
			local from = input.Position
			local moved = false
			local watch: RBXScriptConnection
			local stop: RBXScriptConnection
			watch = UIS.InputChanged:Connect(function(m)
				if m.UserInputType == Enum.UserInputType.MouseMovement and (m.Position - from).Magnitude > 10 then
					moved = true
				end
			end)
			stop = UIS.InputEnded:Connect(function(m)
				if m.UserInputType ~= Enum.UserInputType.MouseButton1 then
					return
				end
				watch:Disconnect()
				stop:Disconnect()
				if not moved then
					return -- semplice clic: lo gestisce Activated
				end
				local p = Vector2.new(m.Position.X, m.Position.Y)
				local target = hit(barSlots :: any, p)
				if target and target ~= i then
					moveSlot(i, target)
				elseif not target and not hit({ barBox }, p) then
					removeFromBar(i)
				end
				pickedSlot = nil
				render()
			end)
		end)
	end

	for f, b in chips do
		b.Activated:Connect(function()
			filter = f
			list.CanvasPosition = Vector2.zero -- (prima restava una posizione che col filtro non esisteva piu')
			render()
		end)
	end

	-- impaginazione (una sola, pixel logici): a sinistra personaggio sopra e griglia sotto, a
	-- destra la scheda dell'oggetto con la barra 1-5
	local CELL, GAP = 60, 6 -- caselle piccole e fitte (prima 112x124 con cornici grosse)
	-- (THIN_SLOT e' definita in cima a mountInventory)
	local function layout()
		local k = uiScale()
		local w, h = container.AbsoluteSize.X / k, container.AbsoluteSize.Y / k
		if w < 50 then
			return
		end
		local stacked = w < 640
		local sideW = if stacked then w else math.clamp(math.floor(w * 0.3), 270, 340)
		local mainW = if stacked then w else w - sideW - 12
		local purseH = 30
		local dollH = math.clamp(math.floor(h * 0.46), 190, 300)
		-- PERSONAGGIO: statistiche | equipaggiamento - modello - equipaggiamento
		Ui.px(doll, 0, 0, 0, 0, mainW, dollH)
		local statsW = math.clamp(math.floor(mainW * 0.3), 170, 240)
		Ui.px(statsCol, 0, 16, 0, 14, statsW - 16, dollH - 28)
		Ui.px(whoName, 0, 0, 0, 0, statsW - 16, 26)
		Ui.px(whoSub, 0, 0, 0, 26, statsW - 16, 16)
		local rowsTop = 50
		local rowH = math.max(20, math.floor((dollH - 28 - rowsTop) / #statRows))
		for i, r in statRows do
			local y = rowsTop + (i - 1) * rowH
			Ui.px(r.key, 0, 0, 0, y, statsW - 80, rowH)
			Ui.px(r.value, 1, 0, 0, y, 76, rowH, 1, 0)
			Ui.px(r.line, 0, 0, 0, y + rowH - 1, statsW - 16, 1)
		end
		local slotS = math.clamp(math.floor((dollH - 40) / 3) - 8, 46, 64)
		local areaX = statsW + 10
		local areaW = mainW - areaX - 14
		local charW = math.clamp(areaW - 2 * (slotS + 24), 120, 260)
		local cx = areaX + areaW / 2
		Ui.px(avatarBox, 0, cx - charW / 2, 0, 10, charW, dollH - 20)
		local colH = 3 * slotS + 2 * 10
		local y0 = math.floor((dollH - colH) / 2)
		for i, id in EQUIP do
			local leftSide = i <= 3
			local row = (i - 1) % 3
			local x = if leftSide then cx - charW / 2 - slotS - 10 else cx + charW / 2 + 10
			Ui.px(equipSlots[id], 0, x, 0, y0 + row * (slotS + 10), slotS, slotS)
		end
		-- FILTRI e GRIGLIA sotto il personaggio
		local barH = 36
		local fy = dollH + 10
		filterBar.Position = UDim2.fromOffset(0, fy)
		filterBar.Size = UDim2.new(0, mainW, 0, barH)
		local chipW = math.min(116, math.floor((mainW - 4 * 6) / 5))
		for i, f in INV_FILTERS do
			local b = chips[f]
			b.Position = UDim2.fromOffset((i - 1) * (chipW + 6), 0)
			b.Size = UDim2.fromOffset(chipW, barH)
			b.TextSize = 16
		end
		local gy = fy + barH + 8
		local gridH = if stacked then 200 else math.max(CELL + 12, h - gy - purseH - 8)
		list.Position = UDim2.fromOffset(0, gy)
		list.Size = UDim2.fromOffset(mainW, gridH)
		grid.CellSize = UDim2.fromOffset(CELL, CELL)
		grid.CellPadding = UDim2.fromOffset(GAP, GAP)
		Ui.px(purse, 0, 0, 0, gy + gridH + 6, mainW, purseH - 4)
		local px = 12
		for _, e in purseItems do
			Ui.px(e.icon, 0, px, 0.5, 0, if e.icon.Rotation ~= 0 then 14 else 22, if e.icon.Rotation ~= 0 then 14 else 22, 0, 0.5)
			Ui.px(e.text, 0, px + 28, 0, 0, 120, purseH - 4)
			px += 160
		end
		-- SCHEDA a destra (sotto, se la pagina e' stretta)
		if stacked then
			side.Position = UDim2.fromOffset(0, gy + gridH + purseH + 10)
			side.Size = UDim2.new(1, 0, 0, 300)
		else
			side.Position = UDim2.new(1, -sideW, 0, 0)
			side.Size = UDim2.new(0, sideW, 1, 0)
		end
		local wantH = if stacked then gy + gridH + purseH + 10 + 300 else 0
		if container:GetAttribute("AltezzaMinima") ~= wantH then
			container:SetAttribute("AltezzaMinima", wantH)
			if ctx and ctx.fit then
				task.defer(ctx.fit)
			end
		end
		local sh = if stacked then 300 else h
		local bslot = 50
		local barBoxH = bslot + 34
		barBox.AnchorPoint = Vector2.new(0, 1)
		barBox.Position = UDim2.new(0, 12, 1, -12)
		barBox.Size = UDim2.new(1, -24, 0, barBoxH)
		barTitle.Position = UDim2.fromOffset(8, 2)
		barTitle.Size = UDim2.new(0.4, 0, 0, 24)
		barHint.Position = UDim2.new(0.4, 0, 0, 2)
		barHint.Size = UDim2.new(0.6, -8, 0, 24)
		local totalW = Hotbar.SLOTS * bslot + (Hotbar.SLOTS - 1) * 6
		for i, b in barSlots do
			b.AnchorPoint = Vector2.new(0.5, 1)
			b.Position = UDim2.new(0.5, -totalW / 2 + (i - 1) * (bslot + 6) + bslot / 2, 1, -6)
			b.Size = UDim2.fromOffset(bslot, bslot)
		end
		local upperH = sh - barBoxH - 24 - 12
		info.Position = UDim2.fromOffset(16, 14)
		info.Size = UDim2.new(1, -32, 0, upperH)
		local ic = 64
		infoIcon.Position = UDim2.fromOffset(0, 0)
		infoIcon.Size = UDim2.fromOffset(ic, ic)
		infoTitle.TextSize = 21
		infoTitle.Position = UDim2.fromOffset(ic + 10, 2)
		infoTitle.Size = UDim2.new(1, -(ic + 10), 0, 28)
		infoKind.Position = UDim2.fromOffset(ic + 10, 32)
		infoKind.Size = UDim2.new(1, -(ic + 10), 0, 16)
		local btnH = 40
		actions.AnchorPoint = Vector2.new(0, 1)
		actions.Position = UDim2.fromScale(0, 1)
		actions.Size = UDim2.new(1, 0, 0, btnH)
		dropOne.Position = UDim2.fromScale(0, 0)
		dropOne.Size = UDim2.new(0.5, -3, 1, 0)
		dropAll.Position = UDim2.new(0.5, 3, 0, 0)
		dropAll.Size = UDim2.new(0.5, -3, 1, 0)
		removeBtn.Position = UDim2.fromScale(0, 0)
		removeBtn.Size = UDim2.fromScale(1, 1)
		for _, b in { dropOne, dropAll, removeBtn } do
			b.TextSize = 15
		end
		infoScroll.Position = UDim2.fromOffset(0, ic + 8)
		infoScroll.Size = UDim2.new(1, 0, 1, -(ic + 8 + btnH + 8))
		infoText.TextSize = 15
	end
	container:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	render = function()
		if ctx and ctx.filter then
			filter = ctx.filter
			ctx.filter = nil
		end
		layout()
		for f, b in chips do
			UiKit.tab(b, f == filter)
		end
		Ui.clear(list)
		table.clear(slots)
		items = {}
		allItems = collect()
		for _, it in allItems do
			if not it.equip and (filter == "All" or it.kind == filter) then
				table.insert(items, it)
			end
		end
		if ctx and ctx.sub then
			ctx.sub(string.format("%d items", #items))
		end
		-- caselle vuote fino a riempire tutta la griglia visibile: sembra un inventario vero
		local cols = math.max(1, math.floor((list.AbsoluteSize.X / uiScale() - 10 + GAP) / (CELL + GAP)))
		local rowsShown = math.max(2, math.floor((list.AbsoluteSize.Y / uiScale() + GAP) / (CELL + GAP)))
		local total = math.max(cols * rowsShown, math.ceil((#items + 1) / cols) * cols)
		local inBar: { [string]: number } = {}
		for i, t in Hotbar.layout(player) do
			inBar[t.Name] = i
		end
		for i = 1, total do
			local it = items[i]
			local slot = Instance.new("TextButton")
			slot.Name = "Casella" .. i
			slot.Text = ""
			slot.AutoButtonColor = it ~= nil
			slot.LayoutOrder = i
			slot.Parent = list
			-- cornice sottile (Mirko 16/10: "le cornici delle caselle sono troppo grosse")
			slot:SetAttribute("CorniceScala", THIN_SLOT)
			if it then
				UiKit.card(slot, it.key == selectedKey)
				UiKit.slot(slot, if it.key == selectedKey then "selected" else "normal")
			elseif not UiKit.slot(slot, "disabled") then
				-- casella vuota: incassata, appena accennata
				slot.BackgroundColor3 = UiKit.INK
				slot.BackgroundTransparency = 0.55
				UiKit.edge(slot, UiKit.LINE, 1, 0.9)
			end
			table.insert(slots, slot)
			if not it then
				continue
			end
			local item = it :: Item
			-- icona al centro dello spazio libero della cornice (prima era spostata in alto)
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.5)
			icon.Size = UDim2.fromScale(0.64, 0.64)
			icon.ZIndex = 3
			icon.Parent = slot
			if item.tool then
				toolIcon(icon, item.tool, nil)
			elseif item.id and Theme.ITEM_ICONS[item.id] then
				Theme.itemIcon(icon, item.id, item.model)
			else
				Theme.assetPreview(icon, item.asset, item.model)
			end
			-- caselle piccole come in Diablo IV: niente nome (sta nella scheda a destra), solo il
			-- numero in basso a destra
			if item.drop then
				local count = UiKit.label(slot, tostring(item.count), "stat", 13)
				count.TextColor3 = UiKit.TEXT
				count.TextStrokeTransparency = 0.2
				count.AnchorPoint = Vector2.new(1, 1)
				count.Position = UDim2.new(1, -7, 1, -5)
				count.Size = UDim2.fromOffset(40, 16)
				count.TextXAlignment = Enum.TextXAlignment.Right
				count.ZIndex = 5
			end
			-- attrezzo gia' nella barra: numero della casella in alto a sinistra
			if item.tool and inBar[item.tool] then
				local tag = UiKit.label(slot, tostring(inBar[item.tool]), "stat", 12)
				tag.TextColor3 = UiKit.INK
				tag.BackgroundColor3 = UiKit.ACCENT
				tag.BackgroundTransparency = 0
				tag.TextXAlignment = Enum.TextXAlignment.Center
				tag.Position = UDim2.fromOffset(6, 6)
				tag.Size = UDim2.fromOffset(15, 15)
				tag.ZIndex = 5
			end

			-- clic = scegli; trascina (mouse) o tieni premuto (dito) = sposta
			slot.InputBegan:Connect(function(input)
				local touch = input.UserInputType == Enum.UserInputType.Touch
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and not touch then
					return
				end
				local from = input.Position
				local done = false
				local watch: RBXScriptConnection
				local stop: RBXScriptConnection
				local function close()
					done = true
					watch:Disconnect()
					stop:Disconnect()
				end
				local function begin()
					if done then
						return
					end
					close()
					startDrag(i, slot, input)
				end
				watch = UIS.InputChanged:Connect(function(m)
					if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then
						local moved = (m.Position - from).Magnitude
						if not touch and moved > 8 then
							begin()
						elseif touch and moved > 14 then
							close() -- il dito scorre la lista: niente trascinamento
						end
					end
				end)
				stop = UIS.InputEnded:Connect(function(m)
					if m.UserInputType == input.UserInputType and not done then
						close()
						confirmAll = false
						pickedSlot = nil
						selectedKey = if selectedKey == item.key then nil else item.key
						render()
					end
				end)
				if touch then
					task.delay(0.35, begin)
				end
			end)
		end
		-- EQUIPAGGIAMENTO attorno al personaggio: quello che hai acceso, quello che manca spento
		for _, slotId in EQUIP do
			local b = equipSlots[slotId]
			for _, c in b:GetChildren() do
				if c:IsA("GuiObject") and c.Name ~= "Cornice" and c.Name ~= "Fondo" then
					c:Destroy()
				end
			end
			-- casella del parapendio: la vela che usi (Gear.glider: la migliore che hai)
			local sail = if slotId == "Parapendio" then Gear.glider(player) else nil
			local id = if sail then sail.id else slotId
			local key = "gear:" .. id
			local entry: Item? = nil
			for _, x in allItems do
				if x.key == key then
					entry = x
				end
			end
			local owned = entry ~= nil and not entry.missing
			b:SetAttribute("CorniceScala", THIN_SLOT)
			UiKit.card(b, selectedKey == key)
			if not UiKit.slot(b, if selectedKey == key then "selected" elseif owned then "normal" else "disabled") then
				b.BackgroundColor3 = UiKit.INK
				b.BackgroundTransparency = 0.4
			end
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.5)
			icon.Size = UDim2.fromScale(0.64, 0.64)
			icon.ZIndex = 5
			icon.Parent = b
			Theme.itemIcon(icon, id, entry and entry.model)
			if not owned then
				-- sagoma spenta: si vede cosa manca
				icon.ImageTransparency = 0.72
				icon.ImageColor3 = Color3.fromRGB(150, 150, 160)
			end
		end
		-- statistiche (attacco, scudo, stamina, salute + draghi e vette)
		local stats = ProfileUI.stats()
		local okData, dd = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("DragonData") or "{}") :: string)
		local dragons = if okData and type(dd) == "table" then #(dd.dragons or {}) else 0
		local extra = {
			{ name = "DRAGONS", value = dragons, color = Theme.PURPLE },
			{ name = "SUMMITS", value = (player:GetAttribute("Summits") or 0) :: number, color = Theme.TEAL },
		}
		for i, r in statRows do
			local st = stats[i] or extra[i - #stats]
			r.key.Text = if st then st.name else ""
			r.key.TextColor3 = if st then st.color else UiKit.MUTED
			r.value.Text = if st then tostring(math.floor(st.value + 0.5)) else ""
		end
		-- monete, pietre del drago, chiodi
		local function fmt(n: number): string
			local t = tostring(math.floor(n))
			return ((t:reverse():gsub("(%d%d%d)", "%1,"):reverse()):gsub("^,", ""))
		end
		purseItems[1].text.Text = fmt((player:GetAttribute("Coins") or 0) :: number)
		purseItems[2].text.Text = fmt(if okData and type(dd) == "table" then tonumber(dd.stones) or 0 else 0)
		purseItems[3].text.Text = fmt((player:GetAttribute("Pitons") or 0) :: number)
		avatar.rebuild()
		showInfo()
	end
	for _, slotId in EQUIP do
		equipSlots[slotId].Activated:Connect(function()
			local sail = if slotId == "Parapendio" then Gear.glider(player) else nil
			local key = "gear:" .. (if sail then sail.id else slotId)
			confirmAll = false
			pickedSlot = nil
			selectedKey = if selectedKey == key then nil else key
			render()
		end)
	end
	-- la barra cambia anche fuori dal menu (attrezzo comprato, respawn): si ridisegna
	player:GetAttributeChangedSignal("HotbarOrder"):Connect(function()
		if container.Visible then
			render()
		end
	end)
	local function watchTools(parent: Instance?)
		if not parent then
			return
		end
		for _, ev in { parent.ChildAdded, parent.ChildRemoved } do
			ev:Connect(function(c)
				if c:IsA("Tool") and container.Visible then
					task.defer(render)
				end
			end)
		end
	end
	watchTools(player:FindFirstChildOfClass("Backpack"))
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		watchTools(player:FindFirstChildOfClass("Backpack"))
		watchTools(character)
	end)
	watchTools(player.Character)
	return render
end
-- Menu unico (Mirko 15/10, schizzo "foto 1"): il tasto in alto a sinistra non apre piu' la fila
-- di sei pulsanti ma una sola finestra. A sinistra la colonna delle schede a parallelogramma
-- (la punta verso il centro): quella sotto il mouse o aperta esce verso destra, le altre si
-- ritirano a sinistra. A destra la pagina: all'apertura il profilo (record, personaggio 3D e
-- statistiche), poi quella della scheda scelta. Fondo scuro stile Black Ops 2.
local TABS = {
	{ key = "Dragons", label = "DRAGONS", icon = "icon_dragons", color = Theme.PURPLE, keyName = "G", title = "Dragons" },
	{ key = "Store", label = "SHOP", icon = "icon_shop", color = Theme.ACCENT, keyName = "B", title = "Shop" },
	{ key = "Teleport", label = "TRAVEL", icon = "icon_teleport", color = Theme.BLUE, keyName = "T", title = "Travel" },
	{ key = "Crafting", label = "CRAFTING", icon = "icon_crafting", color = Theme.TEAL, keyName = "N", title = "Crafting" },
	{ key = "Backpack", label = "INVENTORY", icon = "icon_backpack", color = Theme.ORANGE, keyName = "I", title = "Inventory" },
	{ key = "Upgrades", label = "UPGRADES", icon = "icon_settings", color = Theme.GOOD, keyName = "U", title = "Upgrades" },
}
local KEYS = {
	Dragons = { Enum.KeyCode.G }, Store = { Enum.KeyCode.B }, Teleport = { Enum.KeyCode.T },
	Crafting = { Enum.KeyCode.N }, Backpack = { Enum.KeyCode.I, Enum.KeyCode.V }, Upgrades = { Enum.KeyCode.U },
}

function MainMenu.start()
	local gui = Ui.screen("MainMenu")
	local column, window = Ui.node(gui, "Column"), Ui.node(gui, "Window")
	-- la vecchia fila di pulsanti resta nel modello ma spenta
	column.Visible = false
	column:GetPropertyChangedSignal("Visible"):Connect(function()
		column.Visible = false
	end)
	player:SetAttribute("UiCollapsed", false)
	local hudGui = player.PlayerGui:FindFirstChild("ClimbHUD")
	if hudGui and hudGui:IsA("ScreenGui") then
		gui.DisplayOrder = math.max(gui.DisplayOrder, hudGui.DisplayOrder + 1)
	end

	-- APRI-MENU del gioco: uno solo, in basso a sinistra della barra degli attrezzi (PC e
	-- telefono). Prima c'era in alto a sinistra un cerchio col rombo e una pillola "≡": copiavano
	-- per errore i controlli veri di Roblox dello schizzo di Mirko (Mirko 16/10)
	local opener = Instance.new("TextButton")
	opener.Name = "ApriMenu"
	opener.Text = ""
	opener.BackgroundTransparency = 1
	opener.AutoButtonColor = false
	opener:SetAttribute("UiNative", true)
	opener.ZIndex = 20
	opener.Parent = gui
	local openerShape = Slant.new(opener, UiKit.PANEL, 0.12, 12, "right")
	openerShape.Size = UDim2.fromScale(1, 1)
	Slant.setZ(openerShape, 20)
	local openerMark = Instance.new("Frame")
	openerMark.Name = "Segno"
	openerMark.BorderSizePixel = 0
	openerMark.BackgroundColor3 = UiKit.ACCENT
	openerMark.Size = UDim2.new(0, 3, 1, 0)
	openerMark.ZIndex = 22
	openerMark.Parent = opener
	local openerIcon = Instance.new("ImageLabel")
	openerIcon.BackgroundTransparency = 1
	openerIcon.AnchorPoint = Vector2.new(0, 0.5)
	openerIcon.ZIndex = 22
	openerIcon.Parent = opener
	Ui.asset(openerIcon, "icon_dragons")
	local openerText = UiKit.label(opener, "MENU", "button")
	openerText.ZIndex = 22
	local openerKey = UiKit.label(opener, "M", "status")
	openerKey.TextXAlignment = Enum.TextXAlignment.Center
	openerKey.ZIndex = 22
	opener.MouseEnter:Connect(function()
		Slant.paint(openerShape, UiKit.RAISED, 0.05)
	end)
	opener.MouseLeave:Connect(function()
		Slant.paint(openerShape, UiKit.PANEL, 0.12)
	end)

	-- FINESTRA: angoli vivi, bordo sottile e tacche; il fondo scuro (carbone, fumo, brace) e'
	-- traslucido, cosi' dietro si intravede ancora il mondo (come il riferimento di BO3)
	window.Visible = false
	window.BackgroundTransparency = 1
	window.ClipsDescendants = true
	local surface = window:FindFirstChild("AssetSurface")
	if surface and surface:IsA("GuiObject") then
		surface.Visible = false
	end
	local oldTint = window:FindFirstChild("Tinta")
	if oldTint then
		oldTint:Destroy()
	end
	local windowLimit = window:FindFirstChild("SizeLimit")
	if windowLimit then
		windowLimit:Destroy()
	end
	for _, c in window:GetChildren() do
		if c:IsA("UICorner") or (c:IsA("UIStroke") and c.Name ~= "Bordo") then
			c:Destroy()
		end
	end
	-- cornice di Codex attorno alla finestra (sotto tutto); fondo, fumo e velo stanno in un
	-- riquadro interno, cosi' l'oro del bordo resta visibile. Lo spessore lo decide layout()
	UiKit.Cornici.apply(window, "frame_panel", { border = 14 })
	local inner = Instance.new("Frame")
	inner.Name = "Interno"
	inner.BackgroundTransparency = 1
	inner.BorderSizePixel = 0
	inner.ClipsDescendants = true
	inner.ZIndex = 1
	inner.Parent = window
	local smoke = UiGlow.darkBackground(inner, Theme.EMBER, 22)
	-- fondo quasi pieno: dietro il menu il mondo si intuisce appena (prima 0.3: i draghi che
	-- passavano dietro disturbavano la lettura, Mirko 16/10)
	smoke.BackgroundTransparency = 0.08
	UiKit.edge(window, UiKit.LINE, 1, 1)
	-- velo a sinistra: la colonna delle schede resta leggibile anche col mondo dietro
	local veil = Instance.new("Frame")
	veil.Name = "Velo"
	veil.BorderSizePixel = 0
	veil.BackgroundColor3 = UiKit.INK
	veil.Size = UDim2.fromScale(0.55, 1)
	veil.ZIndex = 1
	veil.Parent = inner
	local vg = Instance.new("UIGradient")
	vg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.45, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	vg.Parent = veil
	local bg = window.Background
	bg.Parent = inner
	bg.Visible = true
	bg.ScaleType = Enum.ScaleType.Crop
	bg.ZIndex = 1
	-- un po' piu' grande della finestra: si sposta appena col mouse (parallasse)
	bg.AnchorPoint = Vector2.new(0.5, 0.5)
	bg.Position = UDim2.fromScale(0.5, 0.5)
	bg.Size = UDim2.fromScale(1.08, 1.08)
	if Ui.asset(bg, "bg_menu_dark") then
		bg.ImageTransparency = 0.35
	else
		Ui.asset(bg, "bg_menu")
		bg.ImageTransparency = 0.84
	end
	window.Title.Visible = false

	-- intestazione: icona e titolo della pagina, sottotitolo, monete, X
	local head = Theme.frame(window, Color3.new(), 1)
	head.Name = "Intestazione"
	head.ZIndex = 5
	head.ClipsDescendants = false
	-- barra del titolo di Codex (terminali ornati ai lati)
	UiKit.Cornici.apply(head, "frame_panel_header")
	local headIcon = Instance.new("ImageLabel")
	headIcon.BackgroundTransparency = 1
	headIcon.ZIndex = 6
	headIcon.Parent = head
	local headTitle = UiKit.label(head, "", "title")
	headTitle.ZIndex = 6
	local headSub = UiKit.label(head, "", "section")
	headSub.ZIndex = 6
	local coinsBox = Theme.frame(head, Color3.new(), 1)
	coinsBox.Name = "MoneteFinestra"
	coinsBox.ZIndex = 6
	coinsBox.ClipsDescendants = false
	local coinIcon = Instance.new("ImageLabel")
	coinIcon.BackgroundTransparency = 1
	coinIcon.AnchorPoint = Vector2.new(0, 0.5)
	coinIcon.Position = UDim2.fromScale(0, 0.5)
	coinIcon.Size = UDim2.fromOffset(30, 30)
	coinIcon.ZIndex = 7
	coinIcon.Parent = coinsBox
	Ui.asset(coinIcon, "icon_coin")
	local coinsLabel = UiKit.label(coinsBox, "0", "stat", 24)
	coinsLabel.Position = UDim2.new(0, 38, 0, 0)
	coinsLabel.Size = UDim2.new(1, -38, 1, 0)
	coinsLabel.ZIndex = 7
	-- chiudi: pulsante nostro (quello del modello mostrava la sua immagine sotto il testo)
	window.Close.Visible = false
	local close = Instance.new("TextButton")
	close.Name = "Chiudi"
	close.ZIndex = 8
	close.Parent = window
	UiKit.button(close, "secondary")
	close.Text = "CLOSE"
	close.TextSize = 16
	local closeLimit = close:FindFirstChild("SizeLimit")
	if closeLimit then
		closeLimit:Destroy()
	end
	local function fmtCoins(): string
		local s = tostring(math.floor((player:GetAttribute("Coins") or 0) :: number))
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		coinsLabel.Text = fmtCoins()
	end)

	-- COLONNA DELLE SCHEDE (parallelogrammi)
	type Tab = { button: TextButton, shape: Frame, label: TextLabel, icon: ImageLabel, key: TextLabel, def: any }
	local tabs: { [string]: Tab } = {}
	for i, def in TABS do
		local b = Instance.new("TextButton")
		b.Name = "Tab_" .. def.key
		b.Text = ""
		b.BackgroundTransparency = 1
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b:SetAttribute("UiNative", true)
		b.ZIndex = 5
		b.Parent = window
		-- scheda di Codex (parallelogramma con l'obliquo a destra, oro e ferro); il vecchio
		-- parallelogramma disegnato resta solo se l'immagine non c'e'
		local shape = Slant.new(b, Theme.DARK3, 0.15, 26)
		shape.Size = UDim2.fromScale(1, 1)
		Slant.setZ(shape, 5)
		local framed = UiKit.Cornici.apply(b, "frame_tab_normal") ~= nil
		shape.Visible = not framed
		local strip = Theme.frame(if framed then b else shape, def.color, 0)
		strip.Name = "Striscia"
		strip.AnchorPoint = Vector2.new(0, 0.5)
		strip.Size = if framed then UDim2.new(0, 4, 0.56, 0) else UDim2.new(0, 6, 1, 0)
		strip.Position = if framed then UDim2.new(0, 14, 0.5, 0) else UDim2.new(0, 30, 0.5, 0)
		strip.ZIndex = 6
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.ZIndex = 7
		icon.Parent = b
		Ui.asset(icon, def.icon)
		local label = UiKit.label(b, def.label, "button", 21)
		label.ZIndex = 7
		local key = UiKit.label(b, def.keyName, "status")
		key.TextXAlignment = Enum.TextXAlignment.Right
		key.ZIndex = 7
		tabs[def.key] = { button = b, shape = shape, label = label, icon = icon, key = key, def = def }
	end

	-- PAGINE: i riquadri del modello (Store, Backpack, Dragons, Crafting, Upgrades) piu' Travel e
	-- il profilo, fatti qui
	local content = window.Content
	content.ZIndex = 4
	content.ClipsDescendants = false
	content.BackgroundTransparency = 1
	-- Sul telefono (circa 354 px di altezza) ogni pagina impilava blocchi fissi pensati per 450+
	-- px e la finestra diventava una striscia (Mirko 16/10). Ora la pagina ha un'altezza minima
	-- e, se non ci sta, si scorre in verticale invece di schiacciarsi
	local pageScroll = Instance.new("ScrollingFrame")
	pageScroll.Name = "Scorrimento"
	pageScroll.BackgroundTransparency = 1
	pageScroll.BorderSizePixel = 0
	pageScroll.ScrollBarThickness = 4
	pageScroll.ScrollBarImageColor3 = UiKit.LINE
	pageScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	pageScroll.ElasticBehavior = Enum.ElasticBehavior.Never
	pageScroll.ZIndex = 4
	pageScroll.Parent = window
	content.Parent = pageScroll
	content.Position = UDim2.fromOffset(0, 0)
	local function page(name: string): Frame
		local f = content:FindFirstChild(name) :: Frame?
		if not f then
			local nf = Instance.new("Frame")
			nf.Name = name
			nf.BackgroundTransparency = 1
			nf.Size = UDim2.fromScale(1, 1)
			nf.Visible = false
			nf.Parent = content
			f = nf
		end
		return f :: Frame
	end
	page("Teleport")
	page("Home")
	local PAGES = { "Home", "Store", "Backpack", "Dragons", "Crafting", "Upgrades", "Teleport" }
	-- impaginazione interna dello Shop (schede Buy/Sell/Robux in alto, carte sotto)
	local store = content.Store
	store.Tabs.Size = UDim2.new(1, 0, 0, 44)
	for _, b in store.Tabs:GetChildren() do
		if b:IsA("GuiObject") then
			b.Size = UDim2.new(1 / 3, -8, 1, 0)
			local lim = b:FindFirstChild("SizeLimit")
			if lim then
				lim:Destroy()
			end
			if b:IsA("TextButton") then
				Ui.text(b, 18, true)
			end
		end
	end
	store.Tabs.Position = UDim2.fromOffset(0, 0)
	store.List.Position = UDim2.fromOffset(0, 54)
	store.List.Size = UDim2.new(1, 0, 1, -54)
	rows(content.Upgrades.List)

	-- esito delle azioni ("Missing materials", "Waypoint set"...): un avviso breve SOPRA la pagina
	-- in alto al centro, che sparisce da solo. Prima era una riga fissa in fondo che rubava 30 px
	-- di altezza (sul telefono un decimo dello schermo) e finiva sotto i pulsanti
	window.Status.Visible = false
	window.Status:GetPropertyChangedSignal("Visible"):Connect(function()
		window.Status.Visible = false
	end)
	local toast = Instance.new("TextLabel")
	toast.Name = "Avviso"
	toast.ZIndex = 30
	toast.Parent = window
	UiKit.text(toast, "button", 17)
	toast:SetAttribute("UiNative", true)
	toast.BackgroundColor3 = Color3.fromRGB(10, 13, 20)
	toast.BackgroundTransparency = 0.02
	toast.BorderSizePixel = 0
	toast.TextWrapped = true
	toast.Visible = false
	UiKit.edge(toast, UiKit.LINE, 2, 0.2)
	-- avviso di Codex attorno al riquadro (filo d'oro con le punte)
	if UiKit.Cornici.apply(toast, "frame_toast", { mode = "outset", z = 2 }) then
		UiKit.edge(toast, UiKit.LINE, 2, 1)
	end
	local toastPad = Instance.new("UIPadding")
	toastPad.PaddingLeft, toastPad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	toastPad.Parent = toast
	local toastSerial = 0
	local function status(message: string, ok: boolean)
		toastSerial += 1
		local serial = toastSerial
		toast.Text = message
		toast.TextColor3 = if ok then UiKit.GOOD else UiKit.BAD
		local stroke = toast:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = toast.TextColor3
		end
		toast.Visible = message ~= ""
		task.delay(3.5, function()
			if serial == toastSerial then
				toast.Visible = false
			end
		end)
	end

	local refreshers: { [string]: () -> () } = {}
	local current: string? = nil
	local hovered: string? = nil
	local open: (string?, string?) -> ()
	local ctx = {
		filter = nil :: string?,
		sub = function(text: string)
			headSub.Text = text
		end,
		open = function(name: string, filter: string?)
			open(name, filter)
		end,
	}

	-- schede: quella attiva (sotto il mouse o aperta) esce, le altre si ritirano a sinistra
	local tabMetrics = { x = 0, y = 0, w = 240, h = 64, gap = 10 }
	local function styleTabs(animate: boolean)
		local active = hovered or current
		-- prospettiva (come il menu di Black Ops III): le schede piu' lontane da quella attiva
		-- rientrano, rimpiccioliscono e si scuriscono, come se andassero indietro nello spazio
		local activeIndex = 1
		for i, def in TABS do
			if def.key == active then
				activeIndex = i
			end
		end
		for i, def in TABS do
			local t = tabs[def.key]
			local on = def.key == active
			local open_ = def.key == current
			local hov = on and not open_
			-- (Mirko 16/10: le schede lontane non devono sparire: restano piene e leggibili, la
			-- profondita' la danno solo grandezza e rientro)
			local far = if active then math.abs(i - activeIndex) else 0
			local x = if open_ then 12 elseif hov then 8 else 2 + far * 3
			local y = tabMetrics.y + (i - 1) * (tabMetrics.h + tabMetrics.gap)
			local goal = UDim2.fromOffset(tabMetrics.x + x, y)
			t.button.Size = UDim2.fromOffset(tabMetrics.w, tabMetrics.h)
			if animate then
				game:GetService("TweenService"):Create(t.button, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Position = goal }):Play()
			else
				t.button.Position = goal
			end
			local framed = t.button:FindFirstChild("Cornice") ~= nil
			if framed then
				UiKit.Cornici.apply(t.button, if open_ then "frame_tab_selected" elseif hov then "frame_tab_hover" else "frame_tab_normal")
			else
				Slant.paint(t.shape, if open_ then def.color elseif hov then UiKit.RAISED else UiKit.PANEL, if open_ then 0 elseif hov then 0.05 else math.min(0.5, 0.2 + far * 0.06))
			end
			local scale = t.button:FindFirstChild("Profondita") :: UIScale?
			if not scale then
				local ns = Instance.new("UIScale")
				ns.Name = "Profondita"
				ns.Parent = t.button
				scale = ns
			end
			-- quella scelta e' piu' vicina, le spente piu' lontane
			;(scale :: UIScale).Scale = if open_ then 1.03 elseif hov then 1 else math.max(0.86, 0.97 - far * 0.025)
			t.icon.ImageTransparency = if framed or open_ or hov then 0 else math.min(0.6, 0.25 + far * 0.07)
			local strip = (t.button:FindFirstChild("Striscia") or t.shape:FindFirstChild("Striscia")) :: Frame?
			if strip then
				strip.BackgroundColor3 = def.color
				strip.BackgroundTransparency = if framed or open_ or hov then 0 else 0.45
			end
			local dark = not framed and open_ and (def.key == "Store" or def.key == "Upgrades" or def.key == "Crafting")
			t.label.TextColor3 = if dark then Color3.fromRGB(30, 22, 6)
				elseif framed and open_ then Color3.fromRGB(255, 222, 140)
				elseif framed or open_ or hov then UiKit.TEXT
				else UiKit.MUTED
			t.label.TextStrokeTransparency = if framed then 0.6 else 1
			t.key.TextColor3 = if dark then Color3.fromRGB(60, 46, 20) else UiKit.DIM
		end
	end
	for _, def in TABS do
		local t = tabs[def.key]
		t.button.MouseEnter:Connect(function()
			hovered = def.key
			styleTabs(true)
		end)
		t.button.MouseLeave:Connect(function()
			if hovered == def.key then
				hovered = nil
				styleTabs(true)
			end
		end)
		t.button.MouseButton1Down:Connect(function()
			local sc = t.button:FindFirstChild("Profondita") :: UIScale?
			if sc then
				sc.Scale = 0.95
			end
		end)
		t.button.Activated:Connect(function()
			-- di nuovo sulla scheda aperta: si torna al profilo
			open(if current == def.key then "Home" else def.key)
		end)
	end

	local function titleFor(name: string): (string, string, Color3)
		if name == "Home" then
			return "Profile", "icon_quest", Theme.ACCENT
		end
		for _, def in TABS do
			if def.key == name then
				return def.title, def.icon, def.color
			end
		end
		return name, "", Theme.ACCENT
	end

	open = function(name: string?, filter: string?)
		if not name then
			window.Visible = false
			current = nil
			hovered = nil
			gui:SetAttribute("MenuOpen", false)
			return
		end
		local pageName = name :: string
		current = if pageName == "Home" then nil else pageName
		ctx.filter = filter
		-- il tutorial vuole sapere quando apri una scheda (server/Tutorial)
		local opened = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("MenuOpened")
		if opened and pageName ~= "Home" then
			(opened :: RemoteEvent):FireServer(pageName)
		end
		local title, icon, tone = titleFor(pageName)
		headTitle.Text = title
		headSub.Text = ""
		-- il sottotitolo subito dopo il titolo ("Crafting  8 items")
		task.defer(function()
			local k = (gui:FindFirstChild("ScalaUI") :: UIScale?)
			local scale = if k and k.Scale > 0 then k.Scale else 1
			headSub.Position = UDim2.fromOffset(headTitle.Position.X.Offset + headTitle.TextBounds.X / scale + 22, headSub.Position.Y.Offset)
		end)
		Ui.asset(headIcon, icon)
		headIcon.ImageColor3 = Color3.new(1, 1, 1)
		headTitle.TextColor3 = Theme.TEXT
		local _ = tone
		coinsLabel.Text = fmtCoins()
		status("", true)
		for _, n in PAGES do
			page(n).Visible = n == pageName
		end
		local shown = page(pageName)
		local fit = (ctx :: any).fit
		if fit then
			fit() -- (fitPage e' definita piu' sotto, con l'impaginazione)
		end
		shown.Position = UDim2.fromOffset(18, 0)
		game:GetService("TweenService"):Create(shown, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
		pageScroll.CanvasPosition = Vector2.zero
		if not refreshers[pageName] then
			local c = page(pageName)
			refreshers[pageName] = if pageName == "Store" then mountShop(c, status)
				elseif pageName == "Backpack" then mountInventory(c, status, ctx)
				elseif pageName == "Dragons" then DragonUI.mount(c, status)
				elseif pageName == "Upgrades" then UpgradeUI.mount(c, status, ctx)
				elseif pageName == "Teleport" then TravelUI.mount(c, status, ctx)
				elseif pageName == "Home" then ProfileUI.mount(c, ctx)
				else CraftingUI.mount(c, status, ctx)
		end
		local wasOpen = window.Visible
		gui:SetAttribute("MenuOpen", true)
		window.Visible = true
		styleTabs(wasOpen)
		refreshers[pageName]()
		if pageName == "Dragons" then
			local data = player:GetAttribute("DragonData")
			headSub.Text = if type(data) == "string" then "Your dragons and your nest" else ""
		elseif pageName == "Store" then
			headSub.Text = "Buy gear, sell ores and eggs"
		elseif pageName == "Home" then
			headSub.Text = player.DisplayName
		end
		if not wasOpen then
			Ui.open(window)
		end
	end
	-- una pagina puo' chiudere il menu mettendo MenuOpen a false (es. Ride nel menu draghi)
	gui:GetAttributeChangedSignal("MenuOpen"):Connect(function()
		if gui:GetAttribute("MenuOpen") ~= true and window.Visible then
			open(nil)
		end
	end)
	opener.Activated:Connect(function()
		-- mentre si spostano i tasti del telefono il tasto si trascina, non apre il menu
		if (require(script.Parent.ClientState) :: any).editingControls then
			return
		end
		if window.Visible then
			open(nil)
		else
			open("Home")
		end
	end)
	-- a menu aperto le schermate del gioco che stanno sopra la finestra si spengono (il tasto Z
	-- del drago e i pulsanti admin coprivano Close e il pulsante di Upgrades sul telefono)
	local hiddenWhileOpen: { [ScreenGui]: boolean } = {}
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		opener.Visible = not window.Visible
		if window.Visible then
			for _, n in { "CombatHUD", "AdminButtons" } do
				local g = player.PlayerGui:FindFirstChild(n)
				if g and g:IsA("ScreenGui") and g.Enabled then
					hiddenWhileOpen[g] = true
					g.Enabled = false
				end
			end
		else
			for g in hiddenWhileOpen do
				if g.Parent then
					g.Enabled = true
				end
			end
			table.clear(hiddenWhileOpen)
		end
	end)
	close.Activated:Connect(function()
		open(nil)
	end)
	-- altri script (e le prove da Studio) aprono una pagina con l'attributo ApriPagina
	-- ("Home", "Crafting", "Teleport"... oppure "" per chiudere)
	gui:GetAttributeChangedSignal("ApriPagina"):Connect(function()
		local v = gui:GetAttribute("ApriPagina")
		if type(v) == "string" then
			open(if v == "" then nil else v)
		end
	end)
	-- tasti: la lettera della scheda la apre (di nuovo: chiude), M apre il profilo
	for key, codes in KEYS do
		CAS:BindAction("Menu" .. key, function(_, state)
			if state == Enum.UserInputState.Begin then
				if window.Visible and current == key then
					open(nil)
				else
					open(key)
				end
			end
			return Enum.ContextActionResult.Pass
		end, false, table.unpack(codes))
	end
	CAS:BindAction("MenuProfilo", function(_, state)
		if state == Enum.UserInputState.Begin then
			if window.Visible and current == nil then
				open(nil)
			else
				open("Home")
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.M)

	-- impaginazione (pixel logici, UiView.fitScale)
	local compactNow = false
	-- altezza della pagina: almeno quella visibile, almeno 440 sul telefono, e quanto chiede la
	-- pagina aperta (attributo AltezzaMinima: le pagine strette mettono la scheda sotto la griglia)
	local pageBox = { w = 0, h = 0, min = 0 }
	local function fitPage()
		local shownPage = content:FindFirstChild(current or "Home")
		local want = if shownPage then (shownPage:GetAttribute("AltezzaMinima") or 0) :: number else 0
		local contentH = math.max(pageBox.h, pageBox.min, want)
		local scrolls = contentH > pageBox.h + 1
		content.Position = UDim2.fromOffset(0, 0)
		content.Size = UDim2.fromOffset(pageBox.w - (if scrolls then 8 else 0), contentH)
		pageScroll.CanvasSize = UDim2.fromOffset(0, contentH)
		pageScroll.ScrollingEnabled = scrolls
	end
	ctx.fit = fitPage
	-- APRI-MENU nell'angolo a sinistra (Mirko 16/10: non vicino alla barra degli attrezzi, che
	-- cosi' resta centrata). Computer: in basso a sinistra. Telefono: sul bordo sinistro a meta'
	-- altezza (in basso a sinistra c'e' il joystick); col tasto ⚙ dei comandi si sposta come gli
	-- altri pulsanti e la posizione si salva insieme a loro (ControlsLayout, voce MenuFrac)
	-- il tasto si sposta come gli altri elementi dell'HUD (client/HudLayout: tasto ⚙, anche sul
	-- computer); la posizione si salva in ControlsLayout
	local HudLayout = require(script.Parent.HudLayout)
	local function placeOpener()
		local w, h = if compactNow then 62 else 136, 50
		if Ui.touch() then
			Ui.px(opener, 0, 8, 0.54, 0, w, h, 0, 0.5)
		else
			Ui.px(opener, 0, 12, 1, -12, w, h, 0, 1)
		end
		HudLayout.place("Menu", opener)
		Ui.px(openerIcon, 0, if compactNow then 10 else 12, 0.5, 0, 30, 30, 0, 0.5)
		openerText.Visible = not compactNow
		Ui.px(openerText, 0, 50, 0, 0, 60, h)
		openerKey.Visible = not compactNow and not Ui.touch()
		Ui.px(openerKey, 1, -18, 0, 0, 20, h, 1, 0)
	end
	HudLayout.register("Menu", opener, "MENU")
	HudLayout.onChange(placeOpener)
	placeOpener()
	-- UNA sola impaginazione (docs/UI_ADATTAMENTO.md): la scala unica di UiView porta ogni schermo
	-- a un'area logica di almeno 1280x540 (telefono S24 Ultra: 1362x540 a scala 0,654), quindi
	-- finestra, schede e pagine hanno le stesse misure sul telefono e sul computer. Prima c'erano
	-- i rami compact/short e sul telefono la finestra usciva dallo schermo (Mirko 16/10)
	Ui.viewportChanged(function(vp)
		local logical = Ui.fitScale(gui, vp)
		UiKit.setScale((gui:GetAttribute("ScalaVera") or 1) :: number)
		-- solo schermi in verticale (area logica stretta): niente telefono in orizzontale
		local compact = Ui.compact(vp)
		gui:SetAttribute("ShortUI", false)
		compactNow = compact
		UiKit.compact = compact
		placeOpener()
		-- finestra: tutto lo spazio utile (la ScreenGui ha gia' tolto la barra di Roblox)
		local w = math.min(1260, logical.X - 20)
		local h = math.min(logical.Y - 16, 760)
		Ui.px(window, 0.5, 0, 0.5, 0, w, h, 0.5, 0.5)
		local headH = 56
		-- bordo della cornice: il fondo scuro sta dentro
		local border = 14
		UiKit.Cornici.apply(window, "frame_panel", { border = border })
		Ui.px(inner, 0, border, 0, border, w - 2 * border, h - 2 * border)
		Ui.px(head, 0, 0, 0, 0, w, headH)
		Ui.px(headIcon, 0, 18, 0, 9, headH - 18, headH - 18)
		Ui.px(headTitle, 0, headH + 8, 0, 0, 280, headH)
		UiKit.text(headTitle, "title", 30)
		headTitle.TextXAlignment = Enum.TextXAlignment.Left
		Ui.px(headSub, 0, headH + 10 + 160, 0, 0, 420, headH)
		UiKit.text(headSub, "section", 16)
		headSub.TextXAlignment = Enum.TextXAlignment.Left
		local closeW = 96
		Ui.px(close, 1, -12, 0, 9, closeW, headH - 18, 1, 0)
		local coinsW = 190
		Ui.px(coinsBox, 1, -(closeW + 26), 0, 0, coinsW, headH, 1, 0)
		UiKit.text(coinsLabel, "stat", 22)
		coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
		-- schede: colonna a parallelogrammi; sei schede sempre tutte dentro la finestra (prima
		-- sul telefono UPGRADES finiva sotto il bordo)
		local colW = if compact then 150 else 232
		local tabsTop = headH + 8
		local gap = 8
		local avail = h - tabsTop - 14
		local tabH = math.clamp(math.floor((avail - 5 * gap) / 6), 36, 64)
		tabMetrics.x, tabMetrics.y, tabMetrics.w, tabMetrics.h, tabMetrics.gap = 0, tabsTop, colW + 14, tabH, gap
		for _, def in TABS do
			local t = tabs[def.key]
			t.button.Visible = true
			local isz = math.floor(tabH * 0.56)
			Ui.px(t.icon, 0, 40, 0.5, 0, isz, isz, 0, 0.5)
			Ui.px(t.label, 0, 48 + isz, 0, 0, colW - isz - 56, tabH)
			UiKit.text(t.label, "button", 19)
			t.label.TextXAlignment = Enum.TextXAlignment.Left
			Ui.px(t.key, 1, -40, 0, 0, 24, tabH, 1, 0)
			t.key.Visible = not Ui.touch()
		end
		headSub.Visible = true
		styleTabs(false)
		-- pagina: mai piu' alta dello spazio visibile (scorrono solo le liste dentro)
		local cx = colW + 38
		local pageW = w - cx - 16
		local pageH = h - tabsTop - 16
		Ui.px(pageScroll, 0, cx, 0, tabsTop, pageW, pageH)
		pageBox.w, pageBox.h, pageBox.min = pageW, pageH, 0
		fitPage()
		toast.AnchorPoint = Vector2.new(0.5, 0)
		toast.Position = UDim2.new(0, cx + pageW / 2, 0, tabsTop + 4)
		toast.Size = UDim2.fromOffset(math.min(560, pageW - 40), 40)
	end, gui)

	-- PARALLASSE leggera (solo col mouse, solo a menu aperto): fondo, fumo e pagina si spostano
	-- di poco e a velocita' diverse, come strati a profondita' diverse
	local parallax: RBXScriptConnection? = nil
	local UIS = game:GetService("UserInputService")
	local smokeBase = smoke.Position
	local function stopParallax()
		if parallax then
			parallax:Disconnect()
			parallax = nil
		end
		bg.Position = UDim2.fromScale(0.5, 0.5)
		smoke.Position = smokeBase
	end
	local offset = Vector2.zero
	local function startParallax()
		if parallax or Ui.touch() then
			return
		end
		parallax = game:GetService("RunService").RenderStepped:Connect(function(dt)
			local cam = workspace.CurrentCamera
			if not cam or not window.Visible then
				stopParallax()
				return
			end
			local m = UIS:GetMouseLocation()
			local vs = cam.ViewportSize
			local want = Vector2.new((m.X / vs.X - 0.5) * 2, (m.Y / vs.Y - 0.5) * 2)
			local before = offset
			offset = offset:Lerp(want, math.min(1, dt * 6))
			if (offset - before).Magnitude < 0.0005 then
				return -- fermo: niente lavoro
			end
			bg.Position = UDim2.new(0.5, -offset.X * 16, 0.5, -offset.Y * 10)
			smoke.Position = smokeBase + UDim2.fromOffset(-offset.X * 7, -offset.Y * 4)
		end)
	end
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			startParallax()
		else
			stopParallax()
		end
	end)
	-- caratteri e angoli vivi per tutto quello che c'e' (e ci sara') nella finestra
	UiKit.adopt(window)

	for eventName, tabName in { OpenShop = "Store", OpenCrafting = "Crafting", OpenDragons = "Dragons" } do
		(remotes:WaitForChild(eventName) :: RemoteEvent).OnClientEvent:Connect(function()
			if current ~= tabName then
				open(tabName)
			end
		end)
	end
	local function refreshOpen()
		if not window.Visible then
			return
		end
		local name = current or "Home"
		if refreshers[name] then
			refreshers[name]()
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
