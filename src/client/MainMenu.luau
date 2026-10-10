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
local function grid(list: ScrollingFrame)
	local old = list:FindFirstChildOfClass("UIListLayout")
	if old then
		old:Destroy()
	end
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromScale(0.02, 0.025)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local function resize()
		layout.CellSize =
			UDim2.fromScale(if list.AbsoluteSize.X >= 540 then 0.48 else 0.97, 180 / math.max(1, list.AbsoluteSize.Y))
	end
	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
end
local function mountShop(container: Frame, status: (string, boolean) -> ()): () -> ()
	local list = Ui.node(container, "List")
	grid(list)
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
			Ui.node(container, "Tabs/" .. name).BackgroundColor3 = if name == sub then Theme.ACCENT else Theme.CARD
		end
		if sub == "Buy" then
			for k, item in ShopConfig.ITEMS do
				local c = card(k)
				local egg = item.id == "MysteryEgg" or item.id == "RareEgg"
				Theme.assetPreview(
					c.Icon,
					if egg then "icon_egg" elseif item.id == "Pitons" then "icon_piton" else "",
					if egg then preview("Eggs", "Cosmico") else Theme.itemModel(item.id, item.color)
				)
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
	grid(list)
	return function()
		Ui.clear(list)
		local summary = Ui.template("TextCard", list)
		summary.LayoutOrder = 0
		summary.SizeLimit.MinSize = Vector2.new(0, 142)
		summary.SizeLimit.MaxSize = Vector2.new(10000, 142)
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
		local function item(title: string, count: string, asset: string, model: Instance?)
			order += 1
			local c = Ui.template("InventoryCard", list)
			c.LayoutOrder = order
			c.Title.Text, c.Count.Text = title, count
			Theme.assetPreview(c.Icon, asset, model)
		end
		for _, ore in ORES do
			item(Names.t(ore), tostring(oreCount(ore)), "ore_" .. ore, Theme.oreModel(ore))
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
					tostring(v.Value),
					"",
					icons and icons:FindFirstChild(v.Name)
				)
			end
		end
		for _, recipe in Gear.RECIPES do
			item(
				recipe.name,
				if Gear.has(player, recipe.id) then "Owned" else "Not owned",
				"",
				Theme.itemModel(if recipe.id == "Chiodi" then "Pitons" else recipe.id, Theme.ACCENT)
			)
		end
	end
end
function MainMenu.start()
	local gui = Ui.screen("MainMenu")
	local column, window = Ui.node(gui, "Column"), Ui.node(gui, "Window")
	column.Teleport.Text = if UIS.TouchEnabled then "Teleport" else "Teleport (T)"
	local content = window.Content
	Ui.skin(window.Title, "panel_header")
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
			return
		end
		current = name
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
	column.NascondiIcone.Activated:Connect(function()
		expanded = not expanded
		for _, n in names do
			column[n].Visible = expanded
		end
		column.Teleport.Visible = expanded
		column.NascondiIcone.Text = if expanded then "Hide" else "Show"
	end)
	Ui.viewportChanged(function(vp)
		local portrait = vp.X < vp.Y
		window.Position = UDim2.fromScale(if portrait then 0.5 else 0.56, 0.5)
		window.Size = UDim2.fromScale(if portrait then 0.97 else 0.83, 0.9)
		local top = if portrait then 0.43 else 0.33
		local height = math.max(48, math.min(364, vp.Y - 170 - top * vp.Y))
		column.Position = UDim2.fromScale(0.01, top)
		column.Size = UDim2.fromScale(if portrait then 0.22 else 0.13, height / vp.Y)
		for _, child in column:GetChildren() do
			if child:IsA("GuiButton") then
				child.Size = UDim2.fromScale(0.94, 48 / height)
			end
		end
		local body = content.Dragons.Body
		body.Nest.Position = UDim2.fromScale(0, 0)
		body.Nest.Size = UDim2.fromScale(if portrait then 1 else 0.36, if portrait then 0.4 else 1)
		body.Dragons.Position = UDim2.fromScale(if portrait then 0 else 0.38, if portrait then 0.43 else 0)
		body.Dragons.Size = UDim2.fromScale(if portrait then 1 else 0.62, if portrait then 0.57 else 1)
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
			if current == "Dragons" then
				refreshOpen()
			end
		end
	end)
end
return MainMenu
