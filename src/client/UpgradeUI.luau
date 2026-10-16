--!strict
-- Potenziamenti (scalatore e draghi), taglie e rinascita nella pagina Upgrades del menu unico.
-- Le carte dei potenziamenti seguono il mockup scelto da Mirko il 15/10: a sinistra le carte
-- (icona, nome, barra a tacche del livello, "View upgrade"), a destra la scheda con livello
-- attuale e successivo, costo e Upgrade. Prima erano righe di testo una sotto l'altra.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("UpgradeConfig"))
local Names = require(Shared:WaitForChild("Names"))
local Ui = require(Shared:WaitForChild("UiView"))
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local player = Players.LocalPlayer
local UpgradeUI = {}
local PAGES = { "Player", "Dragon", "Bounties", "Rebirth" }
-- colore di ogni potenziamento (tacche, barre, raggi)
local COLORS = {
	Rampino = Theme.BLUE, Uncino = Theme.PURPLE, Lancio = Theme.ORANGE, Esoscheletro = Theme.GOOD,
	Scudo = Theme.TEAL, Stivali = Theme.ACCENT,
	Furia = Theme.BAD, Ali = Theme.TEAL, Maestria = Theme.PURPLE, Tesoro = Theme.ACCENT, Addestramento = Theme.GOOD,
} :: { [string]: Color3 }
-- i potenziamenti del drago non hanno ancora un'immagine loro: icone del set colorate
local DRAGON_ICONS = {
	Furia = "act_shoot", Ali = "act_jump", Maestria = "elem_Cosmico", Tesoro = "icon_coin", Addestramento = "icon_dragons",
} :: { [string]: string }
local function count(name: string): number
	for _, folder in { "Ores", "Materiali" } do
		local f = player:FindFirstChild(folder)
		local v = f and f:FindFirstChild(name)
		if v and v:IsA("IntValue") then
			return v.Value
		end
	end
	return 0
end
local function itemName(name: string): string
	local icons = RS:FindFirstChild("DropIcone")
	local map = icons and icons:FindFirstChild("Nomi")
	local shown = map and map:GetAttribute(name)
	if type(shown) == "string" then
		return shown
	end
	local fixed = { Pelliccia_Yeti = "Yeti Fur", Cristallo_Ghiaccio = "Ice Crystal", Nucleo_Glaciale = "Glacial Core" }
	return fixed[name] or Names.t(name)
