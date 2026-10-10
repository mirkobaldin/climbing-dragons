--!strict
-- Menu principale: una colonna di pulsanti grandi a sinistra (a meta' schermo, lontana dal
-- joystick e dal tasto salto del telefono) e una finestra con le schede:
--   Negozio (compra / vendi / Robux) · Zaino · Draghi · Crafting · Potenziamenti (taglie, rinascita)
-- La finestra si adatta allo schermo (anche telefono in verticale) e non copre tutto.
-- Tasti: B negozio, I zaino (anche V), G draghi, N crafting, U potenziamenti. Si apre anche dall'emporio, dal nido e
-- dal banco da lavoro.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local EconomyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EconomyConfig"))
local Names = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Names"))
local Gear = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Gear"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))
local CraftingUI = require(script.Parent.CraftingUI)
local DragonUI = require(script.Parent.DragonUI)
local UpgradeUI = require(script.Parent.UpgradeUI)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local MainMenu = {}

type Tab = { name: string, key: Enum.KeyCode, key2: Enum.KeyCode?, icon: () -> Instance?, frame: Frame?, refresh: (() -> ())? }

local ORES = { "Carbone", "Ferro", "Oro", "Cristallo", "Rubino", "Cosmico" }

local function oreCount(ore: string): number
	local folder = player:FindFirstChild("Ores")
	local v = folder and folder:FindFirstChild(ore) :: IntValue?
	return if v then v.Value else 0
end

