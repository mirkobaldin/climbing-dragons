--!strict
-- Scheda "Upgrades" del menu (tasto U): tre sezioni
--   Upgrades  i potenziamenti dello scalatore con livello, effetto e costo (verde = ce l'hai)
--   Bounties  le tre taglie e la sfida del giorno, con "Claim" quando sono finite
--   Rebirth   rinascita (dopo la vetta), vette, record della discesa e classifica di tutti
-- Il server controlla tutto (remote "Upgrade", server/Upgrades).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local Names = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Names"))
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UpgradeUI = {}

-- icona (emoji) per ogni potenziamento: leggibile anche piccola
local ICONS = {
	Rampino = "⚓",
	Uncino = "⚡",
	Lancio = "🪓",
	Esoscheletro = "🦾",
	Scudo = "🛡️",
	Stivali = "👢",
	Picchiata = "💥",
}

local function count(name: string): number
	for _, folderName in { "Ores", "Materiali" } do
		local f = player:FindFirstChild(folderName)
		local v = f and f:FindFirstChild(name)
		if v and v:IsA("IntValue") then
			return v.Value
		end
	end
	return 0
end

local function itemName(name: string): string
	local icons = ReplicatedStorage:FindFirstChild("DropIcone")
	local nameMap = icons and icons:FindFirstChild("Nomi")
	local shown = nameMap and nameMap:GetAttribute(name)
	return if type(shown) == "string" then shown else Names.t(name)
end

local function clear(frame: Instance)
	for _, c in frame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function call(action: string, arg: any, status: (string, boolean) -> ())
	local ok, message = (remotes:WaitForChild("Upgrade") :: RemoteFunction):InvokeServer(action, arg)
	status(message, ok)
end

local function costText(coins: number, items: { [string]: number }): string
	local parts = {}
	local have = (player:GetAttribute("Coins") or 0) :: number
	table.insert(parts, string.format('<font color="%s">%d coins</font>', if have >= coins then "#6ECD78" else "#EB5F55", coins))
	for name, n in items do
		local c = count(name)
		table.insert(parts, string.format('<font color="%s">%s %d/%d</font>', if c >= n then "#6ECD78" else "#EB5F55", itemName(name), c, n))
	end
	return table.concat(parts, "  ·  ")
end

local function card(parent: Instance, height: number, order: number): Frame
	local c = Theme.frame(parent, Theme.CARD)
	c.Size = UDim2.new(1, -8, 0, height)
	c.LayoutOrder = order
	Theme.corner(c, 10)
	return c
end

------------------------------------------------------------------------------------------

local function upgradesPage(list: ScrollingFrame, status: (string, boolean) -> ())
	for k, u in UpgradeConfig.UPGRADES do
		local level = UpgradeConfig.level(player, u.id)
		local maxed = level >= u.max
		local c = card(list, 96, k)
		if maxed then
			Theme.stroke(c, Theme.ACCENT, 1.5, 0.3)
		end
		local icon = Theme.label(c, ICONS[u.id] or "⭐", 34, Theme.TEXT, true)
		icon.Position = UDim2.new(0, 10, 0, 0)
		icon.Size = UDim2.new(0, 50, 1, 0)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		-- livello a pallini
		local dots = ""
		for i = 1, u.max do
			dots ..= if i <= level then "●" else "○"
		end
		local title = Theme.label(c, string.format('%s  <font color="#FFC450" size="13">%s</font>', u.name, dots), 16, Theme.TEXT, true)
		title.Position = UDim2.new(0, 66, 0, 6)
		title.Size = UDim2.new(1, -200, 0, 20)
		local desc = Theme.label(c, u.description, 12, Theme.MUTED)
		desc.Position = UDim2.new(0, 66, 0, 27)
		desc.Size = UDim2.new(1, -200, 0, 16)
		local now = Theme.label(c, if maxed then "Now: " .. u.text(level) else string.format("Now: %s  →  <b>%s</b>", u.text(level), u.text(level + 1)), 12, Color3.fromRGB(160, 210, 255), true)
		now.Position = UDim2.new(0, 66, 0, 45)
		now.Size = UDim2.new(1, -200, 0, 16)
		local cost = Theme.label(c, if maxed then "MAX LEVEL" else costText(u.costs[level + 1].coins, u.costs[level + 1].items), 12, Theme.TEXT, true)
		cost.Position = UDim2.new(0, 66, 0, 66)
		cost.Size = UDim2.new(1, -200, 0, 24)
		if not maxed then
			local b = Theme.button(c, if level == 0 then "Unlock" else "Upgrade", Theme.GOOD, UDim2.new(0, 116, 0, 42))
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, -10, 0.5, 0)
			b.Activated:Connect(function()
				call("buy", u.id, status)
			end)
		end
	end
