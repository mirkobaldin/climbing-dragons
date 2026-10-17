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
	-- Pannelli di Bounties e Rebirth nello stesso stile della pagina Player (Mirko 16/10: erano
	-- ancora riquadri blu e una pillola azzurra "NOT READY YET"): pannello con la cornice di Codex,
	-- testi di UiKit, barre incassate con la cornice, pulsanti di UiKit
	local function panel(h: number, order: number): Frame
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.Size = UDim2.new(1, -12, 0, h)
		f.LayoutOrder = order
		f.Parent = list
		UiKit.panel(f, { border = 10 })
		return f
	end
	local function label(parent: Instance, str: string, kind: any, x: number, y: number, w: UDim, h: number, size: number?): TextLabel
		local l = UiKit.label(parent, str, kind, size)
		l.ZIndex = 4
		l.Position = UDim2.fromOffset(x, y)
		l.Size = UDim2.new(w.Scale, w.Offset, 0, h)
		return l
	end
	-- barra incassata (scanalatura scura e riempimento), con la cornice delle barre se c'e'
	local function meter(parent: Instance, ratio: number, color: Color3, x: number, y: number, w: UDim, h: number): Frame
		local back = Theme.frame(parent, UiKit.INK, 0)
		back.Position = UDim2.fromOffset(x, y)
		back.Size = UDim2.new(w.Scale, w.Offset, 0, h)
		back.ZIndex = 4
		local fill = Theme.frame(back, color, 0)
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		fill.ZIndex = 5
		if not UiKit.Cornici.apply(back, "frame_bar_xp", { mode = "outset", z = 6 }) then
			UiKit.edge(back, Color3.new(0, 0, 0), 1, 0.3)
		end
		return back
	end
	local function bounties()
		local data = decode(player:GetAttribute("BountyData"))
		if not data then
			local l = UiKit.label(list, "Loading bounties...", "section")
			l.LayoutOrder = 0
			return
		end
		local function section(str: string, order: number)
			local l = UiKit.label(list, str, "section")
			l.LayoutOrder = order
			l.Size = UDim2.new(1, -12, 0, 30)
			l.TextColor3 = UiKit.ACCENT
		end
		local function row(order: number, title: string, progress: number, need: number, reward: string, claimed: boolean, action: string, arg: any)
			local done = progress >= need
			local c = panel(104, order)
			local bw = 190 -- spazio del pulsante a destra
			label(c, title, "name", 22, 14, UDim.new(1, -(bw + 40)), 28)
			meter(c, progress / math.max(need, 1), if claimed then UiKit.DIM elseif done then UiKit.GOOD else UiKit.ICE, 24, 50, UDim.new(1, -(bw + 48)), 12)
			local r = label(c, string.format("%d / %d   ·   Reward: %s", math.min(progress, need), need, reward), "body", 22, 68, UDim.new(1, -(bw + 40)), 24)
			r.TextColor3 = UiKit.MUTED
			local btn = Instance.new("TextButton")
			btn.Name = "Riscatta"
			btn.AnchorPoint = Vector2.new(1, 0.5)
			btn.Position = UDim2.new(1, -18, 0.5, 0)
			btn.Size = UDim2.fromOffset(bw - 20, 50)
			btn.ZIndex = 5
			btn.Parent = c
			UiKit.button(btn, if claimed or not done then "disabled" else "primary")
			btn.Text = if claimed then "CLAIMED" elseif done then "CLAIM" else "IN PROGRESS"
			btn.Activated:Connect(function()
				if not claimed and done then
					call(action, arg)
				end
			end)
		end
		local d = data.daily
		if d then
			section(string.format("Daily challenge  ·  new one in %d h", math.floor((data.resetIn or 0) / 3600)), 0)
			row(1, d.text, d.progress, d.need, string.format("%d coins", d.coins), d.claimed, "daily", nil)
		end
		section("Bounties  ·  claim one to receive a new one", 2)
		for k, b in data.bounties or {} do
			local reward = string.format("%d coins", b.coins)
			for name, n in b.items or {} do
				reward ..= string.format(" + %d %s", n, itemName(name))
			end
			row(k + 2, b.text, b.progress, b.need, reward, false, "claim", k)
		end
	end
	-- Rinascita: titolo, ORA -> DOPO coi bonus in grande (riquadri come "NOW / NEXT" della scheda
	-- dei potenziamenti), cosa tieni e cosa perdi, requisiti con la spunta, pulsante di UiKit che si
	-- accende solo quando si puo'
	local function rebirth()
		local R = Config.REBIRTH
		local n = (player:GetAttribute("Rebirths") or 0) :: number
		local since = (player:GetAttribute("SummitsSinceRebirth") or 0) :: number
		local coins = (player:GetAttribute("Coins") or 0) :: number
		local cost = Config.rebirthCost(player)
		local summitOk, coinsOk = since >= 1, coins >= cost
		local ready = summitOk and coinsOk
		local hero = panel(392, 1)
		hero.Name = "Rinascita"
		local t = label(hero, "REBIRTH", "title", 26, 16, UDim.new(0.6, 0), 40, 36)
		t.TextColor3 = UiKit.ACCENT
		label(hero, string.format("Level %d  >  %d", n, n + 1), "section", 26, 58, UDim.new(0.6, 0), 24)
		-- ora / dopo: due riquadri in rilievo con la freccia in mezzo
		local function bonus(x: UDim, title: string, k: number, color: Color3)
			local box = Theme.frame(hero, UiKit.RAISED, 0.25)
			box.Position = UDim2.new(x.Scale, x.Offset, 0, 94)
			box.Size = UDim2.new(0.5, -44, 0, 104)
			box.ZIndex = 3
			UiKit.edge(box, if color == UiKit.GOOD then UiKit.GOOD else UiKit.LINE, 1, if color == UiKit.GOOD then 0.5 else 0.8)
			local tt = label(box, title, "status", 0, 8, UDim.new(1, 0), 18)
			tt.TextXAlignment = Enum.TextXAlignment.Center
			local a = label(box, string.format("+%d%% coins", math.floor(k * R.COIN_BONUS * 100 + 0.5)), "stat", 0, 30, UDim.new(1, 0), 36, 30)
			a.TextXAlignment = Enum.TextXAlignment.Center
			a.TextColor3 = color
			local b2 = label(box, string.format("+%d%% dragon XP", math.floor(k * R.XP_BONUS * 100 + 0.5)), "name", 0, 68, UDim.new(1, 0), 26, 18)
			b2.TextXAlignment = Enum.TextXAlignment.Center
			b2.TextColor3 = color
		end
		bonus(UDim.new(0, 26), "NOW", n, UiKit.MUTED)
		bonus(UDim.new(0.5, 18), "AFTER REBIRTH", n + 1, UiKit.GOOD)
		local arrow = label(hero, ">", "title", 0, 128, UDim.new(0, 30), 36, 30)
		arrow.AnchorPoint = Vector2.new(0.5, 0)
		arrow.Position = UDim2.new(0.5, 0, 0, 128)
		arrow.TextXAlignment = Enum.TextXAlignment.Center
		arrow.TextColor3 = UiKit.ACCENT
		-- tieni / perdi, requisiti
		local keep = label(hero, "✔  You keep: dragons, gear, your house", "body", 26, 214, UDim.new(0.5, -30), 24, 17)
		keep.TextColor3 = UiKit.GOOD
		local lose = label(hero, "✖  You lose: coins, ores, upgrades", "body", 26, 240, UDim.new(0.5, -30), 24, 17)
		lose.TextColor3 = UiKit.BAD
		local reqT = label(hero, "TO REBIRTH", "status", 0, 214, UDim.new(0.5, -30), 18)
		reqT.Position = UDim2.new(0.5, 18, 0, 214)
		local function need(ok: boolean, str: string, y: number)
			local l = label(hero, (if ok then "✔  " else "✖  ") .. str, "body", 0, y, UDim.new(0.5, -44), 24, 17)
			l.Position = UDim2.new(0.5, 18, 0, y)
			l.TextColor3 = if ok then UiKit.GOOD else UiKit.ACCENT
		end
		need(summitOk, "Reach the summit", 236)
		need(coinsOk, string.format("Have %d coins  (you have %d)", cost, math.floor(coins)), 260)
		local btn = Instance.new("TextButton")
		btn.Name = "Rinasci"
		btn.AnchorPoint = Vector2.new(0.5, 1)
		btn.Position = UDim2.new(0.5, 0, 1, -22)
		btn.Size = UDim2.new(0.6, 0, 0, 58)
		btn.ZIndex = 5
		btn.Parent = hero
		UiKit.button(btn, if ready then "primary" else "disabled")
		btn.Text = if ready then "REBIRTH" else "NOT READY YET"
		btn.TextSize = 22
		local armed = false
		btn.Activated:Connect(function()
			if not ready then
				status("Reach the summit and have enough coins first", false)
				return
			end
			if not armed then
				armed = true
				btn.Text = if Ui.touch() then "SURE? TAP AGAIN" else "SURE? CLICK AGAIN"
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
		-- statistiche e classifica delle discese
		local best = player:GetAttribute("BestDescent")
		local top = decode(workspace:GetAttribute("DescentTop")) or {}
		local rowsN = math.max(1, math.min(#top, 5))
		local stats = panel(84 + 28 * rowsN, 2)
		stats.Name = "Record"
		local st = label(stats, string.format("Summits %d   ·   Enemies %d   ·   Bosses %d   ·   Best descent %s",
			player:GetAttribute("Summits") or 0,
			player:GetAttribute("Kills") or 0,
			player:GetAttribute("BossKills") or 0,
			if type(best) == "number" then string.format("%.1f s", best) else "-"), "name", 24, 14, UDim.new(1, -48), 26, 18)
		st.TextColor3 = UiKit.TEXT
		local ft = label(stats, "FASTEST DESCENTS", "status", 24, 44, UDim.new(1, -48), 18)
		ft.TextColor3 = UiKit.ACCENT
		if #top == 0 then
			local l = label(stats, "No records yet: be the first!", "body", 24, 66, UDim.new(1, -48), 24)
			l.TextColor3 = UiKit.MUTED
		end
		for i, e in top do
			if i > 5 then
				break
			end
			local l = label(stats, string.format("%d.   %s   —   %.1f s", i, e.name, e.seconds), "body", 24, 38 + 28 * i, UDim.new(1, -48), 24)
			l.TextColor3 = if e.name == player.Name or e.name == player.DisplayName then UiKit.ACCENT else UiKit.TEXT
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