local function preview(kind: string, element: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild("Previews")
	local sub = folder and folder:FindFirstChild(kind)
	return sub and sub:FindFirstChild(element)
end

local function clear(frame: Instance)
	for _, c in frame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

------------------------------------------------------------------------------------------
-- Negozio

local function mountShop(container: Frame, status: (string, boolean) -> ()): () -> ()
	local sub = "Buy"
	local tabsRow = Theme.frame(container, nil, 1)
	tabsRow.Size = UDim2.new(1, 0, 0, 38)
	Theme.list(tabsRow, 6, true)
	local body = Theme.frame(container, nil, 1)
	body.Position = UDim2.new(0, 0, 0, 44)
	body.Size = UDim2.new(1, 0, 1, -44)
	local list = Theme.scroll(body)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -6, 0, 120)
	grid.CellPadding = UDim2.new(0, 6, 0, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	local subButtons: { [string]: TextButton } = {}
	local render: () -> ()

	local function call(action: string, id: string?, amount: any)
		local ok, message = (remotes:WaitForChild("Shop") :: RemoteFunction):InvokeServer(action, id, amount)
		if message and message ~= "" then
			status(message, ok)
		end
		render()
	end

	local function card(order: number): Frame
		local c = Theme.frame(list, Theme.CARD)
		c.LayoutOrder = order
		Theme.corner(c, 10)
		return c
	end

	render = function()
		for name, b in subButtons do
			b.BackgroundColor3 = if name == sub then Theme.ACCENT else Theme.CARD
			b.TextColor3 = if name == sub then Theme.BG else Theme.TEXT
		end
		for _, c in list:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		if sub == "Buy" then
			for k, item in ShopConfig.ITEMS do
				local c = card(k)
				local icon: Instance = if item.id == "MysteryEgg" or item.id == "RareEgg"
					then (preview("Eggs", "Cosmico") or Theme.itemModel(item.id, item.color))
					else Theme.itemModel(item.id, item.color)
				Theme.viewport(c, icon, UDim2.new(0, 64, 0, 64)).Position = UDim2.new(0, 6, 0, 6)
				local t = Theme.label(c, item.name, 14, Theme.TEXT, true)
				t.Position = UDim2.new(0, 76, 0, 6)
				t.Size = UDim2.new(1, -80, 0, 18)
				local d = Theme.label(c, item.description, 11, Theme.MUTED)
				d.Position = UDim2.new(0, 76, 0, 26)
				d.Size = UDim2.new(1, -80, 0, 44)
				local b = Theme.button(c, string.format("%d coins", item.price), Theme.COIN, UDim2.new(1, -12, 0, 36))
				b.Position = UDim2.new(0, 6, 1, -42)
				b.Activated:Connect(function()
					call("buy", item.id)
				end)
			end
		elseif sub == "Sell" then
			for k, ore in ORES do
				local have = oreCount(ore)
				local c = card(k)
				Theme.viewport(c, Theme.oreModel(ore), UDim2.new(0, 56, 0, 56)).Position = UDim2.new(0, 6, 0, 6)
				local t = Theme.label(c, string.format("%s  x%d", Names.t(ore), have), 14, Theme.TEXT, true)
				t.Position = UDim2.new(0, 68, 0, 8)
				t.Size = UDim2.new(1, -72, 0, 18)
				local p = Theme.label(c, string.format("%d coins each", EconomyConfig.ORE_PRICES[ore] or 1), 12, Theme.COIN)
				p.Position = UDim2.new(0, 68, 0, 30)
				p.Size = UDim2.new(1, -72, 0, 16)
				local row = Theme.frame(c, nil, 1)
				row.Position = UDim2.new(0, 6, 1, -42)
				row.Size = UDim2.new(1, -12, 0, 36)
				Theme.list(row, 6, true)
				local one = Theme.button(row, "Sell 1", Theme.CARD, UDim2.new(0.5, -3, 1, 0))
				one.TextColor3 = Theme.TEXT
				Theme.stroke(one, Theme.MUTED, 1, 0.5)
				one.Activated:Connect(function()
					call("sellOre", ore, 1)
				end)
				local all = Theme.button(row, "Sell all", Theme.GOOD, UDim2.new(0.5, -3, 1, 0))
				all.Activated:Connect(function()
					call("sellOre", ore, "all")
				end)
				if have <= 0 then
					one.AutoButtonColor, all.AutoButtonColor = false, false
					all.BackgroundColor3 = Color3.fromRGB(80, 84, 92)
				end
			end
			local carrying = player:GetAttribute("CarryingEgg")
			local c = card(99)
			local element, rarity = "", ""
			if type(carrying) == "string" then
				element, rarity = string.match(carrying, "^(.-)|(.*)$")
			end
			Theme.viewport(c, if element ~= "" then preview("Eggs", element :: string) else nil, UDim2.new(0, 56, 0, 56)).Position = UDim2.new(0, 6, 0, 6)
			local t = Theme.label(c, if element ~= "" then string.format("%s %s Egg", Names.t(rarity), Names.t(element)) else "Carried egg", 14, Theme.TEXT, true)
			t.Position = UDim2.new(0, 68, 0, 8)
			t.Size = UDim2.new(1, -72, 0, 18)
			local p = Theme.label(c, if rarity ~= "" then string.format("%d coins", EconomyConfig.EGG_PRICES[rarity] or 10) else "Bring one here to sell it", 12, Theme.MUTED)
			p.Position = UDim2.new(0, 68, 0, 30)
			p.Size = UDim2.new(1, -72, 0, 30)
			if element ~= "" then
				local b = Theme.button(c, "Sell egg", Theme.GOOD, UDim2.new(1, -12, 0, 36))
				b.Position = UDim2.new(0, 6, 1, -42)
				b.Activated:Connect(function()
					call("sellEgg")
				end)
			end
		else
			local entries = {
				{ "EggFinder", "Egg Finder", "Compass to the nearest egg" },
				{ "FastIncubation", "Fast Incubation x2", "Eggs hatch in half the time" },
				{ "ExtraDragon", "+1 Dragon Follower", "Bring two dragons with you" },
				{ "ExtraIncubator", "Big Nest", "+2 nest slots" },
				{ "Revive", "Mountain Rescue", "When you die, respawn where you fell" },
				{ "InstantHatch", "Instant Hatch", "Every egg in your nest ready now" },
				{ "Coins1000", "1000 Coins", "A boost for your house" },
				{ "TrainingX2", "Training XP x2", "Dragons train twice as fast, forever" },
				{ "TrainingBoost", "Training Boost x3", "Training XP x3 for 15 minutes" },
			}
			for k, e in entries do
				local c = card(k)
				local owned = player:GetAttribute("Pass_" .. e[1]) == true
				local t = Theme.label(c, e[2], 15, Theme.TEXT, true)
				t.Position = UDim2.new(0, 10, 0, 8)
				t.Size = UDim2.new(1, -20, 0, 20)
				local d = Theme.label(c, e[3], 12, Theme.MUTED)
				d.Position = UDim2.new(0, 10, 0, 32)
				d.Size = UDim2.new(1, -20, 0, 32)
				local available = (DragonConfig.GAMEPASSES[e[1]] or ShopConfig.DEV_PRODUCTS[e[1]] or 0) > 0
				local b = Theme.button(
					c,
					if owned then "Owned" elseif available then "Buy (Robux)" else "Coming soon",
					if owned then Theme.MUTED elseif available then Theme.GOOD else Color3.fromRGB(80, 84, 92),
					UDim2.new(1, -12, 0, 36)
				)
				b.Position = UDim2.new(0, 6, 1, -42)
				b.Activated:Connect(function()
					if not owned and available then
						call("robux", e[1])
					end
				end)
			end
		end
	end

	for _, name in { "Buy", "Sell", "Robux" } do
		local b = Theme.button(tabsRow, name, Theme.CARD, UDim2.new(0, 100, 0, 34))
		subButtons[name] = b
		b.Activated:Connect(function()
			sub = name
			render()
		end)
	end
	return render
end

------------------------------------------------------------------------------------------
-- Zaino

local function mountInventory(container: Frame): () -> ()
	local list = Theme.scroll(container)
	Theme.list(list, 10)
	return function()
		clear(list)
		local summary = Theme.frame(list, Theme.CARD)
		summary.Size = UDim2.new(1, -8, 0, 64)
		summary.LayoutOrder = 1
		Theme.corner(summary, 10)
		Theme.padding(summary, 10)
		local house = EconomyConfig.HOUSES[(player:GetAttribute("HouseLevel") or 0) :: number]
		Theme.label(
			summary,
			string.format(
				'<font color="#FFCD3C">%d coins</font>   ·   House: %s   ·   Dragons at home: %d coins/min\nPitons: %d   ·   Warmth: %d%%',
				(player:GetAttribute("Coins") or 0) :: number,
				if house then Names.t(house.name) else "none (buy the Tent on your plot)",
				(player:GetAttribute("RoostRate") or 0) :: number,
				(player:GetAttribute("Pitons") or 0) :: number,
				math.floor((player:GetAttribute("Warmth") or 100) :: number)
			),
			14,
			Theme.TEXT,
			true
		).Size =
			UDim2.fromScale(1, 1)

		local title = Theme.label(list, "Ores", 15, Theme.TEXT, true)
		title.LayoutOrder = 2
		local grid = Theme.frame(list, nil, 1)
		grid.LayoutOrder = 3
		grid.Size = UDim2.new(1, -8, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0, 96, 0, 110)
		layout.CellPadding = UDim2.new(0, 8, 0, 8)
		layout.Parent = grid
		for _, ore in ORES do
			local c = Theme.frame(grid, Theme.CARD)
			Theme.corner(c, 10)
			Theme.viewport(c, Theme.oreModel(ore), UDim2.new(1, 0, 0, 70))
			local l = Theme.label(c, string.format("%s\n<b>%d</b>", Names.t(ore), oreCount(ore)), 13, Theme.TEXT)
			l.TextXAlignment = Enum.TextXAlignment.Center
			l.Position = UDim2.new(0, 0, 0, 70)
			l.Size = UDim2.new(1, 0, 0, 38)
		end

		-- materiali lasciati dai nemici (cartella "Materiali"), coi modelli veri di Mirko
		local mats = player:FindFirstChild("Materiali")
		local icons = ReplicatedStorage:FindFirstChild("DropIcone")
		local names = icons and icons:FindFirstChild("Nomi")
		local dropList = {}
		for _, v in (if mats then mats:GetChildren() else {}) :: { Instance } do
			if v:IsA("IntValue") and v.Value > 0 then
				table.insert(dropList, v)
			end
		end
		table.sort(dropList, function(x, y)
			return x.Name < y.Name
		end)
		local dTitle = Theme.label(list, if #dropList > 0 then "Drops" else "Drops (defeat yetis and ice golems to collect them)", 15, Theme.TEXT, true)
		dTitle.LayoutOrder = 3
		dTitle.Size = UDim2.new(1, -8, 0, 20)
		dTitle.TextWrapped = true
		local dGrid = Theme.frame(list, nil, 1)
		dGrid.LayoutOrder = 3
		dGrid.Size = UDim2.new(1, -8, 0, 0)
		dGrid.AutomaticSize = Enum.AutomaticSize.Y
		local dLayout = Instance.new("UIGridLayout")
		dLayout.CellSize = UDim2.new(0, 96, 0, 110)
		dLayout.CellPadding = UDim2.new(0, 8, 0, 8)
		dLayout.Parent = dGrid
		for _, v in dropList do
			local c = Theme.frame(dGrid, Theme.CARD)
			Theme.corner(c, 10)
			local tpl = icons and icons:FindFirstChild(v.Name)
			Theme.viewport(c, if tpl then tpl:Clone() else Theme.itemModel("Drop", Theme.ACCENT), UDim2.new(1, 0, 0, 70), true)
			local shown = names and names:GetAttribute(v.Name)
			local l = Theme.label(c, string.format("%s\n<b>%d</b>", if type(shown) == "string" then shown else (string.gsub(v.Name, "_", " ")), (v :: IntValue).Value), 13, Theme.TEXT)
			l.TextXAlignment = Enum.TextXAlignment.Center
			l.Position = UDim2.new(0, 0, 0, 70)
			l.Size = UDim2.new(1, 0, 0, 38)
		end

		local gTitle = Theme.label(list, "Gear", 15, Theme.TEXT, true)
		gTitle.LayoutOrder = 4
		-- icone 3D come nel crafting; quello che non hai e' scuro
		local ICON = { Chiodi = "Pitons", Torcia = "Torcia" }
		local COLORS = {
			Ramponi = Color3.fromRGB(170, 174, 180),
			Tuta = Color3.fromRGB(235, 120, 50),
			Rampino = Color3.fromRGB(196, 150, 80),
			PiccoRinforzato = Color3.fromRGB(255, 190, 40),
		}
		for k, recipe in Gear.RECIPES do
			local owned = Gear.has(player, recipe.id)
			local row = Theme.frame(list, Theme.CARD)
			row.LayoutOrder = 4 + k
			row.Size = UDim2.new(1, -8, 0, 64)
			Theme.corner(row, 10)
			if owned then
				Theme.stroke(row, Theme.GOOD, 1.5, 0.35)
			end
			local icon = Theme.viewport(row, Theme.itemModel(ICON[recipe.id] or recipe.id, COLORS[recipe.id] or Theme.ACCENT), UDim2.new(0, 56, 0, 56), false)
			icon.Position = UDim2.new(0, 6, 0, 4)
			if not owned then
				icon.ImageTransparency = 0.55
				icon.ImageColor3 = Color3.fromRGB(150, 150, 160)
			end
			local l = Theme.label(
				row,
				string.format(
					'%s\n<font size="12" color="%s">%s</font>',
					recipe.name,
					if owned then "#6ECD78" else "#A5AAB6",
					if owned then "owned" elseif recipe.station == "Ovunque" then "craft anywhere" else "craft at a Workbench"
				),
				15,
				Theme.TEXT,
				true
			)
			l.Position = UDim2.new(0, 72, 0, 0)
			l.Size = UDim2.new(1, -84, 1, 0)
		end
	end
end

------------------------------------------------------------------------------------------

function MainMenu.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	-- colonna dei pulsanti (sinistra, a meta' altezza)
	local column = Theme.frame(gui, nil, 1)
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, 10, 0.46, 0)
	column.Size = UDim2.new(0, 70, 0, 5 * 78)
	Theme.list(column, 8)
	-- "Hide": nasconde e rimostra la colonna (resta solo questo pulsantino)
	local hideBtn = Instance.new("TextButton")
	hideBtn.Name = "NascondiIcone"
	hideBtn.AnchorPoint = Vector2.new(0, 0)
	hideBtn.Position = UDim2.new(0, 10, 0.46, (5 * 78) / 2 + 4) -- sotto la colonna
	hideBtn.Size = UDim2.new(0, 70, 0, 26)
	hideBtn.BackgroundColor3 = Theme.BG
	hideBtn.BackgroundTransparency = 0.2
	hideBtn.Font = Enum.Font.GothamBold
	hideBtn.TextSize = 13
	hideBtn.TextColor3 = Theme.TEXT
	hideBtn.Text = "Hide"
	hideBtn.Parent = gui
	Theme.corner(hideBtn, 10)
	hideBtn.Activated:Connect(function()
		column.Visible = not column.Visible
		hideBtn.Text = if column.Visible then "Hide" else "Show"
	end)

	-- finestra
	local window = Theme.frame(gui, Theme.BG, 0.06)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.52, 0.5)
	window.Size = UDim2.fromScale(0.7, 0.72)
	window.Visible = false
	Theme.corner(window, 14)
	Theme.stroke(window, Theme.ACCENT, 2, 0.6)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(760, 500)
	limit.MinSize = Vector2.new(300, 240)
	limit.Parent = window
	Theme.padding(window, 12)

	local title = Theme.label(window, "", 20, Theme.ACCENT, true)
	title.Size = UDim2.new(1, -50, 0, 28)
	local close = Theme.button(window, "X", Theme.CARD, UDim2.new(0, 40, 0, 40))
	close.TextColor3 = Theme.TEXT
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, -4)
	local content = Theme.frame(window, nil, 1)
	content.Position = UDim2.new(0, 0, 0, 38)
	content.Size = UDim2.new(1, 0, 1, -64)
	local statusLabel = Theme.label(window, "", 14, Theme.GOOD, true)
	statusLabel.AnchorPoint = Vector2.new(0, 1)
	statusLabel.Position = UDim2.new(0, 0, 1, 0)
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	local function status(text: string, ok: boolean)
		statusLabel.Text = text
		statusLabel.TextColor3 = if ok then Theme.GOOD else Theme.BAD
	end

	local tabs: { Tab } = {
		{ name = "Store", key = Enum.KeyCode.B, icon = function()
			return Theme.itemModel("Coins", Theme.COIN)
		end },
		{ name = "Backpack", key = Enum.KeyCode.I, key2 = Enum.KeyCode.V, icon = function()
			return Theme.oreModel("Oro")
		end },
		{ name = "Dragons", key = Enum.KeyCode.G, icon = function()
			return preview("Dragons", "Cosmico")
		end },
		{ name = "Crafting", key = Enum.KeyCode.N, icon = function()
			return Theme.itemModel("Pitons", Color3.fromRGB(170, 174, 180))
		end },
		{ name = "Upgrades", key = Enum.KeyCode.U, icon = function()
			return Theme.itemModel("Rampino", Color3.fromRGB(196, 150, 80))
		end },
	}
	local current: Tab? = nil

	local function open(tab: Tab?)
		if not tab or current == tab then
			window.Visible = false
			current = nil
			return
		end
		current = tab
		window.Visible = true
		title.Text = tab.name
		statusLabel.Text = ""
		for _, t in tabs do
			if t.frame then
				t.frame.Visible = t == tab
			end
		end
		if not tab.frame then
			local f = Theme.frame(content, nil, 1)
			f.Size = UDim2.fromScale(1, 1)
			tab.frame = f
			if tab.name == "Store" then
				tab.refresh = mountShop(f, status)
			elseif tab.name == "Backpack" then
				tab.refresh = mountInventory(f)
			elseif tab.name == "Dragons" then
				tab.refresh = DragonUI.mount(f, status)
			elseif tab.name == "Upgrades" then
				tab.refresh = UpgradeUI.mount(f, status)
			else
				tab.refresh = CraftingUI.mount(f, status)
			end
		end
		if tab.refresh then
			(tab.refresh :: () -> ())()
		end
	end
	local function byName(name: string): Tab?
		for _, t in tabs do
			if t.name == name then
				return t
			end
		end
		return nil
	end

	for k, tab in tabs do
		local b = Instance.new("TextButton")
		b.LayoutOrder = k
		b.Size = UDim2.new(0, 70, 0, 70)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BackgroundTransparency = 0.05
		b.Text = ""
		b.Parent = column
		Theme.corner(b, 18)
		-- stesso stile delle schede: vetro blu notte, bordo dorato
		Theme.gradient(b, Color3.fromRGB(40, 54, 92), Color3.fromRGB(14, 18, 32), 90)
		Theme.stroke(b, Theme.ACCENT, 2, 0.35)
		local vf = Theme.viewport(b, nil, UDim2.new(1, -10, 1, -24))
		vf.Position = UDim2.new(0, 5, 0, 2)
		task.spawn(function()
			-- l'anteprima dei draghi arriva dal server dopo qualche istante
			for _ = 1, 20 do
				local obj = tab.icon()
				if obj then
					vf:Destroy()
					Theme.viewport(b, obj, UDim2.new(1, -10, 1, -24), true).Position = UDim2.new(0, 5, 0, 2)
					return
				end
				task.wait(1)
			end
		end)
		local l = Theme.label(b, tab.name, 11, Theme.TEXT, true)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.AnchorPoint = Vector2.new(0, 1)
		l.Position = UDim2.new(0, 0, 1, -3)
		l.Size = UDim2.new(1, 0, 0, 16)
		b.Activated:Connect(function()
			open(tab)
		end)
		ContextActionService:BindAction("Menu" .. tab.name, function(_, state)
			if state == Enum.UserInputState.Begin then
				open(tab)
			end
			return Enum.ContextActionResult.Pass
		end, false, tab.key, tab.key2 or tab.key)
	end
	close.Activated:Connect(function()
		open(nil)
	end)

	for eventName, tabName in { OpenShop = "Store", OpenCrafting = "Crafting", OpenDragons = "Dragons" } do
		(remotes:WaitForChild(eventName) :: RemoteEvent).OnClientEvent:Connect(function()
			local t = byName(tabName)
			if t and current ~= t then
				open(t)
			end
		end)
	end

	-- ridisegna la scheda aperta quando cambiano soldi, minerali, draghi...
	local function refreshOpen()
		if current and current.refresh then
			(current.refresh :: () -> ())()
		end
	end
	for _, attr in { "Coins", "DragonData", "CarryingEgg", "HouseLevel", "Pitons" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshOpen)
	end
	task.spawn(function()
		-- anche i drop dei nemici (cartella "Materiali")
		task.spawn(function()
			local mats = player:WaitForChild("Materiali", 120)
			if mats then
				local function watch(v: Instance)
					if v:IsA("IntValue") then
						v.Changed:Connect(refreshOpen)
					end
				end
				for _, v in mats:GetChildren() do
					watch(v)
				end
				mats.ChildAdded:Connect(function(v)
					watch(v)
					refreshOpen()
				end)
			end
		end)
		local minerals = player:WaitForChild("Ores", 30)
		if minerals then
			minerals.DescendantAdded:Connect(refreshOpen)
			for _, v in minerals:GetChildren() do
				if v:IsA("IntValue") then
					v.Changed:Connect(refreshOpen)
				end
			end
			minerals.ChildAdded:Connect(function(v)
				if v:IsA("IntValue") then
					v.Changed:Connect(refreshOpen)
				end
			end)
		end
	end)
	-- i tempi di cova scorrono mentre la scheda Draghi e' aperta
	task.spawn(function()
		while true do
			task.wait(1)
			if current and current.name == "Dragons" then
				refreshOpen()
			end
		end
	end)
end

return MainMenu
