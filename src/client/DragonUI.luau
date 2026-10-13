--!strict
-- Carte del nido e della collezione, con logica server invariata.
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
			"Stones: %d · Following: %d/%d · Home: %d (%d coins/min)",
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
		for index, d in data.dragons do
			local e = DragonConfig.element(d.element)
			local stage = DragonConfig.STAGES[d.stage] or DragonConfig.STAGES[1]
			local nextStage = DragonConfig.STAGES[d.stage + 1]
			local following = table.find(data.equipped, d.id) ~= nil
			local c = Ui.template("DragonCard", dragonList)
			c.LayoutOrder = index
			Ui.skin(c, "rarity_" .. (RARITY[d.rarity] or "common"))
			if following then
				c.Stroke.Color = Theme.GOOD
				c.Stroke.Enabled = true
			end
			Theme.viewport(c.Preview, preview("Dragons", d.element), UDim2.fromScale(1, 1), false)
			Ui.asset(c.Element, "elem_" .. d.element)
			c.Title.Text = (if d.shiny then "SHINY · " else "")
				.. Names.dragon(d.element)
				.. " · "
				.. Names.t(d.rarity)
				.. " · "
				.. Names.t(stage.name)
			-- statistiche del drago (ogni uovo ne da' di diverse) e la sua abilita'
			local grade = DragonConfig.grade(d)
			local gradeColor = ({ S = "#ffd75e", A = "#7fe08a", B = "#8fc8ff", C = "#c9c9c9" })[grade]
			c.Ability.RichText = true
			c.Ability.Text = string.format(
				'<font color="%s"><b>Grade %s</b></font> · ATK <b>%d</b> · CRIT <b>%d%%</b>\n%s',
				gradeColor,
				grade,
				math.floor(DragonConfig.attack(d) + 0.5),
				math.floor((d.crit or 0.05) * 100 + 0.5),
				if e then e.ability else ""
			)
			local level = d.level or 1
			local maxed = level >= DragonConfig.MAX_LEVEL
			local need = DragonConfig.xpForLevel(level)
			c.XP.Fill.Size = UDim2.fromScale(if maxed then 1 else math.clamp((d.xp or 0) / need, 0, 1), 1)
			c.XP.Text.Text = if maxed
				then string.format("Lv %d · MAX", level)
				else string.format("Lv %d · %d/%d XP", level, d.xp or 0, need)
			c.Follow.Text = if following then "Rest" else "Follow"
			c.Follow.Activated:Connect(function()
				act(if following then "unequip" else "equip", d.id)
			end)
			c.Evolve.Visible = nextStage ~= nil
			c.Evolve.Text = if maxed then "Evolve!" else string.format("Evolve (Lv %d)", DragonConfig.MAX_LEVEL)
			c.Evolve.Activated:Connect(function()
				if nextStage then
					act("evolve", d.id)
				end
			end)
			local price = (EconomyConfig.DRAGON_PRICES[d.rarity] or 20) * d.stage
			c.Sell.Text = if confirmSell == d.id then "Sure?" else "Sell " .. price
			Ui.row({ c.Follow, c.Evolve, c.Sell }, 142, 96, 34)
			c.Sell.Activated:Connect(function()
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
