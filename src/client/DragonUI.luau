--!strict
-- Scheda "Draghi" del menu: il nido (uova in cova, "Schiudi" quando sono pronte) e la
-- collezione (anteprima 3D, Segui/Riposa, Evolvi con le pietre, Vendi).
-- Lo stato arriva dal server nell'attributo DragonData.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local EconomyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EconomyConfig"))
local Names = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Names"))
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local DragonUI = {}

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function readState(): any
	local raw = player:GetAttribute("DragonData")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok then data else nil
end

local function preview(kind: string, element: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild("Previews")
	local sub = folder and folder:FindFirstChild(kind)
	return sub and sub:FindFirstChild(element)
end

-- Monta la scheda dentro "container"; restituisce la funzione per ridisegnarla
function DragonUI.mount(container: Frame, status: (string, boolean) -> ()): () -> ()
	local header = Theme.label(container, "", 14, Theme.MUTED)
	header.Size = UDim2.new(1, 0, 0, 22)

	local body = Theme.frame(container, nil, 1)
	body.Position = UDim2.new(0, 0, 0, 28)
	body.Size = UDim2.new(1, 0, 1, -28)

	local nestCol = Theme.frame(body, nil, 1)
	nestCol.Size = UDim2.new(0.36, -6, 1, 0)
	local nestTitle = Theme.label(nestCol, "Hatching nest", 15, Theme.TEXT, true)
	nestTitle.Size = UDim2.new(1, 0, 0, 22)
	local nestList = Theme.scroll(nestCol)
	nestList.Position = UDim2.new(0, 0, 0, 26)
	nestList.Size = UDim2.new(1, 0, 1, -26)
	Theme.list(nestList, 6)

	local dragonCol = Theme.frame(body, nil, 1)
	dragonCol.Position = UDim2.new(0.36, 6, 0, 0)
	dragonCol.Size = UDim2.new(0.64, -6, 1, 0)
	local dragonTitle = Theme.label(dragonCol, "Your dragons", 15, Theme.TEXT, true)
	dragonTitle.Size = UDim2.new(1, 0, 0, 22)
	local dragonList = Theme.scroll(dragonCol)
	dragonList.Position = UDim2.new(0, 0, 0, 26)
	dragonList.Size = UDim2.new(1, 0, 1, -26)
	Theme.list(dragonList, 6)

	local confirmSell: number? = nil
	local render: () -> ()

	local function act(kind: string, arg: any)
		local ok, message = (remotes:WaitForChild("DragonAction") :: RemoteFunction):InvokeServer(kind, arg)
		status(message or "", ok)
	end

	render = function()
		for _, list in { nestList, dragonList } do
			for _, c in list:GetChildren() do
				if c:IsA("Frame") then
					c:Destroy()
				end
			end
		end
		local data = readState()
		if not data then
			return
		end
		header.Text = string.format(
			"Evolution stones: <b>%d</b>   ·   Following: <b>%d/%d</b>   ·   At home: <b>%d</b> (%d coins/min)",
			data.stones or 0,
			#data.equipped,
			data.maxEquipped or 1,
			data.roostSlots or 0,
			player:GetAttribute("RoostRate") or 0
		)
		local now = os.time()

		for index, egg in data.nest do
			local card = Theme.frame(nestList, Theme.CARD)
			card.Size = UDim2.new(1, -6, 0, 76)
			Theme.corner(card, 10)
			Theme.viewport(card, preview("Eggs", egg.element), UDim2.new(0, 64, 0, 64), false).Position = UDim2.new(0, 6, 0, 6)
			local e = DragonConfig.element(egg.element)
			local r = DragonConfig.rarity(egg.rarity)
			local t = Theme.label(card, string.format('%s Egg\n<font color="%s">%s</font>', Names.t(egg.element), hex(r.color), Names.t(egg.rarity)), 13, if e then e.glow else Theme.TEXT, true)
			t.Position = UDim2.new(0, 76, 0, 6)
			t.Size = UDim2.new(1, -82, 0, 34)
			local left = math.max(0, egg.readyAt - now)
			if left <= 0 then
				local b = Theme.button(card, "Hatch!", Theme.GOOD, UDim2.new(1, -84, 0, 28))
				b.Position = UDim2.new(0, 76, 0, 42)
				b.Activated:Connect(function()
					act("hatch", index)
				end)
			else
				local l = Theme.label(card, string.format("Ready in %d:%02d", left // 60, left % 60), 13, Theme.MUTED)
				l.Position = UDim2.new(0, 76, 0, 46)
				l.Size = UDim2.new(1, -82, 0, 20)
			end
		end
		if #data.nest == 0 then
			local card = Theme.frame(nestList, nil, 1)
			card.Size = UDim2.new(1, -6, 0, 80)
			Theme.label(card, if (data.nestSlots or 0) > 0
				then "No eggs. Find them in tunnels, rivers and on walls, and bring them to your home nest."
				else "Buy the Tent on your plot (the sign with your name) to unlock the nest.", 13, Theme.MUTED).Size =
				UDim2.fromScale(1, 1)
		end

		for _, d in data.dragons do
			local e = DragonConfig.element(d.element)
			local r = DragonConfig.rarity(d.rarity)
			local stage = DragonConfig.STAGES[d.stage] or DragonConfig.STAGES[1]
			local nextStage = DragonConfig.STAGES[d.stage + 1]
			local following = table.find(data.equipped, d.id) ~= nil
			local card = Theme.frame(dragonList, Theme.CARD)
			card.Size = UDim2.new(1, -6, 0, 112)
			Theme.corner(card, 10)
			if following then
				Theme.stroke(card, Theme.GOOD, 2, 0.2)
			end
			Theme.viewport(card, preview("Dragons", d.element), UDim2.new(0, 84, 0, 84), false).Position = UDim2.new(0, 6, 0, 6)
			local t = Theme.label(
				card,
				string.format('%s%s  <font color="%s">%s</font>  <font color="#A5AAB6">%s</font>', if d.shiny then '<font color="#FFD86E">✨ SHINY</font> ' else '', Names.dragon(d.element), hex(r.color), Names.t(d.rarity), Names.t(stage.name)),
				14,
				Theme.TEXT,
				true
			)
			t.Position = UDim2.new(0, 96, 0, 6)
			t.Size = UDim2.new(1, -100, 0, 20)
			local a = Theme.label(card, if e then e.ability else "", 12, Theme.MUTED)
			a.Position = UDim2.new(0, 96, 0, 26)
			a.Size = UDim2.new(1, -100, 0, 28)
			-- livello e barra dell'esperienza (si addestra nella zona delle costole)
			local level = d.level or 1
			local maxed = level >= DragonConfig.MAX_LEVEL
			local need = DragonConfig.xpForLevel(level)
			local bar = Theme.frame(card, Color3.fromRGB(22, 24, 30))
			bar.Position = UDim2.new(0, 96, 0, 56)
			bar.Size = UDim2.new(1, -110, 0, 14)
			Theme.corner(bar, 7)
			local fill = Theme.frame(bar, if maxed then Theme.ACCENT else (if e then e.glow else Theme.GOOD))
			fill.Size = UDim2.new(if maxed then 1 else math.clamp((d.xp or 0) / need, 0, 1), 0, 1, 0)
			Theme.corner(fill, 7)
			local lv = Theme.label(bar, if maxed then string.format("Lv %d  ·  MAX", level) else string.format("Lv %d   %d / %d XP", level, d.xp or 0, need), 11, Theme.TEXT, true)
			lv.Size = UDim2.fromScale(1, 1)
			lv.TextXAlignment = Enum.TextXAlignment.Center
			local row = Theme.frame(card, nil, 1)
			row.Position = UDim2.new(0, 96, 1, -38)
			row.Size = UDim2.new(1, -100, 0, 32)
			Theme.list(row, 6, true)
			local follow = Theme.button(row, if following then "Rest" else "Follow", if following then Theme.MUTED else Theme.GOOD, UDim2.new(0, 76, 0, 30))
			follow.Activated:Connect(function()
				act(if following then "unequip" else "equip", d.id)
			end)
			if nextStage then
				local ready = (d.level or 1) >= DragonConfig.MAX_LEVEL
				local evo = Theme.button(row, if ready then "Evolve!" else string.format("Evolve (Lv %d)", DragonConfig.MAX_LEVEL), if ready then Theme.ACCENT else Theme.MUTED, UDim2.new(0, 104, 0, 30))
				evo.Activated:Connect(function()
					act("evolve", d.id)
				end)
			end
			local price = (EconomyConfig.DRAGON_PRICES[d.rarity] or 20) * d.stage
			local sell = Theme.button(row, if confirmSell == d.id then "Sure?" else "Sell " .. price, Theme.BAD, UDim2.new(0, 84, 0, 30))
			sell.Activated:Connect(function()
				if confirmSell == d.id then
					confirmSell = nil
					act("sell", d.id)
				else
					confirmSell = d.id
					render()
				end
			end)
		end
	end
	return render
end

return DragonUI
