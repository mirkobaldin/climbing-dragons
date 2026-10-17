--!strict
-- Pagina a Robux del negozio (Mirko 17/10, riferimento: la pagina dei pacchetti di un simulatore).
-- Uova e velocita' della schiusa si comprano qui, non con le monete. Sezioni dall'alto:
-- Starter Pack (una volta sola, grande), Value Packs, uova (con le probabilita', come chiede
-- Roblox per le cose a caso), pozioni da 15 minuti, monete, aiuti, pass. I dati stanno in
-- shared/ShopConfig (DEV_PRODUCTS, ROBUX_PRICES, PACKS...), la consegna in server/Shop.
-- Un prodotto con ID 0 (non ancora creato nel Creator Hub) mostra COMING SOON.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("UiView"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local DragonConfig = require(Shared:WaitForChild("DragonConfig"))
local Items = require(Shared:WaitForChild("Items"))
local Names = require(Shared:WaitForChild("Names"))
local UiKit = require(script.Parent.UiKit)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local RobuxShop = {}

-- prezzo vero da Roblox (si chiede una volta sola per prodotto)
local realPrice: { [string]: number } = {}
local asked: { [string]: boolean } = {}

local function idOf(name: string): (number, Enum.InfoType)
	local pass = DragonConfig.GAMEPASSES[name]
	if pass and pass > 0 then
		return pass, Enum.InfoType.GamePass
	end
	return ShopConfig.DEV_PRODUCTS[name] or 0, Enum.InfoType.Product
end

local function priceText(name: string): string
	local id, kind = idOf(name)
	if id > 0 and not asked[name] then
		asked[name] = true
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, kind)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				realPrice[name] = info.PriceInRobux
			end
		end)
	end
	return "R$ " .. tostring(realPrice[name] or ShopConfig.ROBUX_PRICES[name] or "?")
end

local function packIcon(it: ShopConfig.PackItem): string
	if it.kind == "coins" then
		return "icon_coin"
	elseif it.kind == "egg" or it.kind == "hatch" then
		return "icon_egg"
	elseif it.kind == "stones" then
		return "icon_stone"
	elseif it.kind == "item" and it.id then
		local def = Items.get(it.id)
		return if def then def.icon else "icon_quest"
	end
	return "icon_quest"
end

local function icon(parent: Instance, asset: string, fallback: string?, size: number): ImageLabel
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromOffset(size, size)
	img.ZIndex = 5
	img.Parent = parent
	if not Ui.asset(img, asset) and not (fallback and Ui.asset(img, fallback)) then
		if not Ui.asset(img, "icon_quest") then
			img.Visible = false
		end
	end
	return img
end