end

local function bountiesPage(list: ScrollingFrame, status: (string, boolean) -> ())
	local raw = player:GetAttribute("BountyData")
	local data: any = nil
	if type(raw) == "string" then
		local ok, d = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		data = if ok then d else nil
	end
	if not data then
		Theme.label(list, "Loading bounties...", 14, Theme.MUTED)
		return
	end
	local function row(order: number, text: string, progressN: number, need: number, reward: string, claimed: boolean, onClaim: () -> (), gold: boolean)
		local c = card(list, 78, order)
		if gold then
			Theme.stroke(c, Theme.ACCENT, 2, 0.2)
		end
		local t = Theme.label(c, text, 15, Theme.TEXT, true)
		t.Position = UDim2.new(0, 12, 0, 6)
		t.Size = UDim2.new(1, -150, 0, 20)
		local back = Theme.frame(c, Theme.BG)
		back.Position = UDim2.new(0, 12, 0, 32)
		back.Size = UDim2.new(1, -150, 0, 12)
		Theme.corner(back, 6)
		local fill = Theme.frame(back, if progressN >= need then Theme.GOOD else Theme.BLUE)
		fill.Size = UDim2.fromScale(math.clamp(progressN / math.max(need, 1), 0, 1), 1)
		Theme.corner(fill, 6)
		local r = Theme.label(c, string.format("%d / %d   ·   Reward: %s", progressN, need, reward), 12, Theme.MUTED, true)
		r.Position = UDim2.new(0, 12, 0, 50)
		r.Size = UDim2.new(1, -150, 0, 18)
		local b = Theme.button(c, if claimed then "Claimed" elseif progressN >= need then "Claim" else "In progress", if progressN >= need and not claimed then Theme.ACCENT else Theme.CARD, UDim2.new(0, 120, 0, 40))
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -10, 0.5, 0)
		b.TextColor3 = if progressN >= need and not claimed then Theme.BG else Theme.MUTED
		Theme.stroke(b, Theme.MUTED, 1, 0.6)
		if progressN >= need and not claimed then
			b.Activated:Connect(onClaim)
		end
	end
	local daily = data.daily
	if daily then
		local hours = math.floor((data.resetIn or 0) / 3600)
		local head = Theme.label(list, string.format("Daily challenge  ·  new one in %d h", hours), 15, Theme.ACCENT, true)
		head.LayoutOrder = 0
		row(1, daily.text, daily.progress, daily.need, string.format("%d coins", daily.coins), daily.claimed, function()
			call("daily", nil, status)
		end, true)
	end
	local head2 = Theme.label(list, "Bounties (a new one arrives when you claim one)", 15, Theme.TEXT, true)
	head2.LayoutOrder = 2
	for k, b in data.bounties or {} do
		local reward = string.format("%d coins", b.coins)
		for name, n in b.items or {} do
			reward ..= string.format(" + %d %s", n, itemName(name))
		end
		row(2 + k, b.text, b.progress, b.need, reward, false, function()
			call("claim", k, status)
		end, false)
	end
end