end
local function decode(raw: any): any
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then data else nil
end
-- ctx: { sub = function(text) } dal menu (MainMenu)
function UpgradeUI.mount(container: Frame, status: (string, boolean) -> (), ctx: any?): () -> ()
	local list = Ui.node(container, "List")
	local page = "Player"
	local refresh: () -> ()
	local function uiScale(): number
		local gui = container:FindFirstAncestorWhichIsA("ScreenGui")
		local su = gui and gui:FindFirstChild("ScalaUI") :: UIScale?
		return if su and su.Scale > 0 then su.Scale else 1
	end
	local function call(action: string, arg: any)
		local ok, message = (RS.Remotes:WaitForChild("Upgrade") :: RemoteFunction):InvokeServer(action, arg)
		status(message or "", ok)
		refresh()
	end
	local function heading(value: string, order: number)
		local l = Ui.template("Heading", list)
		l.Text, l.LayoutOrder = value, order
	end
	-- schede in alto: Player / Dragon / Bounties / Rebirth (al posto delle tre del modello)
	local oldTabs = container:FindFirstChild("Tabs")
	if oldTabs and oldTabs:IsA("GuiObject") then
		oldTabs.Visible = false
	end
	local tabs = Theme.frame(container, Color3.new(), 1)
	tabs.Name = "SchedeNuove"
	tabs.Size = UDim2.new(1, 0, 0, 44)
	tabs.ClipsDescendants = false
	local tabButtons: { [string]: TextButton } = {}
	for i, name in PAGES do
		local b = Instance.new("TextButton")
		b.Name = name
		b.Text = name
		b.Position = UDim2.new((i - 1) / #PAGES, if i > 1 then 4 else 0, 0, 2)
		b.Size = UDim2.new(1 / #PAGES, -6, 1, -4)
		b.Parent = tabs
		tabButtons[name] = b
		b.Activated:Connect(function()
			page = name
			refresh()
		end)
	end
	local pageBox = Theme.frame(container, Color3.new(), 1)
	pageBox.Name = "PaginaPotenziamenti"
	pageBox.ClipsDescendants = false
	local cardsBox = Theme.frame(pageBox, Color3.new(), 1)
	local cardList = Theme.scroll(cardsBox)
	cardList.ScrollBarThickness = 6
	local cpad = Instance.new("UIPadding")
	cpad.PaddingTop, cpad.PaddingLeft, cpad.PaddingRight, cpad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 10), UDim.new(0, 16)
	cpad.Parent = cardList
	local cardGrid = Instance.new("UIGridLayout")
	cardGrid.CellPadding = UDim2.fromOffset(14, 14)
	cardGrid.SortOrder = Enum.SortOrder.LayoutOrder
	cardGrid.Parent = cardList
	local side = Theme.frame(pageBox, Theme.DARK, 1)
	side.Name = "Scheda"
	UiKit.panel(side, { transparency = 0.22 })
	local chosen: { [string]: string } = {}

	local function tone(u: any): Color3
		return COLORS[u.id] or Theme.ACCENT
	end
	local function iconFor(img: ImageLabel, u: any)
		local asset = DRAGON_ICONS[u.id] or ("item_Upgrade" .. u.id)
		Theme.assetPreview(img, asset, nil)
		img.ImageColor3 = if string.sub(asset, 1, 4) == "act_" then tone(u) else Color3.new(1, 1, 1)
	end
	local function txt(parent: Instance, str: string, size: number, color: Color3, bold: boolean?): TextLabel
		local l = Theme.label(parent, str, size, color, bold)
		l.ZIndex = 4
		return l
	end
	local function box(parent: Instance): Frame
		local f = Theme.frame(parent, Theme.DARK2, 0.2)
		f.ZIndex = 3
		Theme.corner(f, 12)
		local s = Instance.new("UIStroke")
		s.Color = Theme.DARK3
		s.Thickness = 1.5
		s.Transparency = 0.2
		s:SetAttribute("KeepStroke", true)
		s.Parent = f
		return f
	end
	-- barra a tacche: una tacca per livello
	local function segments(parent: Instance, u: any, level: number): Frame
		local row = Theme.frame(parent, Theme.DARK, 0.3)
		Theme.corner(row, 8)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
		pad.Parent = row
		local l = Theme.list(row, 6, true)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		for i = 1, u.max do
			local seg = Theme.frame(row, if i <= level then tone(u) else Theme.DARK3, 0)
			seg.LayoutOrder = i
			seg.Size = UDim2.new(1 / u.max, -6, 0, 14)
			seg.ZIndex = 4
			Theme.corner(seg, 5)
		end
		return row
	end

	-- Scheda di destra: intestazione (icona, nome, tipo), corpo che scorre (ora -> dopo, cosa fa,
	-- perche' e' bloccato) e PIEDE FISSO col costo e il pulsante. Sul telefono il pulsante
	-- Unlock/Upgrade finiva fuori dallo schermo (Mirko 16/10): ora il piede sta sempre dentro e,
	-- se manca altezza, scorre solo il corpo sopra.
	local function detail(u: any)
		for _, c in side:GetChildren() do
			if c:IsA("GuiObject") and c.Name ~= "FondoScuro" then
				c:Destroy()
			end
		end
		local level = Config.level(player, u.id)
		local maxed = level >= u.max
		local h = side.AbsoluteSize.Y / uiScale()
		local short = h < 420
		-- requisiti del livello dopo: monete, materiali, cosa manca
		local lines = {}
		local missing: string? = nil
		local lack = 0
		local coinsOk = true
		local cost = if maxed then nil else u.costs[level + 1]
		if cost then
			local coins = (player:GetAttribute("Coins") or 0) :: number
			coinsOk = coins >= cost.coins
			table.insert(lines, string.format('<font color="%s">%s %d coins</font>', if coinsOk then "#7BE08A" else "#FF8C94", if coinsOk then "✔" else "✖", cost.coins))
			local names = {}
			for item in cost.items do
				table.insert(names, item)
			end
			table.sort(names)
			for _, item in names do
				local n = cost.items[item]
				local have = count(item)
				if have < n and not missing then
					missing, lack = item, n - have
				end
				table.insert(lines, string.format('<font color="%s">%s %s %d/%d</font>', if have >= n then "#7BE08A" else "#FF8C94", if have >= n then "✔" else "✖", itemName(item), have, n))
			end
		end
		local ready = not maxed and missing == nil and coinsOk
		local why: string? = nil
		if maxed then
			why = "Fully upgraded."
		elseif not coinsOk then
			why = string.format("Not enough coins: you need %d more.", cost.coins - math.floor((player:GetAttribute("Coins") or 0) :: number))
		elseif missing then
			why = string.format("You need %d more %s. %s", lack, itemName(missing), Config.SOURCES[missing] or "Found on the mountain.")
		end

		-- INTESTAZIONE
		local iconS = if short then 52 else 96
		local big = Instance.new("ImageLabel")
		big.BackgroundTransparency = 1
		big.Position = UDim2.fromOffset(12, 10)
		big.Size = UDim2.fromOffset(iconS, iconS)
		big.ZIndex = 4
		big.Parent = side
		iconFor(big, u)
		local name = UiKit.label(side, u.name, "name", if short then 22 else 30)
		name.ZIndex = 4
		name.Position = UDim2.fromOffset(iconS + 22, if short then 8 else 18)
		name.Size = UDim2.new(1, -(iconS + 32), 0, if short then 28 else 36)
		local kind = UiKit.label(side, string.format("%s  ·  LV %d / %d", if u.group == "Dragon" then "DRAGON UPGRADE" else "PLAYER UPGRADE", level, u.max), "status")
		kind.TextColor3 = tone(u)
		kind.ZIndex = 4
		kind.Position = UDim2.fromOffset(iconS + 22, if short then 36 else 56)
		kind.Size = UDim2.new(1, -(iconS + 32), 0, 18)
		local headH = iconS + 18

		-- PIEDE FISSO: costo a sinistra, pulsante a destra, riga del motivo sotto
		local footH = if short then 96 else 128
		local foot = Theme.frame(side, UiKit.INK, 0.25)
		foot.Name = "Piede"
		foot.AnchorPoint = Vector2.new(0, 1)
		foot.Position = UDim2.new(0, 8, 1, -8)
		foot.Size = UDim2.new(1, -16, 0, footH)
		foot.ZIndex = 3
		UiKit.edge(foot, UiKit.LINE, 1, 0.8)
		local ct = UiKit.label(foot, if maxed then "Max level" else "Upgrade cost", "section", if short then 14 else 17)
		ct.ZIndex = 4
		ct.Position = UDim2.fromOffset(12, 6)
		ct.Size = UDim2.new(0.55, -12, 0, 20)
		local cl = UiKit.label(foot, table.concat(lines, "\n"), "body", if short then 14 else 16)
		cl.RichText = true
		cl.ZIndex = 4
		cl.TextYAlignment = Enum.TextYAlignment.Top
		cl.Position = UDim2.fromOffset(12, if short then 26 else 30)
		cl.Size = UDim2.new(0.55, -12, 1, -(if short then 30 else 36))
		local btn = Instance.new("TextButton")
		btn.Name = "Compra"
		btn.AnchorPoint = Vector2.new(1, 0)
		btn.Position = UDim2.new(1, -10, 0, 10)
		btn.Size = UDim2.new(0.45, -10, 0, if short then 44 else 54)
		btn.ZIndex = 5
		btn.Parent = foot
		UiKit.button(btn, if ready then "primary" else "disabled")
		btn.Text = if maxed then "MAX" elseif level == 0 then "UNLOCK" else "UPGRADE"
		local whyLabel = UiKit.label(foot, if ready then "Ready!" else (why or ""), "secondary", 13)
		whyLabel.TextColor3 = if ready then UiKit.GOOD else UiKit.MUTED
		whyLabel.TextWrapped = true
		whyLabel.TextTruncate = Enum.TextTruncate.None
		whyLabel.TextYAlignment = Enum.TextYAlignment.Top
		whyLabel.ZIndex = 4
		whyLabel.AnchorPoint = Vector2.new(1, 0)
		whyLabel.Position = UDim2.new(1, -10, 0, (if short then 44 else 54) + 14)
		whyLabel.Size = UDim2.new(0.45, -10, 1, -((if short then 44 else 54) + 16))
		btn.Activated:Connect(function()
			if ready then
				call("buy", u.id)
			else
				-- spiega il blocco invece di non fare niente
				status(why or "Not available", false)
			end
		end)

		-- CORPO che scorre tra intestazione e piede
		local body = Theme.scroll(side)
		body.Name = "Corpo"
		body.ZIndex = 3
		body.ScrollBarThickness = 4
		body.Position = UDim2.fromOffset(8, headH)
		body.Size = UDim2.new(1, -16, 1, -(headH + footH + 16))
		local bl = Theme.list(body, 8)
		bl.Name = "Righe"
		local bpad = Instance.new("UIPadding")
		bpad.PaddingBottom = UDim.new(0, 8)
		bpad.PaddingRight = UDim.new(0, 6)
		bpad.Parent = body
		local boxH = if short then 74 else 92
		local levels = Theme.frame(body, Color3.new(), 1)
		levels.LayoutOrder = 1
		levels.Size = UDim2.new(1, 0, 0, boxH)
		levels.ZIndex = 3
		local function levelBox(x: UDim, title: string, lv: number, effect: string, color: Color3)
			local b = Theme.frame(levels, UiKit.RAISED, 0.25)
			b.Position = UDim2.new(x.Scale, x.Offset, 0, 0)
			b.Size = UDim2.new(0.5, -16, 1, 0)
			b.ZIndex = 3
			UiKit.edge(b, UiKit.LINE, 1, 0.8)
			local t = UiKit.label(b, title, "status")
			t.ZIndex = 4
			t.Position = UDim2.fromOffset(10, 6)
			t.Size = UDim2.new(1, -20, 0, 18)
			-- barra incassata: scanalatura scura e riempimento dentro
			local back = Theme.frame(b, UiKit.INK, 0)
			back.Position = UDim2.fromOffset(10, 28)
			back.Size = UDim2.new(1, -20, 0, 10)
			back.ZIndex = 4
			UiKit.edge(back, Color3.new(0, 0, 0), 1, 0.3)
			local fill = Theme.frame(back, color, 0)
			fill.Size = UDim2.fromScale(math.clamp(lv / u.max, 0, 1), 1)
			fill.ZIndex = 5
			local e = UiKit.label(b, effect, "name", if short then 15 else 17)
			e.TextColor3 = color
			e.TextWrapped = true
			e.ZIndex = 4
			e.Position = UDim2.fromOffset(10, 42)
			e.Size = UDim2.new(1, -20, 1, -46)
		end
		levelBox(UDim.new(0, 0), string.format("NOW · LV %d", level), level, u.text(level), UiKit.MUTED)
		local arrow = UiKit.label(levels, ">", "name", 26)
		arrow.TextColor3 = UiKit.ACCENT
		arrow.TextXAlignment = Enum.TextXAlignment.Center
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Position = UDim2.fromScale(0.5, 0.5)
		arrow.Size = UDim2.fromOffset(28, 30)
		arrow.ZIndex = 4
		if maxed then
			levelBox(UDim.new(0.5, 16), "MAX LEVEL", u.max, "Fully upgraded!", UiKit.ACCENT)
		else
			levelBox(UDim.new(0.5, 16), string.format("NEXT · LV %d", level + 1), level + 1, u.text(level + 1), tone(u))
		end
		local desc = UiKit.label(body, u.description, "body", if short then 14 else 16)
		desc.LayoutOrder = 2
		desc.TextWrapped = true
		desc.TextTruncate = Enum.TextTruncate.None
		desc.AutomaticSize = Enum.AutomaticSize.Y
		desc.Size = UDim2.new(1, 0, 0, 20)
		desc.ZIndex = 4
	end
	local function upgrades(group: string)
		local shown: { any } = {}
		for _, u in Config.UPGRADES do
			if (u.group or "Player") == group then
				table.insert(shown, u)
			end
		end
		for _, c in cardList:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local sel = chosen[group]
		if not sel or not Config.find(sel) then
			sel = shown[1] and shown[1].id
			chosen[group] = sel
		end
		-- carte basse sul telefono (icona piccola, descrizione su due righe, tacche e "View"),
		-- quelle grandi del mockup sul computer
		local small = cardGrid.CellSize.Y.Offset < 180
		local narrow = cardGrid.CellSize.X.Offset < 300
		local ic = if small then 46 elseif narrow then 72 else 100
		for k, u in shown do
			local level = Config.level(player, u.id)
			local on = u.id == sel
			local c = Instance.new("TextButton")
			c.Name = u.id
			c.Text = ""
			c.AutoButtonColor = false
			c.LayoutOrder = k
			c:SetAttribute("UiNative", true)
			c.Parent = cardList
			UiKit.card(c, on, tone(u))
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Position = UDim2.fromOffset(if small then 8 else 12, if small then 8 else 12)
			img.Size = UDim2.fromOffset(ic, ic)
			img.ZIndex = 3
			img.Parent = c
			iconFor(img, u)
			local tx = ic + (if small then 14 else 22)
			local n = UiKit.label(c, u.name, "name", if small then 17 else 22)
			n.ZIndex = 4
			n.Position = UDim2.fromOffset(tx, if small then 6 else 14)
			n.Size = UDim2.new(1, -(tx + 8), 0, if small then 22 else 30)
			local d = UiKit.label(c, u.description, "secondary", if small then 13 else nil)
			d.ZIndex = 4
			d.TextWrapped = true
			d.TextTruncate = Enum.TextTruncate.AtEnd
			d.TextYAlignment = Enum.TextYAlignment.Top
			d.Position = UDim2.fromOffset(tx, if small then 28 else 46)
			d.Size = UDim2.new(1, -(tx + 8), 0, if small then 32 else 60)
			local seg = segments(c, u, level)
			seg.Position = if small then UDim2.new(0, 8, 1, -34) else UDim2.new(0, 14, 1, -88)
			seg.Size = if small then UDim2.new(1, -96, 0, 24) else UDim2.new(1, -28, 0, 26)
			seg.ZIndex = 3
			local view = Instance.new("TextButton")
			view.Name = "Vedi"
			view.ZIndex = 4
			view.Parent = c
			if small then
				view.AnchorPoint = Vector2.new(1, 1)
				view.Position = UDim2.new(1, -8, 1, -8)
				view.Size = UDim2.fromOffset(80, 30)
			else
				view.AnchorPoint = Vector2.new(0, 1)
				view.Position = UDim2.new(0, 14, 1, -12)
				view.Size = UDim2.new(1, -28, 0, 44)
			end
			-- anche al massimo la scheda si apre (prima il pulsante era spento)
			UiKit.button(view, if on then "primary" else "secondary")
			view.Text = if small then (if level >= u.max then "MAX" else "VIEW  >") elseif level >= u.max then "MAX LEVEL  >" else "VIEW UPGRADE  >"
			view.TextSize = if small then 14 else view.TextSize
			local function pick()
				chosen[group] = u.id
				refresh()
			end
			c.Activated:Connect(pick)
			view.Activated:Connect(pick)
		end
		local u = Config.find(sel or "")
		if u then
			detail(u)
		end
		if ctx and ctx.sub then
			ctx.sub(if group == "Dragon" then "Boosts for all your dragons" else "Boosts for you")
		end
	end
	local function bounties()
		local data = decode(player:GetAttribute("BountyData"))
		if not data then
			heading("Loading bounties...", 0)
			return
		end
		local function row(
			order: number,
			title: string,
			progress: number,
			need: number,
			reward: string,
			claimed: boolean,
			action: string,
			arg: any
		)
			local c = Ui.template("BountyCard", list)
			c.LayoutOrder = order
			c.Title.Text = title
			c.Progress.Fill.Size = UDim2.fromScale(math.clamp(progress / math.max(need, 1), 0, 1), 1)
			c.Reward.Text = string.format("%d/%d · Reward: %s", progress, need, reward)
			c.Claim.Text = if claimed then "Claimed" elseif progress >= need then "Claim" else "In progress"
			c.Claim.Activated:Connect(function()
				if not claimed and progress >= need then
					call(action, arg)
				end
			end)
		end
		local d = data.daily
		if d then
			heading(string.format("Daily challenge · new one in %d h", math.floor((data.resetIn or 0) / 3600)), 0)
			row(1, d.text, d.progress, d.need, string.format("%d coins", d.coins), d.claimed, "daily", nil)
		end
		heading("Bounties · claim one to receive a new one", 2)
		for k, b in data.bounties or {} do
			local reward = string.format("%d coins", b.coins)
			for name, n in b.items or {} do
				reward ..= string.format(" + %d %s", n, itemName(name))
			end
			row(k + 2, b.text, b.progress, b.need, reward, false, "claim", k)
		end
	end
	-- Rinascita: pannello "di vetro" sopra lo sfondo della finestra (piace molto ai giocatori: si
	-- deve vedere), titolo grande, ora/dopo coi bonus in grande, cosa tieni e cosa perdi, requisiti
	-- con la spunta e un pulsante grande che si accende solo quando si puo'
	local function rebirth()
		local R = Config.REBIRTH
		local n = (player:GetAttribute("Rebirths") or 0) :: number
		local since = (player:GetAttribute("SummitsSinceRebirth") or 0) :: number
		local coins = (player:GetAttribute("Coins") or 0) :: number
		local summitOk, coinsOk = since >= 1, coins >= R.MIN_COINS
		local ready = summitOk and coinsOk
		local GOLD = Theme.ACCENT
		local function glass(parent: Instance, h: number, order: number): Frame
			local f = Theme.frame(parent, Theme.CARD, 0.35)
			f.Size = UDim2.new(1, -12, 0, h)
			f.LayoutOrder = order
			Theme.corner(f, 16)
			Theme.stroke(f, GOLD, 2, 0.55)
			return f
		end
		local function text(parent: Instance, str: string, size: number, color: Color3, x: number, y: number, w: UDim, h: number, align: Enum.TextXAlignment?): TextLabel
			local l = Theme.label(parent, str, size, color, true)
			l.Font = Enum.Font.GothamBlack
			l.TextScaled = true
			l.Position = UDim2.new(0, x, 0, y)
			l.Size = UDim2.new(w.Scale, w.Offset, 0, h)
			l.TextXAlignment = align or Enum.TextXAlignment.Left
			l.TextStrokeTransparency = 0.25
			local c = l:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
			c.MaxTextSize = size
			c.MinTextSize = 12
			c.Parent = l
			return l
		end
		local hero = glass(list, 430, 1)
		hero.Name = "Rinascita"
		text(hero, "REBIRTH", 44, GOLD, 24, 16, UDim.new(0.6, 0), 48)
		text(hero, string.format("Level %d  →  %d", n, n + 1), 22, Color3.new(1, 1, 1), 24, 66, UDim.new(0.6, 0), 28)
		-- ora / dopo
		local function bonus(x: number, title: string, k: number, color: Color3)
			local box = Theme.frame(hero, Theme.CARD, 0.2)
			box.Position = UDim2.new(x, if x == 0 then 24 else 8, 0, 108)
			box.Size = UDim2.new(0.5, -32, 0, 110)
			Theme.corner(box, 12)
			Theme.stroke(box, color, 2, 0.4)
			local t = text(box, title, 16, Theme.MUTED, 14, 8, UDim.new(1, -28), 20)
			t.TextXAlignment = Enum.TextXAlignment.Center
			text(box, string.format("+%d%% coins", math.floor(k * R.COIN_BONUS * 100 + 0.5)), 30, color, 14, 32, UDim.new(1, -28), 36, Enum.TextXAlignment.Center)
			text(box, string.format("+%d%% dragon XP", math.floor(k * R.XP_BONUS * 100 + 0.5)), 20, color, 14, 72, UDim.new(1, -28), 26, Enum.TextXAlignment.Center)
		end
		bonus(0, "NOW", n, Theme.MUTED)
		bonus(0.5, "AFTER REBIRTH", n + 1, Theme.GOOD)
		-- tieni / perdi
		text(hero, "✔  You keep: dragons, gear, your house", 18, Theme.GOOD, 24, 232, UDim.new(1, -48), 24)
		text(hero, "✖  You lose: coins, ores, upgrades", 18, Theme.BAD, 24, 260, UDim.new(1, -48), 24)
		-- requisiti
		local function need(ok: boolean, str: string, y: number)
			text(hero, (if ok then "✔  " else "✖  ") .. str, 18, if ok then Theme.GOOD else Theme.ACCENT, 24, y, UDim.new(1, -48), 24)
		end
		need(summitOk, "Reach the summit", 300)
		need(coinsOk, string.format("Have %d coins  (you have %d)", R.MIN_COINS, math.floor(coins)), 328)
		-- pulsante
		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(0.5, 1)
		btn.Position = UDim2.new(0.5, 0, 1, -16)
		btn.Size = UDim2.new(1, -48, 0, 60)
		btn.Font = Enum.Font.GothamBlack
		btn.TextScaled = true
		btn.Text = if ready then "REBIRTH" else "NOT READY YET"
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.TextStrokeTransparency = 0.2
		Theme.action(btn, "main", not ready)
		btn.AutoButtonColor = ready
		btn.Parent = hero
		Theme.corner(btn, 14)
		Theme.gradient(btn, Color3.new(1, 1, 1), Theme.MUTED, 90)
		local bc = btn:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		bc.MaxTextSize = 28
		bc.MinTextSize = 12
		bc.Parent = btn
		local bp = btn:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
		bp.PaddingTop, bp.PaddingBottom = UDim.new(0.18, 0), UDim.new(0.18, 0)
		bp.Parent = btn
		local armed = false
		btn.Activated:Connect(function()
			if not ready then
				status("Reach the summit and have enough coins first", false)
				return
			end
			if not armed then
				armed = true
				btn.Text = "SURE? TAP AGAIN"
				task.delay(3, function()
					if btn.Parent then
						armed = false
						btn.Text = "REBIRTH"
					end
				end)
				return
			end
			call("rebirth", nil)
		end)
		-- statistiche e classifica, nello stesso vetro
		local best = player:GetAttribute("BestDescent")
		local top = decode(workspace:GetAttribute("DescentTop")) or {}
		local stats = glass(list, 64 + 30 * math.max(1, math.min(#top, 5)), 2)
		text(stats, string.format("Summits %d   ·   Enemies %d   ·   Bosses %d   ·   Best descent %s",
			player:GetAttribute("Summits") or 0,
			player:GetAttribute("Kills") or 0,
			player:GetAttribute("BossKills") or 0,
			if type(best) == "number" then string.format("%.1f s", best) else "-"), 17, Color3.new(1, 1, 1), 20, 12, UDim.new(1, -40), 22)
		text(stats, "Fastest descents", 16, GOLD, 20, 38, UDim.new(1, -40), 20)
		if #top == 0 then
			text(stats, "No records yet: be the first!", 16, Theme.MUTED, 20, 62, UDim.new(1, -40), 22)
		end
		for i, e in top do
			if i > 5 then
				break
			end
			text(stats, string.format("%d.  %s  —  %.1f s", i, e.name, e.seconds), 16, Theme.TEXT, 20, 32 + 30 * i, UDim.new(1, -40), 22)
		end
	end
	local function layout()
		local w = container.AbsoluteSize.X / uiScale()
		if w < 50 then
			return
		end
		local h = container.AbsoluteSize.Y / uiScale()
		local low = h < 420 -- telefono in orizzontale
		local tabH = if low then 34 else 44
		tabs.Size = UDim2.new(1, 0, 0, tabH)
		for _, b in tabButtons do
			b.TextSize = if low then 15 else 19
		end
		local gapY = if low then 6 else 10
		list.Position = UDim2.fromOffset(0, tabH + gapY)
		list.Size = UDim2.new(1, 0, 1, -(tabH + gapY))
		pageBox.Position = UDim2.fromOffset(0, tabH + gapY)
		pageBox.Size = UDim2.new(1, 0, 1, -(tabH + gapY))
		-- carte a sinistra (circa 58%), scheda a destra (42%): anche sul telefono in orizzontale,
		-- come il riferimento di Mirko. Solo una pagina davvero stretta mette la scheda sotto
		local stacked = w < 600
		local sideW = if stacked then w else math.clamp(math.floor(w * 0.42), 300, 460)
		local cardsH, sideH = 250, 440
		if stacked then
			cardsBox.Position = UDim2.fromOffset(0, 0)
			cardsBox.Size = UDim2.new(1, 0, 0, cardsH)
			side.Position = UDim2.fromOffset(0, cardsH + 12)
			side.Size = UDim2.new(1, 0, 0, sideH)
		else
			cardsBox.Position = UDim2.fromOffset(0, 0)
			cardsBox.Size = UDim2.new(1, -(sideW + 14), 1, 0)
			side.Position = UDim2.new(1, -sideW, 0, 0)
			side.Size = UDim2.new(0, sideW, 1, 0)
		end
		local wantH = if stacked and (page == "Player" or page == "Dragon") then tabH + 10 + cardsH + 12 + sideH else 0
		if container:GetAttribute("AltezzaMinima") ~= wantH then
			container:SetAttribute("AltezzaMinima", wantH)
			if ctx and ctx.fit then
				task.defer(ctx.fit)
			end
		end
		local gw = if stacked then w - 18 else w - sideW - 14 - 18
		local cols = if gw > 440 then 2 else 1
		local cellW = math.floor((gw - (cols - 1) * 14) / cols)
		cardGrid.CellSize = UDim2.fromOffset(cellW, if low then 112 elseif cellW < 300 then 210 else 224)
		cardGrid.CellPadding = UDim2.fromOffset(if low then 8 else 14, if low then 8 else 14)
	end
	container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		layout()
		if container.Visible and (page == "Player" or page == "Dragon") then
			refresh()
		end
	end)
	refresh = function()
		layout()
		Ui.clear(list)
		for name, b in tabButtons do
			local on = name == page
			b.Text = name
			UiKit.tab(b, on)
		end
		local cardsPage = page == "Player" or page == "Dragon"
		pageBox.Visible = cardsPage
		list.Visible = not cardsPage
		if cardsPage then
			upgrades(page)
		elseif page == "Bounties" then
			if ctx and ctx.sub then
				ctx.sub("Claim one to get a new one")
			end
			bounties()
		else
			if ctx and ctx.sub then
				ctx.sub("Start again, stronger")
			end
			rebirth()
		end
	end
	local function onChange()
		if container.Parent and container.Visible then
			refresh()
		end
	end
	for _, attr in { "Coins", "BountyData", "Rebirths", "Summits", "SummitsSinceRebirth", "Kills", "BossKills", "BestDescent" } do
		player:GetAttributeChangedSignal(attr):Connect(onChange)
	end
	for _, u in Config.UPGRADES do
		player:GetAttributeChangedSignal("Up_" .. u.id):Connect(onChange)
	end
	workspace:GetAttributeChangedSignal("DescentTop"):Connect(onChange)
	return refresh
end
return UpgradeUI