-- monta la pagina accanto alla lista del negozio; call(action, id) chiama il server
function RobuxShop.mount(container: Frame, list: GuiObject, call: (string, string) -> ()): { show: (boolean) -> () }
	local page = Instance.new("ScrollingFrame")
	page.Name = "PaginaRobux"
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 4
	page.ScrollBarImageColor3 = UiKit.ACCENT
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.Visible = false
	page.ZIndex = list.ZIndex
	page.Parent = container
	local function follow()
		page.AnchorPoint = list.AnchorPoint
		page.Position = list.Position
		page.Size = list.Size
	end
	list:GetPropertyChangedSignal("Size"):Connect(follow)
	list:GetPropertyChangedSignal("Position"):Connect(follow)
	follow()
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 14)
	layout.Parent = page
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 12)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 16)
	pad.Parent = page

	local grids: { { grid: UIGridLayout, h: number, min: number } } = {}
	local function width(): number
		local gui = page:FindFirstAncestorWhichIsA("ScreenGui")
		local u = gui and gui:FindFirstChild("ScalaUI")
		local k = if u and u:IsA("UIScale") and u.Scale > 0 then u.Scale else 1
		return page.AbsoluteSize.X / k - 22
	end
	local function resize()
		local w = width()
		if w < 50 then
			return
		end
		for _, g in grids do
			local cols = math.clamp(math.floor(w / g.min), 1, 5)
			g.grid.CellSize = UDim2.fromOffset(math.floor((w - (cols - 1) * 10) / cols), g.h)
		end
	end
	page:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)

	local order = 0
	local function heading(text: string, sub: string?)
		order += 1
		local h = Instance.new("Frame")
		h.BackgroundTransparency = 1
		h.Size = UDim2.new(1, 0, 0, if sub then 46 else 30)
		h.LayoutOrder = order
		h.Parent = page
		local t = UiKit.label(h, text, "section", 22)
		t.TextColor3 = UiKit.ACCENT
		t.Size = UDim2.new(1, 0, 0, 28)
		if sub then
			local s = UiKit.label(h, sub, "secondary", 13)
			s.Position = UDim2.fromOffset(0, 28)
			s.Size = UDim2.new(1, 0, 0, 16)
		end
	end
	local function section(h: number, min: number): Frame
		order += 1
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		f.LayoutOrder = order
		f.Parent = page
		local g = Instance.new("UIGridLayout")
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.CellPadding = UDim2.fromOffset(10, 10)
		g.Parent = f
		table.insert(grids, { grid = g, h = h, min = min })
		return f
	end
	local function card(parent: Instance, tone: Color3?): Frame
		local c = Instance.new("Frame")
		c.BackgroundColor3 = UiKit.RAISED
		c.BackgroundTransparency = 0.1
		c.BorderSizePixel = 0
		c.Parent = parent
		UiKit.edge(c, tone or UiKit.LINE, 1, if tone then 0.2 else 0.7)
		-- luce del colore del prodotto dal basso
		local glow = Instance.new("Frame")
		glow.BorderSizePixel = 0
		glow.BackgroundColor3 = tone or UiKit.ICE
		glow.Size = UDim2.fromScale(1, 1)
		glow.ZIndex = 1
		glow.Parent = c
		local gg = Instance.new("UIGradient")
		gg.Rotation = -90
		gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) })
		gg.Parent = glow
		return c
	end
	local buttons: { { b: TextButton, name: string } } = {}
	local function buy(parent: Instance, name: string): TextButton
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(0.5, 0, 1, -10)
		b.Size = UDim2.new(1, -20, 0, 40)
		b.ZIndex = 6
		b.Parent = parent
		UiKit.button(b, "primary")
		b.Activated:Connect(function()
			local id = idOf(name)
			local packDef = ShopConfig.pack(name)
			local owned = player:GetAttribute("Pass_" .. name) == true or (packDef ~= nil and packDef.oneTime == true and player:GetAttribute("Comprato_" .. name) == true)
			if id > 0 and not owned then
				call("robux", name)
			end
		end)
		table.insert(buttons, { b = b, name = name })
		return b
	end
	local function title(parent: Instance, text: string, y: number, size: number?): TextLabel
		local t = UiKit.label(parent, text, "name", size or 19)
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.Position = UDim2.fromOffset(8, y)
		t.Size = UDim2.new(1, -16, 0, 24)
		t.ZIndex = 5
		return t
	end
	local function body(parent: Instance, text: string, y: number, h: number): TextLabel
		local t = UiKit.label(parent, text, "secondary", 13)
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.TextYAlignment = Enum.TextYAlignment.Top
		t.TextWrapped = true
		t.TextTruncate = Enum.TextTruncate.None
		t.Position = UDim2.fromOffset(10, y)
		t.Size = UDim2.new(1, -20, 0, h)
		t.ZIndex = 5
		return t
	end
	-- righe "icona + testo" del contenuto di un pacchetto
	local function contents(parent: Instance, pack: ShopConfig.Pack, x: UDim, y: number, w: UDim)
		for i, it in pack.items do
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Position = UDim2.new(x.Scale, x.Offset, 0, y + (i - 1) * 26)
			row.Size = UDim2.new(w.Scale, w.Offset, 0, 24)
			row.ZIndex = 5
			row.Parent = parent
			local fallback = if it.kind == "stones" then "ore_Cristallo" elseif it.kind == "item" and it.id and Items.get(it.id) then (Items.get(it.id) :: Items.Item).fallback else nil
			icon(row, packIcon(it), fallback, 22)
			local t = UiKit.label(row, it.text, "body", 14)
			t.Position = UDim2.fromOffset(28, 0)
			t.Size = UDim2.new(1, -28, 1, 0)
			t.ZIndex = 5
		end
	end
	local function art(parent: Instance, asset: string, fallbackEgg: string?, pos: UDim2, size: UDim2)
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.Position = pos
		img.Size = size
		img.ZIndex = 4
		img.Parent = parent
		if not Ui.asset(img, asset) then
			img:Destroy()
			-- finche' Codex non fa le immagini dei pacchetti: l'uovo 3D che gira
			local f = RS:FindFirstChild("Previews")
			local eggs = f and f:FindFirstChild("Eggs")
			local m = eggs and fallbackEgg and eggs:FindFirstChild(fallbackEgg)
			local vf = Theme.viewport(parent, m, size, true)
			vf.Position = pos
			vf.ZIndex = 4
		end
	end

	-- STARTER PACK (una volta sola)
	local starter = ShopConfig.pack("StarterPack") :: ShopConfig.Pack
	heading("STARTER PACK")
	order += 1
	local banner = card(page, starter.color)
	banner.Name = "StarterPack"
	banner.LayoutOrder = order
	banner.Size = UDim2.new(1, 0, 0, 230)
	art(banner, starter.art, "Cosmico", UDim2.fromOffset(10, 10), UDim2.new(0.34, -10, 1, -20))
	local once = UiKit.label(banner, "ONE TIME ONLY", "status", 12)
	once.TextXAlignment = Enum.TextXAlignment.Center
	once.BackgroundColor3 = UiKit.ACCENT
	once.BackgroundTransparency = 0
	once.TextColor3 = Color3.fromRGB(40, 24, 0)
	once.Position = UDim2.new(0.36, 0, 0, 14)
	once.Size = UDim2.fromOffset(120, 20)
	once.ZIndex = 6
	local st = UiKit.label(banner, starter.name, "title", 32)
	st.Position = UDim2.new(0.36, 0, 0, 38)
	st.Size = UDim2.new(0.62, 0, 0, 38)
	st.ZIndex = 5
	contents(banner, starter, UDim.new(0.36, 0), 84, UDim.new(0.4, 0))
	local sb = buy(banner, "StarterPack")
	sb.AnchorPoint = Vector2.new(1, 1)
	sb.Position = UDim2.new(1, -14, 1, -14)
	sb.Size = UDim2.fromOffset(200, 46)

	-- VALUE PACKS
	heading("VALUE PACKS")
	local packs = section(330, 230)
	for i, pack in ShopConfig.PACKS do
		if not pack.oneTime then
			local c = card(packs, pack.color)
			c.LayoutOrder = i
			art(c, pack.art, if pack.id == "HatcherPack" then "Gelo" elseif pack.id == "HunterPack" then "Roccia" else "Eclissi",
				UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 110))
			title(c, pack.name, 122, 21)
			contents(c, pack, UDim.new(0, 14), 152, UDim.new(1, -28))
			buy(c, pack.id)
		end
	end

	-- UOVA
	heading("DRAGON EGGS", "Random element. Goes straight into your nest, even if it's full.")
	local eggs = section(300, 200)
	for i, e in ShopConfig.ROBUX_EGGS do
		local odds = ShopConfig.EGG_ODDS[e.id] or {}
		local tone = if e.id == "EpicEgg" then Color3.fromRGB(190, 90, 255) elseif e.id == "RareEgg" then Color3.fromRGB(90, 170, 255) else nil
		local c = card(eggs, tone)
		c.LayoutOrder = i
		art(c, "prod_" .. e.id, e.preview, UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 120))
		title(c, e.name, 132)
		local lines = {}
		for _, r in DragonConfig.RARITIES do
			if odds[r.id] then
				table.insert(lines, string.format("%s %d%%", Names.t(r.id), odds[r.id]))
			end
		end
		body(c, table.concat(lines, "  ·  "), 160, 60)
		buy(c, e.id)
	end

	-- POZIONI
	heading("POTIONS", "They go into your backpack and hotbar. Each one lasts 15 minutes; drinking more adds time.")
	local potions = section(260, 200)
	for i, id in { "PotionCoins", "PotionHatchLuck", "PotionShinyLuck", "PotionDropLuck" } do
		local def = Items.get(id) :: Items.Item
		local c = card(potions, def.color)
		c.LayoutOrder = i
		local img = icon(c, def.icon, def.fallback, 84)
		img.AnchorPoint = Vector2.new(0.5, 0)
		img.Position = UDim2.new(0.5, 0, 0, 12)
		title(c, def.name, 104)
		body(c, def.text, 132, 70)
		buy(c, id)
	end

	-- MONETE
	heading("COINS")
	local coins = section(220, 180)
	for i, p in ShopConfig.COIN_PACKS do
		local c = card(coins, UiKit.ACCENT)
		c.LayoutOrder = i
		local img = icon(c, "prod_" .. p.id, "icon_coin", 72 + i * 6)
		img.AnchorPoint = Vector2.new(0.5, 0)
		img.Position = UDim2.new(0.5, 0, 0, 10)
		title(c, string.format("%s", p.name), 106)
		local amount = title(c, string.format("%d coins", p.coins), 130, 22)
		amount.TextColor3 = UiKit.ACCENT
		buy(c, p.id)
	end

	-- AIUTI
	heading("HELPERS")
	local helpers = section(230, 200)
	for i, h in {
		{ "NestWarmer", "Nest Warmer", "Eggs in your nest hatch twice as fast (time left halved)." },
		{ "InstantHatch", "Instant Hatch", "Every egg in your nest is ready now." },
		{ "Revive", "Mountain Rescue", "Respawn where you fell." },
		{ "TrainingBoost", "Training Boost x3", "Triple training XP for 15 minutes." },
	} do
		local c = card(helpers)
		c.LayoutOrder = i
		local img = icon(c, "prod_" .. h[1], "icon_egg", 64)
		img.AnchorPoint = Vector2.new(0.5, 0)
		img.Position = UDim2.new(0.5, 0, 0, 12)
		title(c, h[2], 84)
		body(c, h[3], 112, 50)
		buy(c, h[1])
	end

	-- PASS (per sempre)
	heading("GAME PASSES", "Bought once, yours forever.")
	local passes = section(230, 200)
	for i, p in {
		{ "ExtraDragon", "+1 Dragon Follower", "Bring two dragons with you." },
		{ "FastIncubation", "Fast Incubation x2", "Eggs hatch in half the time." },
		{ "ExtraIncubator", "Big Nest", "+2 nest slots." },
		{ "EggFinder", "Egg Finder", "Compass to the nearest egg." },
		{ "TrainingX2", "Training XP x2", "Double training XP, forever." },
	} do
		local c = card(passes, Color3.fromRGB(190, 130, 255))
		c.LayoutOrder = i
		local img = icon(c, "pass_" .. p[1], nil, 64)
		img.AnchorPoint = Vector2.new(0.5, 0)
		img.Position = UDim2.new(0.5, 0, 0, 12)
		title(c, p[2], 84)
		body(c, p[3], 112, 50)
		buy(c, p[1])
	end

	-- testo e stato dei pulsanti (prezzo, posseduto, non ancora in vendita)
	local function paint()
		for _, e in buttons do
			local id = idOf(e.name)
			local packDef = ShopConfig.pack(e.name)
			local owned = player:GetAttribute("Pass_" .. e.name) == true or (packDef ~= nil and packDef.oneTime == true and player:GetAttribute("Comprato_" .. e.name) == true)
			UiKit.button(e.b, if owned or id <= 0 then "disabled" else "primary")
			e.b.Text = if owned then "OWNED" elseif id <= 0 then "COMING SOON" else priceText(e.name)
		end
		-- lo Starter Pack comprato sparisce (resta solo la scritta)
		banner.Visible = player:GetAttribute("Comprato_StarterPack") ~= true
	end
	player.AttributeChanged:Connect(function(name)
		if page.Visible and (string.sub(name, 1, 5) == "Pass_" or string.sub(name, 1, 9) == "Comprato_") then
			paint()
		end
	end)

	return {
		show = function(on: boolean)
			page.Visible = on
			list.Visible = not on
			if on then
				resize()
				paint()
				-- i prezzi veri arrivano dopo un attimo
				task.delay(1.5, function()
					if page.Visible then
						paint()
					end
				end)
			end
		end,
	}
end

return RobuxShop