local function rebirthPage(list: ScrollingFrame, status: (string, boolean) -> ())
	local R = UpgradeConfig.REBIRTH
	local rebirths = (player:GetAttribute("Rebirths") or 0) :: number
	local since = (player:GetAttribute("SummitsSinceRebirth") or 0) :: number
	local c = card(list, 150, 1)
	Theme.stroke(c, Color3.fromRGB(200, 140, 255), 2, 0.3)
	local t = Theme.label(c, string.format('Rebirth  <font color="#C88CFF">%d</font>', rebirths), 20, Theme.TEXT, true)
	t.Position = UDim2.new(0, 12, 0, 8)
	t.Size = UDim2.new(1, -24, 0, 24)
	local d = Theme.label(
		c,
		string.format(
			"Start over from the base camp, stronger. You lose coins, ores and upgrades; you keep dragons, gear and your house.\nBonus now: <b>+%d%% coins, +%d%% dragon XP</b>   →   next: <b>+%d%%</b>",
			math.floor(rebirths * R.COIN_BONUS * 100 + 0.5),
			math.floor(rebirths * R.XP_BONUS * 100 + 0.5),
			math.floor((rebirths + 1) * R.COIN_BONUS * 100 + 0.5)
		),
		13,
		Theme.MUTED,
		true
	)
	d.Position = UDim2.new(0, 12, 0, 36)
	d.Size = UDim2.new(1, -150, 0, 60)
	local need = Theme.label(
		c,
		string.format(
			'<font color="%s">Reach the summit (%s)</font>   ·   <font color="%s">%d coins</font>',
			if since >= 1 then "#6ECD78" else "#EB5F55",
			if since >= 1 then "done" else "not yet",
			if ((player:GetAttribute("Coins") or 0) :: number) >= R.MIN_COINS then "#6ECD78" else "#EB5F55",
			R.MIN_COINS
		),
		13,
		Theme.TEXT,
		true
	)
	need.Position = UDim2.new(0, 12, 0, 104)
	need.Size = UDim2.new(1, -150, 0, 36)
	local b = Theme.button(c, "Rebirth", Color3.fromRGB(200, 140, 255), UDim2.new(0, 120, 0, 44))
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -10, 0.5, 0)
	local armed = false
	b.Activated:Connect(function()
		-- doppio click: si perdono monete e potenziamenti
		if not armed then
			armed = true
			b.Text = "Sure?"
			task.delay(3, function()
				armed = false
				b.Text = "Rebirth"
			end)
			return
		end
		call("rebirth", nil, status)
	end)

	local best = player:GetAttribute("BestDescent")
	local s = card(list, 74, 2)
	local st = Theme.label(
		s,
		string.format(
			"Summits reached: <b>%d</b>   ·   Enemies defeated: <b>%d</b>   ·   Bosses: <b>%d</b>\nBest descent from the summit: <b>%s</b>  (glide down to the base camp)",
			(player:GetAttribute("Summits") or 0) :: number,
			(player:GetAttribute("Kills") or 0) :: number,
			(player:GetAttribute("BossKills") or 0) :: number,
			if type(best) == "number" then string.format("%.1f s", best) else "none yet"
		),
		13,
		Theme.TEXT,
		true
	)
	st.Position = UDim2.new(0, 12, 0, 8)
	st.Size = UDim2.new(1, -24, 1, -16)

	local head = Theme.label(list, "Fastest descents (all players)", 15, Theme.ACCENT, true)
	head.LayoutOrder = 3
	local raw = workspace:GetAttribute("DescentTop")
	local top = {}
	if type(raw) == "string" then
		local ok, d2 = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		top = if ok then d2 else {}
	end
	if #top == 0 then
		local none = Theme.label(list, "No records yet: be the first!", 13, Theme.MUTED)
		none.LayoutOrder = 4
	end
	for i, e in top do
		local l = Theme.label(list, string.format("%d.  %s  —  %.1f s", i, e.name, e.seconds), 14, if i == 1 then Theme.COIN else Theme.TEXT, i <= 3)
		l.LayoutOrder = 3 + i
	end
end

------------------------------------------------------------------------------------------

function UpgradeUI.mount(container: Frame, status: (string, boolean) -> ()): () -> ()
	local page = "Upgrades"
	local tabsRow = Theme.frame(container, nil, 1)
	tabsRow.Size = UDim2.new(1, 0, 0, 38)
	Theme.list(tabsRow, 6, true)
	local body = Theme.frame(container, nil, 1)
	body.Position = UDim2.new(0, 0, 0, 44)
	body.Size = UDim2.new(1, 0, 1, -44)
	local list = Theme.scroll(body)
	Theme.list(list, 8)
	local buttons: { [string]: TextButton } = {}
	local function refresh()
		for name, b in buttons do
			b.BackgroundColor3 = if name == page then Theme.ACCENT else Theme.CARD
			b.TextColor3 = if name == page then Theme.BG else Theme.TEXT
		end
		clear(list)
		if page == "Upgrades" then
			upgradesPage(list, status)
		elseif page == "Bounties" then
			bountiesPage(list, status)
		else
			rebirthPage(list, status)
		end
	end
	for _, name in { "Upgrades", "Bounties", "Rebirth" } do
		local b = Theme.button(tabsRow, name, Theme.CARD, UDim2.new(0, 120, 0, 34))
		buttons[name] = b
		b.Activated:Connect(function()
			page = name
			refresh()
		end)
	end
	-- si ridisegna da sola quando cambiano livelli, taglie, rinascite
	local function onChange()
		if container.Parent and container.Visible then
			refresh()
		end
	end
	for _, attr in { "BountyData", "Rebirths", "Shield" } do
		player:GetAttributeChangedSignal(attr):Connect(onChange)
	end
	for _, u in UpgradeConfig.UPGRADES do
		player:GetAttributeChangedSignal("Up_" .. u.id):Connect(onChange)
	end
	return refresh
end

return UpgradeUI
