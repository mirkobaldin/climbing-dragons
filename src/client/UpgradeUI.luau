--!strict
-- Potenziamenti, taglie e rinascita usano carte modificabili nella finestra principale.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("UpgradeConfig"))
local Names = require(Shared:WaitForChild("Names"))
local Ui = require(Shared:WaitForChild("UiView"))
local Theme = require(script.Parent.Theme)
local player = Players.LocalPlayer
local UpgradeUI = {}
local ICONS = {
	Rampino = "⚓",
	Uncino = "⚡",
	Lancio = "🪓",
	Esoscheletro = "🦾",
	Scudo = "🛡",
	Stivali = "👢",
	Picchiata = "💥",
}
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
	return if type(shown) == "string" then shown else Names.t(name)
end
local function costText(coins: number, items: { [string]: number }): string
	local parts = {
		string.format(
			'<font color="%s">%d coins</font>',
			if ((player:GetAttribute("Coins") or 0) :: number) >= coins then "#6ECD78" else "#EB5F55",
			coins
		),
	}
	for name, n in items do
		local have = count(name)
		table.insert(
			parts,
			string.format(
				'<font color="%s">%s %d/%d</font>',
				if have >= n then "#6ECD78" else "#EB5F55",
				itemName(name),
				have,
				n
			)
		)
	end
	return table.concat(parts, " · ")
