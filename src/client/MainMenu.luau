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
local UiGlow = require(script.Parent.UiGlow)
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
		Ui.tint(c, CARD_TONES[(order - 1) % #CARD_TONES + 1], false, 0.03)
		local fill = c:FindFirstChild("Tinta") :: Frame?
		if fill then
			fill.BackgroundTransparency = 0.25
		end
		Ui.tint(c.Buy, Theme.GOOD, false)
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
-- Zaino: caselle in griglia come un vero inventario (Mirko 15/10: "solo immagini fisse, non puoi
-- spostare item, rimuoverli ne' niente"). Trascini una casella su un'altra per spostarla (sul
-- telefono tieni premuto un attimo), clic per sceglierla: sotto compare la scheda con nome,
-- descrizione e i pulsanti Drop 1 / Drop all. L'ordine si salva (attributo BagOrder, Progression).
-- Il riquadro di testo in cima (monete, casa, pitons...) e' sparito: era tutto nell'HUD.
local function mountInventory(container: Frame, status: (string, boolean) -> ()): () -> ()
	local UIS = game:GetService("UserInputService")
	local HttpService = game:GetService("HttpService")
	local GuiService = game:GetService("GuiService")
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
	list.Position = UDim2.fromOffset(0, 0)
	list.Size = UDim2.new(1, 0, 1, -122)
	-- scheda dell'oggetto scelto, in fondo
	local info = Theme.frame(container, Theme.DARK2, 0.2)
	info.Name = "SchedaOggetto"
	info.AnchorPoint = Vector2.new(0, 1)
	info.Position = UDim2.fromScale(0, 1)
	info.Size = UDim2.new(1, 0, 0, 110)
	Theme.corner(info, 12)
	local infoIcon = Instance.new("ImageLabel")
	infoIcon.BackgroundTransparency = 1
	infoIcon.Position = UDim2.fromOffset(14, 13)
	infoIcon.Size = UDim2.fromOffset(84, 84)
	infoIcon.Parent = info
	local infoTitle = Theme.label(info, "", 22, Theme.TEXT, true)
	infoTitle.Position = UDim2.fromOffset(112, 14)
	infoTitle.Size = UDim2.new(1, -112 - 300, 0, 30)
	local infoText = Theme.label(info, "", 16, Theme.MUTED, false)
	infoText.Position = UDim2.fromOffset(112, 46)
	infoText.Size = UDim2.new(1, -112 - 300, 0, 50)
	infoText.TextYAlignment = Enum.TextYAlignment.Top
	Theme.fitText(infoText, 16, true)
	local dropOne = Theme.button(info, "Drop 1", Theme.BAD, UDim2.fromOffset(130, 52))
	dropOne.AnchorPoint = Vector2.new(1, 0.5)
	dropOne.Position = UDim2.new(1, -152, 0.5, 0)
	local dropAll = Theme.button(info, "Drop all", Theme.BAD, UDim2.fromOffset(130, 52))
	dropAll.AnchorPoint = Vector2.new(1, 0.5)
	dropAll.Position = UDim2.new(1, -12, 0.5, 0)
	for _, b in { dropOne, dropAll } do
		b:SetAttribute("UiNative", true)
		Theme.action(b, "sell")
	end

	type Item = { key: string, title: string, count: number, asset: string, model: Instance?, id: string?, text: string, drop: string? }
	local selectedKey: string? = nil
	local confirmAll = false
	local items: { Item } = {}
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
	local function collect(): { Item }
		local out: { Item } = {}
		for _, ore in ORES do
			local n = oreCount(ore)
			if n > 0 then
				table.insert(out, { key = "ore:" .. ore, title = Names.t(ore), count = n, asset = "ore_" .. ore, model = Theme.oreModel(ore),
					text = string.format("Ore. Sell it at the shop (%d coins each) or use it at the workbench.", EconomyConfig.ORE_PRICES[ore] or 1), drop = ore })
			end
		end
		local mats = player:FindFirstChild("Materiali")
		local icons = RS:FindFirstChild("DropIcone")
		local names = icons and icons:FindFirstChild("Nomi")
		for _, v in (if mats then mats:GetChildren() else {}) do
			if v:IsA("IntValue") and v.Value > 0 then
				local shown = names and names:GetAttribute(v.Name)
				table.insert(out, { key = "mat:" .. v.Name, title = if type(shown) == "string" then shown else Names.t(v.Name), count = v.Value,
					asset = "", model = icons and icons:FindFirstChild(v.Name), text = "Dropped by monsters. Used to craft gear.", drop = v.Name })
			end
		end
		for _, recipe in Gear.RECIPES do
			if Gear.has(player, recipe.id) then
				table.insert(out, { key = "gear:" .. recipe.id, title = recipe.name, count = 1, asset = "", id = recipe.id,
					model = Theme.itemModel(if recipe.id == "Chiodi" then "Pitons" else recipe.id, Theme.ACCENT), text = recipe.description })
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
		for _, x in items do
			if x.key == selectedKey then
				return x
			end
		end
		return nil
	end

	local function showInfo()
		local it = chosen()
		if not it then
			infoIcon.Visible = false
			infoTitle.Text = "Backpack"
			infoText.Text = "Click an item to see it. Drag it onto another slot to move it."
			dropOne.Visible, dropAll.Visible = false, false
			return
		end
		local item = it :: Item
		if item.id and Theme.ITEM_ICONS[item.id] then
			Theme.itemIcon(infoIcon, item.id, item.model)
		else
			Theme.assetPreview(infoIcon, item.asset, item.model)
		end
		infoTitle.Text = if item.drop then string.format("%s  x%d", item.title, item.count) else item.title
		infoText.Text = item.text
		dropOne.Visible = item.drop ~= nil
		dropAll.Visible = item.drop ~= nil
		dropAll.Text = if confirmAll then "Sure?" else "Drop all"
	end
	local function drop(amount: any)
		local it = chosen()
		if not it or not it.drop then
			return
		end
		local ok, message = (remotes:WaitForChild("Shop") :: RemoteFunction):InvokeServer("discard", it.key, amount)
		status(message or "", ok)
	end
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
	local function slotAt(p: Vector2): number?
		-- le posizioni dell'input sono sotto la barra di Roblox, quelle delle caselle no se la
		-- schermata la ignora
		local inset = if menuGui and menuGui.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero
		local q = p + inset
		for i, s in slots do
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
			local target = slotAt(Vector2.new(i.Position.X, i.Position.Y))
			if target and target ~= index then
				local keys = {}
				for _, x in items do
					table.insert(keys, x.key)
				end
				table.remove(keys, index)
				table.insert(keys, math.min(target, #keys + 1), item.key)
				selectedKey = item.key
				saveOrder(keys)
			end
			render()
		end)
	end

	render = function()
		Ui.clear(list)
		table.clear(slots)
		items = collect()
		-- caselle vuote fino a riempire almeno tre file: sembra uno zaino, non una lista
		local cols = math.max(1, math.floor((list.AbsoluteSize.X / uiScale() - 4) / 122))
		local total = math.max(cols * 3, math.ceil((#items + 1) / cols) * cols)
		for i = 1, total do
			local it = items[i]
			local slot = Instance.new("TextButton")
			slot.Name = "Casella" .. i
			slot.Text = ""
			slot.AutoButtonColor = it ~= nil
			slot.LayoutOrder = i
			slot.BackgroundColor3 = if it then Theme.DARK3 else Theme.DARK2
			slot.BackgroundTransparency = if it then 0.15 else 0.45
			slot.Parent = list
			Theme.corner(slot, 12)
			table.insert(slots, slot)
			if not it then
				continue
			end
			local item = it :: Item
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 10)
			icon.Size = UDim2.fromOffset(70, 70)
			icon.Parent = slot
			if item.id and Theme.ITEM_ICONS[item.id] then
				Theme.itemIcon(icon, item.id, item.model)
			else
				Theme.assetPreview(icon, item.asset, item.model)
			end
			local name = Theme.label(slot, item.title, 13, Theme.TEXT, true)
			name.AnchorPoint = Vector2.new(0.5, 1)
			name.Position = UDim2.new(0.5, 0, 1, -6)
			name.Size = UDim2.new(1, -8, 0, 30)
			name.TextXAlignment = Enum.TextXAlignment.Center
			Theme.fitText(name, 13, true)
			if item.drop then
				local count = Theme.label(slot, "x" .. item.count, 15, Theme.ACCENT, true)
				count.AnchorPoint = Vector2.new(1, 0)
				count.Position = UDim2.new(1, -6, 0, 4)
				count.Size = UDim2.fromOffset(60, 20)
				count.TextXAlignment = Enum.TextXAlignment.Right
				count.ZIndex = 4
			end
			if item.key == selectedKey then
				UiGlow.ring(slot, Theme.ACCENT, { round = false, speed = 150, thickness = 3, pad = 0 })
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
						selectedKey = item.key
						render()
					end
				end)
				if touch then
					task.delay(0.35, begin)
				end
			end)
		end
		showInfo()
	end
	return render
end
-- colori delle schede del menu (pulsanti della colonna e sfondo della finestra)
local MENU_COLORS = Theme.MENU

function MainMenu.start()
	local gui = Ui.screen("MainMenu")
	local column, window = Ui.node(gui, "Column"), Ui.node(gui, "Window")
	-- lo sfondo illustrato della montagna (bg_menu) resta: piace a Mirko e ai giocatori (la v3 lo
	-- nascondeva e dietro le finestre si vedeva il gioco)
	window.Background.Visible = true
	window.Background.ImageTransparency = 0.15
	window.Background.ScaleType = Enum.ScaleType.Crop
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
	toggle.TextColor3 = Theme.TEXT
	if not column.Teleport:FindFirstChild("Icon") then
		local icon = column.Store.Icon:Clone()
		icon.Parent = column.Teleport
		Ui.asset(icon, "icon_teleport")
	end
	for _, n in { "Store", "Backpack", "Dragons", "Crafting", "Upgrades", "Teleport" } do
  local btn = column[n]
  btn:SetAttribute("UiNative", true)
  Theme.action(btn, "alt")
  btn.BackgroundColor3 = Theme.MENU[n]
  btn.Text = ""
  btn.ClipsDescendants = true
  local title = Theme.label(btn, if n == "Store" then "Shop" elseif n == "Teleport" then "Travel" else n, 16, Theme.TEXT, true)
  title.Name = "NavTitle"
  title.Position = UDim2.new(0, 4, 1, -24)
  title.Size = UDim2.new(1, -8, 0, 22)
  title.TextXAlignment = Enum.TextXAlignment.Center
  title.ZIndex = 4
  local icon = btn:FindFirstChild("Icon")
  if icon then
   icon.AnchorPoint = Vector2.new(0.5, 0)
   icon.Position = UDim2.new(0.5, 0, 0, 3)
   icon.Size = UDim2.fromOffset(28, 28)
   icon.ZIndex = 3
  end
 end
 toggle.Visible = false

	local content = window.Content
	-- la finestra sopra l'HUD (prima il meteo le restava disegnato sopra)
	local hudGui = player.PlayerGui:FindFirstChild("ClimbHUD")
	if hudGui and hudGui:IsA("ScreenGui") then
		gui.DisplayOrder = math.max(gui.DisplayOrder, hudGui.DisplayOrder + 1)
	end
	-- impaginazione interna in pixel: titolo, chiusura, contenuto, stato
	window.Title.Position = UDim2.fromOffset(12, 8)
	window.Title.Size = UDim2.new(1, -80, 0, 44)
	window.Title.TextXAlignment = Enum.TextXAlignment.Center
	Ui.px(window.Close, 1, -12, 0, 10, 50, 50, 1, 0)
	local closeLimit = window.Close:FindFirstChild("SizeLimit")
	if closeLimit then
		closeLimit:Destroy()
	end
	Ui.px(window.Status, 0, 18, 1, -8, 600, 28, 0, 1)
	window.Status.Size = UDim2.new(1, -36, 0, 28)
	Ui.text(window.Status, 15, true)
	content.Position = UDim2.fromOffset(12, 62)
	content.Size = UDim2.new(1, -24, 1, -96)
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
	cards(content.Crafting.List, 220, 310)
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
		local travel = player.PlayerGui:FindFirstChild("Teletrasporto")
		local travelPanel = travel and travel:FindFirstChild("Panel") :: GuiObject?
		if travelPanel then travelPanel.Visible = false end
		-- il tutorial vuole sapere quando apri il Crafting (server/Tutorial)
		local opened = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("MenuOpened")
		if opened then
			(opened :: RemoteEvent):FireServer(name)
		end
		-- finestra e titolo del colore della scheda (sfondo sfumato sotto la cornice)
		local tone = MENU_COLORS[name] or Theme.BLUE
		-- velo scuro (stile menu zombie di Black Ops 2): lo sfondo illustrato si intravede, il
		-- colore della scheda resta solo nel titolo e nei pulsanti (Mirko 15/10: "lo sfondo
		-- colorato fa schifo")
		Ui.tint(window, Theme.DARK, false, 0)
		local fill = window:FindFirstChild("Tinta") :: Frame?
		if fill then
			fill.BackgroundTransparency = 0.22
		end
		-- sfondo scuro dipinto da Codex (docs/CODEX_UOVA_E_SFONDI.md): quando ha l'ID prende il posto
		-- dell'illustrazione della montagna e il velo diventa leggero
		if Ui.asset(window.Background, "bg_menu_dark") then
			window.Background.Visible = true
			window.Background.ImageTransparency = 0
			if fill then
				fill.BackgroundTransparency = 0.55
			end
		else
			Ui.asset(window.Background, "bg_menu")
			window.Background.Visible = true
		end
		-- l'immagine sotto il velo (tint porta tutti i figli sopra al colore)
		window.Background.ZIndex = 0
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
				elseif name == "Backpack" then mountInventory(c, status)
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
		b.Text = ""
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
		column.Visible = true
		toggle.Text = if expanded then "Hide" else "Menu"
	end
	toggle.Activated:Connect(function()
		expanded = not expanded
		showIcons()
	end)
	showIcons()
	Ui.viewportChanged(function(vp)
		gui:SetAttribute("ShortUI", vp.Y < 560)
  local logical = Ui.fitScale(gui, vp)
  local m = Ui.menuMetrics(logical)
  grid.FillDirectionMaxCells = m.cols
  grid.CellSize = UDim2.fromOffset(m.cell, 56)
  Ui.px(column, 0.5, 0, 0, 8, m.navWidth, m.navHeight, 0.5, 0)
  Ui.px(window, 0, m.x, 0, m.y, m.width, m.height)
  toggle.Visible = false
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
