--!strict
-- Potenziamenti, taglie e rinascita usano carte modificabili nella finestra principale.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.UpgradeConfig)
local Names = require(Shared.Names)
local Ui = require(Shared.UiView)
local Theme = require(script.Parent.Theme)
local player = Players.LocalPlayer
local UpgradeUI = {}
local ICONS = {Rampino="⚓", Uncino="⚡", Lancio="🪓", Esoscheletro="🦾", Scudo="🛡", Stivali="👢", Picchiata="💥"}
local function count(name: string): number
	for _, folder in {"Ores", "Materiali"} do
		local f = player:FindFirstChild(folder)
		local v = f and f:FindFirstChild(name)
		if v and v:IsA("IntValue") then return v.Value end
	end
	return 0
end
local function itemName(name: string): string
	local icons = RS:FindFirstChild("DropIcone")
	local map = icons and icons:FindFirstChild("Nomi")
	local shown = map and map:GetAttribute(name)
	return if type(shown) == "string" then shown else Names.t(name)
end
local function costText(coins: number, items: {[string]: number}): string
	local parts = {string.format('<font color="%s">%d coins</font>', if ((player:GetAttribute("Coins") or 0) :: number) >= coins then "#6ECD78" else "#EB5F55", coins)}
	for name, n in items do
		local have = count(name)
		table.insert(parts, string.format('<font color="%s">%s %d/%d</font>', if have >= n then "#6ECD78" else "#EB5F55", itemName(name), have, n))
	end
	return table.concat(parts, " · ")
end
local function decode(raw: any): any
	if type(raw) ~= "string" then return nil end
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
			for i = 1, u.max do dots ..= if i <= level then "●" else "○" end
			c.Title.Text = u.name .. " " .. dots
			c.Description.Text = u.description
			c.Effect.Text = if maxed then "Now: " .. u.text(level) else "Now: " .. u.text(level) .. " → " .. u.text(level + 1)
			c.Cost.Text = if maxed then "MAX LEVEL" else costText(u.costs[level + 1].coins, u.costs[level + 1].items)
			c.Action.Visible = not maxed
			c.Action.Text = if level == 0 then "Unlock" else "Upgrade"
			c.Action.Activated:Connect(function() if not maxed then call("buy", u.id) end end)
		end
	end
	local function bounties()
		local data = decode(player:GetAttribute("BountyData"))
		if not data then heading("Loading bounties...", 0); return end
		local function row(order: number, title: string, progress: number, need: number, reward: string, claimed: boolean, action: string, arg: any)
			local c = Ui.template("BountyCard", list)
			c.LayoutOrder = order
			c.Title.Text = title
			c.Progress.Fill.Size = UDim2.fromScale(math.clamp(progress / math.max(need, 1), 0, 1), 1)
			c.Reward.Text = string.format("%d/%d · Reward: %s", progress, need, reward)
			c.Claim.Text = if claimed then "Claimed" elseif progress >= need then "Claim" else "In progress"
			c.Claim.Activated:Connect(function() if not claimed and progress >= need then call(action, arg) end end)
		end
		local d = data.daily
		if d then
			heading(string.format("Daily challenge · new one in %d h", math.floor((data.resetIn or 0) / 3600)), 0)
			row(1, d.text, d.progress, d.need, string.format("%d coins", d.coins), d.claimed, "daily", nil)
		end
		heading("Bounties · claim one to receive a new one", 2)
		for k, b in data.bounties or {} do
			local reward = string.format("%d coins", b.coins)
			for name, n in b.items or {} do reward ..= string.format(" + %d %s", n, itemName(name)) end
			row(k + 2, b.text, b.progress, b.need, reward, false, "claim", k)
		end
	end
	local function rebirth()
		local R = Config.REBIRTH
		local n = (player:GetAttribute("Rebirths") or 0) :: number
		local since = (player:GetAttribute("SummitsSinceRebirth") or 0) :: number
		local c = Ui.template("RebirthCard", list)
		c.LayoutOrder = 1
		c.Title.Text = "Rebirth " .. n
		c.Description.Text = string.format("Start again from base camp. You lose coins, ores and upgrades; you keep dragons, gear and your house.\nNow: +%d%% coins, +%d%% dragon XP.\nNext: +%d%% coins, +%d%% dragon XP.", math.floor(n*R.COIN_BONUS*100+.5), math.floor(n*R.XP_BONUS*100+.5), math.floor((n+1)*R.COIN_BONUS*100+.5), math.floor((n+1)*R.XP_BONUS*100+.5))
		c.Cost.Text = (if since >= 1 then "Summit reached" else "Reach the summit first") .. " · " .. costText(R.MIN_COINS, {})
		local armed = false
		c.Action.Activated:Connect(function()
			if not armed then
				armed = true
				c.Action.Text = "Sure?"
				task.delay(3, function() if c.Parent then armed = false; c.Action.Text = "Rebirth" end end)
				return
			end
			call("rebirth", nil)
		end)
		local best = player:GetAttribute("BestDescent")
		local stats = Ui.template("TextCard", list)
		stats.LayoutOrder = 2
		stats.Text.Text = string.format("Summits: %d · Enemies: %d · Bosses: %d\nBest descent: %s", player:GetAttribute("Summits") or 0, player:GetAttribute("Kills") or 0, player:GetAttribute("BossKills") or 0, if type(best) == "number" then string.format("%.1f s", best) else "none yet")
		heading("Fastest descents (all players)", 3)
		local top = decode(workspace:GetAttribute("DescentTop")) or {}
		if #top == 0 then heading("No records yet: be the first!", 4) end
		for i, e in top do heading(string.format("%d. %s — %.1f s", i, e.name, e.seconds), i+3) end
	end
	refresh = function()
		Ui.clear(list)
		for _, name in {"Upgrades", "Bounties", "Rebirth"} do Ui.node(container, "Tabs/" .. name).BackgroundColor3 = if name == page then Theme.ACCENT else Theme.CARD end
		if page == "Upgrades" then upgrades() elseif page == "Bounties" then bounties() else rebirth() end
	end
	for _, name in {"Upgrades", "Bounties", "Rebirth"} do Ui.node(container, "Tabs/" .. name).Activated:Connect(function() page = name; refresh() end) end
	local function onChange() if container.Parent and container.Visible then refresh() end end
	for _, attr in {"BountyData", "Rebirths", "Summits", "SummitsSinceRebirth", "Kills", "BossKills", "BestDescent"} do player:GetAttributeChangedSignal(attr):Connect(onChange) end
	for _, u in Config.UPGRADES do player:GetAttributeChangedSignal("Up_" .. u.id):Connect(onChange) end
	workspace:GetAttributeChangedSignal("DescentTop"):Connect(onChange)
	return refresh
end
return UpgradeUI