end
local function decode(raw: any): any
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then data else nil
end
function UpgradeUI.mount(container: Frame, status: (string, boolean) -> ()): () -> ()
	local list = Ui.node(container, "List")
	local page = "Upgrades"
	local refresh: () -> ()
	local function call(action: string, arg: any)
		local ok, message = (RS.Remotes:WaitForChild("Upgrade") :: RemoteFunction):InvokeServer(action, arg)
		status(message or "", ok)
		refresh()
	end
	local function heading(value: string, order: number)
		local l = Ui.template("Heading", list)
		l.Text, l.LayoutOrder = value, order
	end
	local function upgrades()
		for k, u in Config.UPGRADES do
			local c = Ui.template("UpgradeCard", list)
			c.LayoutOrder = k
			local level = Config.level(player, u.id)
			local maxed = level >= u.max
			c.Icon.Text = ICONS[u.id] or "★"
			local dots = ""
			for i = 1, u.max do
				dots ..= if i <= level then "●" else "○"
			end
			c.Title.Text = u.name .. " " .. dots
			c.Description.Text = u.description
			-- "ora" grigio, "dopo" verde: si vede subito cosa si guadagna
			c.Effect.Text = if maxed
				then '<font color="#FFD27A">MAX:</font> ' .. u.text(level)
				else '<font color="#AEB4C6">' .. u.text(level) .. '</font>  <font color="#FFD27A">→</font>  <font color="#7BE08A">' .. u.text(level + 1) .. "</font>"
			c.Cost.Text = if maxed then "MAX LEVEL" else costText(u.costs[level + 1].coins, u.costs[level + 1].items)
			c.Action.Visible = not maxed
			c.Action.Text = if level == 0 then "Unlock" else "Upgrade"
			Ui.tint(c, Color3.fromRGB(70, 110, 190), false, 0.02)
			local fill = c:FindFirstChild("Tinta") :: Frame?
			if fill then
				fill.BackgroundTransparency = 0.55
			end
			c.Action.Activated:Connect(function()
				if not maxed then
					call("buy", u.id)
				end
			end)
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
		local GOLD = Color3.fromRGB(255, 205, 90)
		local function glass(parent: Instance, h: number, order: number): Frame
			local f = Theme.frame(parent, Color3.fromRGB(10, 14, 26), 0.35)
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
			local c = Instance.new("UITextSizeConstraint")
			c.MaxTextSize = size
			c.MinTextSize = math.floor(size * 0.6)
			c.Parent = l
			return l
		end
		local hero = glass(list, 430, 1)
		hero.Name = "Rinascita"
		text(hero, "REBIRTH", 44, GOLD, 24, 16, UDim.new(0.6, 0), 48)
		text(hero, string.format("Level %d  →  %d", n, n + 1), 22, Color3.new(1, 1, 1), 24, 66, UDim.new(0.6, 0), 28)
		-- ora / dopo
		local function bonus(x: number, title: string, k: number, color: Color3)
			local box = Theme.frame(hero, Color3.fromRGB(20, 26, 44), 0.2)
			box.Position = UDim2.new(x, if x == 0 then 24 else 8, 0, 108)
			box.Size = UDim2.new(0.5, -32, 0, 110)
			Theme.corner(box, 12)
			Theme.stroke(box, color, 2, 0.4)
			local t = text(box, title, 16, Color3.fromRGB(190, 196, 214), 14, 8, UDim.new(1, -28), 20)
			t.TextXAlignment = Enum.TextXAlignment.Center
			text(box, string.format("+%d%% coins", math.floor(k * R.COIN_BONUS * 100 + 0.5)), 30, color, 14, 32, UDim.new(1, -28), 36, Enum.TextXAlignment.Center)
			text(box, string.format("+%d%% dragon XP", math.floor(k * R.XP_BONUS * 100 + 0.5)), 20, color, 14, 72, UDim.new(1, -28), 26, Enum.TextXAlignment.Center)
		end
		bonus(0, "NOW", n, Color3.fromRGB(200, 205, 220))
		bonus(0.5, "AFTER REBIRTH", n + 1, Color3.fromRGB(120, 230, 140))
		-- tieni / perdi
		text(hero, "✔  You keep: dragons, gear, your house", 18, Color3.fromRGB(120, 230, 140), 24, 232, UDim.new(1, -48), 24)
		text(hero, "✖  You lose: coins, ores, upgrades", 18, Color3.fromRGB(240, 110, 100), 24, 260, UDim.new(1, -48), 24)
		-- requisiti
		local function need(ok: boolean, str: string, y: number)
			text(hero, (if ok then "✔  " else "✖  ") .. str, 18, if ok then Color3.fromRGB(120, 230, 140) else Color3.fromRGB(255, 200, 90), 24, y, UDim.new(1, -48), 24)
		end
		need(summitOk, "Reach the summit", 300)
		need(coinsOk, string.format("Have %d coins  (you have %d)", R.MIN_COINS, math.floor(coins)), 328)
		-- pulsante
		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(0.5, 1)
		btn.Position = UDim2.new(0.5, 0, 1, -16)
		btn.Size = UDim2.new(0, 320, 0, 60)
		btn.Font = Enum.Font.GothamBlack
		btn.TextScaled = true
		btn.Text = if ready then "REBIRTH" else "NOT READY YET"
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.TextStrokeTransparency = 0.2
		btn.BackgroundColor3 = if ready then Color3.fromRGB(220, 70, 50) else Color3.fromRGB(70, 74, 90)
		btn.AutoButtonColor = ready
		btn.Parent = hero
		Theme.corner(btn, 14)
		Theme.gradient(btn, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 180), 90)
		Theme.stroke(btn, GOLD, 3, if ready then 0 else 0.6)
		local bc = Instance.new("UITextSizeConstraint")
		bc.MaxTextSize = 28
		bc.Parent = btn
		local bp = Instance.new("UIPadding")
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
			text(stats, "No records yet: be the first!", 16, Color3.fromRGB(200, 206, 222), 20, 62, UDim.new(1, -40), 22)
		end
		for i, e in top do
			if i > 5 then
				break
			end
			text(stats, string.format("%d.  %s  —  %.1f s", i, e.name, e.seconds), 16, Color3.fromRGB(220, 226, 240), 20, 32 + 30 * i, UDim.new(1, -40), 22)
		end
	end
	refresh = function()
		Ui.clear(list)
		for _, name in { "Upgrades", "Bounties", "Rebirth" } do
			Ui.selected(Ui.node(container, "Tabs/" .. name), name == page, Theme.ACCENT, Theme.CARD)
		end
		if page == "Upgrades" then
			upgrades()
		elseif page == "Bounties" then
			bounties()
		else
			rebirth()
		end
	end
	for _, name in { "Upgrades", "Bounties", "Rebirth" } do
		Ui.node(container, "Tabs/" .. name).Activated:Connect(function()
			page = name
			refresh()
		end)
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
