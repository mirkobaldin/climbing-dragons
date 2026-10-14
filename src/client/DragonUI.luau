--!strict
-- Carte del nido e della collezione, con logica server invariata.
-- I draghi: una griglia di tessere (anteprima 3D, voto, grado, stadio, livello); al click si apre
-- la scheda stile FIFA (Mirko: "tipo scheda fifa") con il voto complessivo, le statistiche, l'abilita',
-- cosa serve per evolverlo (livello e pietre dell'evoluzione) e i pulsanti Follow / Evolve / Sell.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local DragonConfig = require(Shared:WaitForChild("DragonConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Names = require(Shared:WaitForChild("Names"))
local Ui = require(Shared:WaitForChild("UiView"))
local Theme = require(script.Parent.Theme)
local player = Players.LocalPlayer
local DragonUI = {}
-- uova nel nido: il conto alla rovescia si aggiorna da solo ogni secondo (DragonUI.tick), senza
-- ricostruire la lista (prima la lista si rifaceva ogni secondo e tornava in cima)
type Timer = { label: TextLabel, hatch: GuiObject, readyAt: number }
local timers: { Timer } = {}
local RARITY = {
	Comune = "common",
	NonComune = "common",
	Raro = "rare",
	Epico = "epic",
	Leggendario = "legendary",
	Mitico = "legendary",
}
-- voto complessivo (40-99, come le carte FIFA): dall'attacco, rispetto al drago piu' forte possibile
-- (leggendario adulto a livello 100 con l'attacco al massimo)
local MAX_ATTACK = DragonConfig.attack({ stage = #DragonConfig.STAGES, level = DragonConfig.MAX_LEVEL, atk = 1.5 })
local function overall(d: any): number
	return math.clamp(math.floor(40 + 59 * math.sqrt(DragonConfig.attack(d) / MAX_ATTACK) + 0.5), 40, 99)
end
local GRADE_COLORS = { S = Color3.fromRGB(255, 215, 94), A = Color3.fromRGB(127, 224, 138), B = Color3.fromRGB(143, 200, 255), C = Color3.fromRGB(201, 201, 201) }
-- sfondo della carta per rarita' (bronzo, argento, oro, viola leggendario come le carte speciali)
local CARD_COLORS = {
	Comune = { Color3.fromRGB(150, 110, 78), Color3.fromRGB(70, 48, 34) },
	Raro = { Color3.fromRGB(180, 190, 205), Color3.fromRGB(70, 80, 96) },
	Epico = { Color3.fromRGB(240, 200, 90), Color3.fromRGB(120, 80, 20) },
	Leggendario = { Color3.fromRGB(190, 110, 255), Color3.fromRGB(40, 16, 80) },
}

local function preview(kind: string, element: string): Instance?
	local f = RS:FindFirstChild("Previews")
	local sub = f and f:FindFirstChild(kind)
	return sub and sub:FindFirstChild(element)
end
function DragonUI.mount(container: Frame, status: (string, boolean) -> ()): () -> ()
	local header = Ui.node(container, "Header")
	local nestList = Ui.node(container, "Body/Nest/List")
	local dragonList = Ui.node(container, "Body/Dragons/List")
	local confirmSell: number? = nil
	local render: () -> ()
	local function act(kind: string, arg: any)
		local ok, message = (RS.Remotes:WaitForChild("DragonAction") :: RemoteFunction):InvokeServer(kind, arg)
		status(message or "", ok)
	end
	local selected: number? = nil -- id del drago con la scheda aperta
	local overlay: Frame? = nil
	local renderDragons: (any) -> ()

	-- testo con dimensione fissa che si rimpicciolisce solo se non ci sta (prima i testi lunghi
	-- uscivano dalle carte o erano minuscoli)
	local function text(parent: Instance, str: string, size: number, color: Color3?, bold: boolean?, align: Enum.TextXAlignment?): TextLabel
		local l = Theme.label(parent, str, size, color, bold)
		l.TextScaled = true
		l.TextXAlignment = align or Enum.TextXAlignment.Left
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = size
		c.MinTextSize = math.max(10, math.floor(size * 0.6))
		c.Parent = l
		return l
	end
	local function bar(parent: Instance, k: number, color: Color3): Frame
		local back = Theme.frame(parent, Color3.fromRGB(20, 22, 30), 0.1)
		Theme.corner(back, 6)
		local fill = Theme.frame(back, color, 0)
		fill.Size = UDim2.fromScale(math.clamp(k, 0, 1), 1)
		Theme.corner(fill, 6)
		return back
	end

	-- scheda stile FIFA del drago d (a sinistra la carta, a destra evoluzione e comandi)
	local function openCard(data: any, d: any)
		if overlay then
			overlay:Destroy()
		end
		selected = d.id
		local e = DragonConfig.element(d.element)
		local stage = DragonConfig.STAGES[d.stage] or DragonConfig.STAGES[1]
		local nextStage = DragonConfig.STAGES[d.stage + 1]
		local following = table.find(data.equipped, d.id) ~= nil
		local grade, quality = DragonConfig.grade(d)
		local level = d.level or 1
		local maxed = level >= DragonConfig.MAX_LEVEL
		local colors = CARD_COLORS[d.rarity] or CARD_COLORS.Comune

		local o = Theme.frame(container, Color3.fromRGB(10, 12, 18), 0)
		o.Name = "SchedaDrago"
		o.Size = UDim2.fromScale(1, 1)
		o.ZIndex = 50
		o.Active = true
		Theme.corner(o, 12)
		overlay = o

		-- la carta
		local card = Theme.frame(o, colors[1], 0)
		card.Name = "Carta"
		card.AnchorPoint = Vector2.new(0, 0.5)
		card.Position = UDim2.new(0, 12, 0.5, 0)
		card.Size = UDim2.new(0.42, -12, 1, -24)
		Theme.corner(card, 18)
		Theme.gradient(card, colors[1], colors[2], 90)
		Theme.stroke(card, Color3.new(1, 1, 1), 3, 0.4)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 0.7
		ratio.DominantAxis = Enum.DominantAxis.Height
		ratio.Parent = card
		local ovr = text(card, tostring(overall(d)), 44, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
		ovr.Font = Enum.Font.GothamBlack
		ovr.Position = UDim2.new(0.05, 0, 0.03, 0)
		ovr.Size = UDim2.new(0.28, 0, 0.12, 0)
		local gradeL = text(card, grade, 30, GRADE_COLORS[grade], true, Enum.TextXAlignment.Center)
		gradeL.Font = Enum.Font.GothamBlack
		gradeL.Position = UDim2.new(0.05, 0, 0.15, 0)
		gradeL.Size = UDim2.new(0.28, 0, 0.08, 0)
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Position = UDim2.new(0.11, 0, 0.24, 0)
		icon.Size = UDim2.new(0.16, 0, 0.11, 0)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = card
		Ui.asset(icon, "elem_" .. d.element)
		local vp = Theme.viewport(card, preview("Dragons", d.element), UDim2.new(0.72, 0, 0.46, 0), true)
		vp.Position = UDim2.new(0.27, 0, 0.04, 0)
		local name = text(card, (if d.shiny then "SHINY " else "") .. string.upper(Names.dragon(d.element)), 22, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
		name.Font = Enum.Font.GothamBlack
		name.Position = UDim2.new(0.05, 0, 0.5, 0)
		name.Size = UDim2.new(0.9, 0, 0.07, 0)
		local sub = text(card, Names.t(d.rarity) .. " · " .. Names.t(stage.name), 16, Color3.fromRGB(255, 240, 210), true, Enum.TextXAlignment.Center)
		sub.Position = UDim2.new(0.05, 0, 0.57, 0)
		sub.Size = UDim2.new(0.9, 0, 0.05, 0)
		local line = Theme.frame(card, Color3.new(1, 1, 1), 0.6)
		line.Position = UDim2.new(0.1, 0, 0.635, 0)
		line.Size = UDim2.new(0.8, 0, 0, 2)
		-- sei statistiche in due colonne, numero grande e sigla (come le carte)
		local roost = (EconomyConfig.ROOST_RATE[d.rarity] or 1) * d.stage
		local stats = {
			{ math.floor(DragonConfig.attack(d) + 0.5), "ATK" },
			{ math.floor((d.crit or 0.05) * 100 + 0.5), "CRT" },
			{ level, "LVL" },
			{ math.floor(DragonConfig.STAGE_POWER[math.clamp(d.stage or 1, 1, #DragonConfig.STAGE_POWER)] / DragonConfig.STAGE_POWER[#DragonConfig.STAGE_POWER] * 99 + 0.5), "PWR" },
			{ math.floor(quality * 100 + 0.5), "QLT" },
			{ roost, "C/M" },
		}
		for i, st in stats do
			local col = (i - 1) // 3
			local row = (i - 1) % 3
			local cell = text(card, string.format("<b>%d</b> <font transparency=\"0.25\">%s</font>", st[1], st[2]), 22, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
			cell.Position = UDim2.new(0.06 + col * 0.46, 0, 0.66 + row * 0.1, 0)
			cell.Size = UDim2.new(0.42, 0, 0.085, 0)
		end

		-- il pannello a destra
		local side = Instance.new("Frame")
		side.Name = "Dettagli"
		side.BackgroundTransparency = 1
		side.AnchorPoint = Vector2.new(1, 0)
		side.Position = UDim2.new(1, -14, 0, 12)
		side.Size = UDim2.new(0.56, -20, 1, -24)
		side.Parent = o
		local close = Theme.button(side, "Back", Theme.CARD, UDim2.new(0, 96, 0, 40))
		close.TextColor3 = Theme.TEXT
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = UDim2.new(1, 0, 0, 0)
		close.Activated:Connect(function()
			selected = nil
			o:Destroy()
			overlay = nil
		end)
		local title = text(side, Names.dragon(d.element), 26, Theme.ACCENT, true)
		title.Font = Enum.Font.GothamBlack
		title.Size = UDim2.new(1, -110, 0, 34)
		local ability = text(side, "<b>Ability:</b> " .. (if e then e.ability else "-"), 17, Theme.TEXT)
		ability.Position = UDim2.new(0, 0, 0, 44)
		ability.Size = UDim2.new(1, 0, 0, 44)
		ability.TextYAlignment = Enum.TextYAlignment.Top
		-- evoluzione: livello e pietre
		local evoTitle = text(side, if nextStage then "Evolve to " .. Names.t(nextStage.name) else "Fully evolved", 20, Color3.new(1, 1, 1), true)
		evoTitle.Position = UDim2.new(0, 0, 0, 96)
		evoTitle.Size = UDim2.new(1, 0, 0, 26)
		local need = DragonConfig.xpForLevel(level)
		local lvText = text(side, if maxed then string.format("Level %d / %d  ✓", level, DragonConfig.MAX_LEVEL) else string.format("Level %d / %d  ·  %d/%d XP", level, DragonConfig.MAX_LEVEL, d.xp or 0, need), 16, Theme.MUTED)
		lvText.Position = UDim2.new(0, 0, 0, 126)
		lvText.Size = UDim2.new(1, 0, 0, 20)
		local lvBar = bar(side, level / DragonConfig.MAX_LEVEL, Theme.BLUE)
		lvBar.Position = UDim2.new(0, 0, 0, 150)
		lvBar.Size = UDim2.new(1, 0, 0, 12)
		local stonesNeed = if nextStage then nextStage.stones else 0
		local stonesHave = data.stones or 0
		local stText = text(side, string.format("Evolution stones %d / %d%s", math.min(stonesHave, stonesNeed), stonesNeed, if stonesHave >= stonesNeed then "  ✓" else ""), 16, Theme.MUTED)
		stText.Position = UDim2.new(0, 0, 0, 170)
		stText.Size = UDim2.new(1, 0, 0, 20)
		local stBar = bar(side, if stonesNeed > 0 then stonesHave / stonesNeed else 1, Color3.fromRGB(200, 120, 255))
		stBar.Position = UDim2.new(0, 0, 0, 194)
		stBar.Size = UDim2.new(1, 0, 0, 12)
		stText.Visible = nextStage ~= nil
		stBar.Visible = nextStage ~= nil
		local how = text(side, if not nextStage then "This dragon has reached its final form." elseif not maxed then "Train it in the Dragon Arena (inside the giant ribs) to level it up." elseif stonesHave < stonesNeed then "Win Dragon Duels in the arena or defeat the Summit Guardian to get stones." else "Ready to evolve!", 15, if nextStage and maxed and stonesHave >= stonesNeed then Theme.GOOD else Theme.MUTED)
		how.Position = UDim2.new(0, 0, 0, 214)
		how.Size = UDim2.new(1, 0, 0, 40)
		how.TextYAlignment = Enum.TextYAlignment.Top
		-- comandi in fondo
		local follow = Theme.button(side, if following then "Rest" else "Follow", if following then Theme.CARD else Theme.ACCENT)
		if following then
			follow.TextColor3 = Theme.TEXT
		end
		follow.Activated:Connect(function()
			act(if following then "unequip" else "equip", d.id)
		end)
		local evolve = Theme.button(side, "Evolve", if nextStage and maxed and stonesHave >= stonesNeed then Theme.GOOD else Theme.CARD)
		evolve.Visible = nextStage ~= nil
		evolve.Activated:Connect(function()
			act("evolve", d.id)
		end)
		local price = (EconomyConfig.DRAGON_PRICES[d.rarity] or 20) * d.stage
		local sell = Theme.button(side, "Sell " .. price, Theme.BAD)
		sell.TextColor3 = Color3.new(1, 1, 1)
		sell.Activated:Connect(function()
			if confirmSell == d.id then
				confirmSell = nil
				selected = nil
				act("sell", d.id)
			else
				confirmSell = d.id
				sell.Text = "Sure? Sell " .. price
			end
		end)
		-- adulto: al posto di Evolve si monta questo drago (diventa il primo al seguito, server/Riding)
		local ride = Theme.button(side, "Ride", Theme.BLUE)
		ride.TextColor3 = Color3.new(1, 1, 1)
		ride.Visible = nextStage == nil
		ride.Activated:Connect(function()
			local remote = RS.Remotes:FindFirstChild("DragonRide") :: RemoteEvent?
			if remote then
				remote:FireServer(d.id)
				local gui = container:FindFirstAncestorWhichIsA("ScreenGui")
				if gui then
					gui:SetAttribute("MenuOpen", false)
				end
			end
		end)
		local middle = if nextStage then evolve else ride
		if nextStage then
			ride:Destroy()
		end
		for _, btn in { follow, middle, sell } do
			btn.AnchorPoint = Vector2.new(0, 1)
			btn.TextSize = 17
		end
		Ui.row({ follow, middle, sell }, 0, 0, 46)
		for _, btn in { follow, middle, sell } do
			btn.Position = UDim2.new(btn.Position.X.Scale, btn.Position.X.Offset, 1, 0)
		end
	end

	-- griglia dei draghi: tessere piccole, il clic apre la scheda
	renderDragons = function(data: any)
		local layout = dragonList:FindFirstChildWhichIsA("UIGridLayout")
		if not layout then
			for _, l in dragonList:GetChildren() do
				if l:IsA("UIListLayout") then
					l:Destroy()
				end
			end
			local g = Instance.new("UIGridLayout")
			g.SortOrder = Enum.SortOrder.LayoutOrder
			g.CellPadding = UDim2.fromOffset(10, 10)
			g.Parent = dragonList
			layout = g
		end
		local width = math.max(dragonList.AbsoluteSize.X - 12, 200)
		local cols = math.clamp(math.floor(width / 150), 2, 5)
		local cell = (width - (cols - 1) * 10) / cols
		;(layout :: UIGridLayout).CellSize = UDim2.fromOffset(cell, cell * 1.3)
		if dragonList:IsA("ScrollingFrame") then
			dragonList.AutomaticCanvasSize = Enum.AutomaticSize.Y
			dragonList.CanvasSize = UDim2.new()
		end
		for index, d in data.dragons do
			local stage = DragonConfig.STAGES[d.stage] or DragonConfig.STAGES[1]
			local following = table.find(data.equipped, d.id) ~= nil
			local colors = CARD_COLORS[d.rarity] or CARD_COLORS.Comune
			local tile = Instance.new("TextButton")
			tile.Name = "Drago" .. d.id
			tile.Text = ""
			tile.AutoButtonColor = true
			tile.LayoutOrder = (if following then 0 else 1000) + index
			tile.BackgroundColor3 = colors[1]
			tile.Parent = dragonList
			Theme.corner(tile, 14)
			Theme.gradient(tile, colors[1], colors[2], 90)
			Theme.stroke(tile, if following then Theme.GOOD else Color3.new(1, 1, 1), if following then 3 else 1.5, if following then 0 else 0.6)
			local vp = Theme.viewport(tile, preview("Dragons", d.element), UDim2.new(1, -8, 0.6, 0), false)
			vp.Position = UDim2.new(0, 4, 0.06, 0)
			local grade = DragonConfig.grade(d)
			local ovr = text(tile, tostring(overall(d)), 26, Color3.new(1, 1, 1), true)
			ovr.Font = Enum.Font.GothamBlack
			ovr.Position = UDim2.new(0, 8, 0, 4)
			ovr.Size = UDim2.new(0.4, 0, 0.13, 0)
			local g = text(tile, grade, 20, GRADE_COLORS[grade], true, Enum.TextXAlignment.Right)
			g.Font = Enum.Font.GothamBlack
			g.AnchorPoint = Vector2.new(1, 0)
			g.Position = UDim2.new(1, -8, 0, 4)
			g.Size = UDim2.new(0.3, 0, 0.11, 0)
			local nm = text(tile, (if d.shiny then "✦ " else "") .. Names.dragon(d.element), 16, Color3.new(1, 1, 1), true, Enum.TextXAlignment.Center)
			nm.Position = UDim2.new(0, 4, 0.66, 0)
			nm.Size = UDim2.new(1, -8, 0.12, 0)
			local info = text(tile, string.format("%s · Lv %d", Names.t(stage.name), d.level or 1), 14, Color3.fromRGB(255, 240, 215), false, Enum.TextXAlignment.Center)
			info.Position = UDim2.new(0, 4, 0.78, 0)
			info.Size = UDim2.new(1, -8, 0.1, 0)
			if following then
				local tag = text(tile, "FOLLOWING", 12, Theme.GOOD, true, Enum.TextXAlignment.Center)
				tag.Position = UDim2.new(0, 4, 0.88, 0)
				tag.Size = UDim2.new(1, -8, 0.09, 0)
			end
			tile.Activated:Connect(function()
				confirmSell = nil
				openCard(data, d)
			end)
		end
		-- la scheda aperta si aggiorna (es. dopo Follow o Evolve); se il drago non c'e' piu' si chiude
		if selected then
			local still = nil
			for _, d in data.dragons do
				if d.id == selected then
					still = d
				end
			end
			if still then
				openCard(data, still)
			elseif overlay then
				overlay:Destroy()
				overlay = nil
				selected = nil
			end
		end
	end

	render = function()
		table.clear(timers)
		Ui.clear(nestList)
		Ui.clear(dragonList)
		local raw = player:GetAttribute("DragonData")
		if type(raw) ~= "string" then
			return
		end
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok or type(data) ~= "table" then
			return
		end
		header.Text = string.format(
			"Evolution stones: %d  ·  Following: %d/%d  ·  Pen: %d (%d coins/min)",
			data.stones or 0,
			#data.equipped,
			data.maxEquipped or 1,
			data.roostSlots or 0,
			player:GetAttribute("RoostRate") or 0
		)
		for index, egg in data.nest do
			local c = Ui.template("EggCard", nestList)
			c.LayoutOrder = index
			Ui.skin(c, "rarity_" .. (RARITY[egg.rarity] or "common"))
			Theme.assetPreview(c.Icon, "icon_egg", preview("Eggs", egg.element))
			c.Title.Text = Names.t(egg.element) .. " Egg\n" .. Names.t(egg.rarity)
			local left = math.max(0, egg.readyAt - os.time())
			c.Time.Text = if left <= 0
				then "Ready to hatch"
				else string.format("Ready in %d:%02d", left // 60, left % 60)
			c.Hatch.Visible = left <= 0
			c.Time.Visible = left > 0
			table.insert(timers, { label = c.Time, hatch = c.Hatch, readyAt = egg.readyAt })
			c.Hatch.Activated:Connect(function()
				act("hatch", index)
			end)
		end
		if #data.nest == 0 then
			local c = Ui.template("TextCard", nestList)
			c.Text.Text = if (data.nestSlots or 0) > 0
				then "Find eggs and bring them to your home nest."
				else "Buy the Tent on your plot to unlock the nest."
		end
		renderDragons(data)
	end
	return render
end

-- ogni secondo dal menu: aggiorna i timer; true se un uovo e' appena pronto (serve rifare la lista)
function DragonUI.tick(): boolean
	local now = os.time()
	local ready = false
	for _, t in timers do
		local left = math.max(0, t.readyAt - now)
		if left <= 0 and not t.hatch.Visible then
			ready = true
		end
		t.label.Text = if left <= 0 then "Ready to hatch" else string.format("Ready in %d:%02d", left // 60, left % 60)
	end
	return ready
end

return DragonUI
