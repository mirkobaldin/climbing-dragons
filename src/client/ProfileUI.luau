--!strict
-- Pagina iniziale del menu unico (si apre col tasto menu in alto a sinistra), come lo schizzo di
-- Mirko del 15/10: al centro i record (ore di gioco, draghi, vette, quota...), a destra il
-- personaggio 3D che ruota su un fondo scuro coi raggi e sotto le statistiche (attacco, scudo,
-- stamina, salute).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local ClimbConfig = require(Shared:WaitForChild("ClimbConfig"))
local EnemyConfig = require(Shared:WaitForChild("EnemyConfig"))
local UpgradeConfig = require(Shared:WaitForChild("UpgradeConfig"))
local Ui = require(Shared:WaitForChild("UiView"))
local Theme = require(script.Parent.Theme)
local Slant = require(script.Parent.Slant)
local UiKit = require(script.Parent.UiKit)
local AvatarView = require(script.Parent.AvatarView)
local player = Players.LocalPlayer
local ProfileUI = {}

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function hours(sec: number): string
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	return if h > 0 then string.format("%dh %02dm", h, m) else string.format("%dm", m)
end

local function dragonData(): any
	local raw = player:GetAttribute("DragonData")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then data else nil
end

local function stat(name: string): number
	return (player:GetAttribute(name) or 0) :: number
end

-- statistiche del giocatore (stesse formule del server)
function ProfileUI.stats(): { any }
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local atk = (EnemyConfig.PLAYER_DAMAGE[ClimbConfig.TOOL_NAME] or 20) * 1.3
		* UpgradeConfig.value(player, "Lancio", "mult") * (1 + stat("Forza") * 0.02)
	local shield = UpgradeConfig.value(player, "Scudo", "hp")
	local stamina = ClimbConfig.STAMINA_MAX * UpgradeConfig.value(player, "Esoscheletro", "stamina")
	local health = if humanoid then humanoid.MaxHealth else 100
	return {
		{ name = "ATTACK", value = atk, max = 22 * 1.3 * 2.6 * 1.4, color = Theme.BAD },
		{ name = "SHIELD", value = shield, max = 110, color = Theme.BLUE },
		{ name = "STAMINA", value = stamina, max = 180, color = Theme.GOOD },
		{ name = "HEALTH", value = health, max = 250, color = Theme.PINK },
	}
end

-- ctx: { fit = function() } dal menu (MainMenu), per l'altezza della pagina stretta
function ProfileUI.mount(container: Frame, ctx: any?): () -> ()
	local root = Theme.frame(container, Color3.new(), 1)
	root.Name = "Profilo"
	root.Size = UDim2.fromScale(1, 1)

	-- RECORD (al centro)
	local recBox = Theme.frame(root, Theme.DARK, 1)
	recBox.Name = "Record"
	UiKit.panel(recBox, { transparency = 0.3 })
	local recTitle = UiKit.label(recBox, "Your records", "section", 20)
	recTitle.TextColor3 = UiKit.ACCENT
	recTitle.Position = UDim2.fromOffset(20, 12)
	recTitle.Size = UDim2.new(1, -40, 0, 30)
	recTitle.ZIndex = 3
	local recGrid = Theme.scroll(recBox)
	recGrid.Position = UDim2.fromOffset(16, 52)
	recGrid.Size = UDim2.new(1, -32, 1, -64)
	recGrid.ZIndex = 3
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = recGrid

	-- PERSONAGGIO (a destra) e statistiche sotto
	local side = Theme.frame(root, Theme.DARK, 1)
	side.Name = "Personaggio"
	side.ClipsDescendants = false
	-- il personaggio sta nella scena del menu, non chiuso in un riquadro: niente fondo, un alone
	-- fermo dietro, l'ombra a terra, e il pannello delle statistiche che gli passa davanti alle
	-- gambe (strati a profondita' diverse, come il riferimento di Mirko)
	local stage = Theme.frame(side, Theme.DARK, 1)
	stage.Name = "Palco"
	stage.ClipsDescendants = false
	local halo = Instance.new("Frame")
	halo.Name = "Alone"
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(0.95, 0.95)
	halo.BackgroundColor3 = UiKit.ACCENT
	halo.BackgroundTransparency = 0.86
	halo.BorderSizePixel = 0
	halo.Parent = stage
	local hr = Instance.new("UIAspectRatioConstraint")
	hr.Parent = halo
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0.5, 0)
	hc.Parent = halo
	local hg = Instance.new("UIGradient")
	hg.Rotation = 90
	hg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	hg.Parent = halo
	local ground = Instance.new("Frame")
	ground.Name = "Ombra"
	ground.AnchorPoint = Vector2.new(0.5, 0.5)
	ground.Position = UDim2.fromScale(0.5, 0.86)
	ground.Size = UDim2.fromScale(0.62, 0.07)
	ground.BackgroundColor3 = Color3.new(0, 0, 0)
	ground.BackgroundTransparency = 0.45
	ground.BorderSizePixel = 0
	ground.ZIndex = 2
	ground.Parent = stage
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0.5, 0)
	gc.Parent = ground
	local name = UiKit.label(stage, player.DisplayName, "title", 26)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Position = UDim2.fromOffset(10, 10)
	name.Size = UDim2.new(1, -20, 0, 30)
	name.ZIndex = 6
	-- il personaggio vero in 3D (client/AvatarView): si gira col mouse o col dito, FRONT lo
	-- rimette di fronte
	local avatarBox = Theme.frame(stage, Color3.new(), 1)
	avatarBox.Name = "Modello"
	avatarBox.ZIndex = 5
	avatarBox.ClipsDescendants = false
	local avatar = AvatarView.new(avatarBox, function()
		return container.Visible and root.Parent ~= nil
	end)
	local vf = avatarBox
	local front = avatar.front
	local rebuild = avatar.rebuild
	local statBox = Theme.frame(side, Theme.DARK, 1)
	statBox.Name = "Statistiche"
	UiKit.panel(statBox, { transparency = 0.18 })
	local statRows: { any } = {}
	-- barre con la cornice di Codex (a parallelogramma quando c'e' la cornice obliqua) ed etichette
	-- in Oswald come il resto del menu (Mirko 16/10: il carattere di prima non piaceva)
	local BAR_KIND = { "health", "shield", "stamina", "health" }
	for i = 1, 4 do
		local label = UiKit.label(statBox, "", "name", 16)
		label.ZIndex = 3
		local bar = UiKit.bar(statBox, BAR_KIND[i], Theme.GOOD, UiKit.INK, 7)
		local value = UiKit.label(statBox, "", "stat", 18)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.ZIndex = 4
		statRows[i] = { label = label, bar = bar, value = value }
	end



	local function layout()
		local w, h = root.AbsoluteSize.X, root.AbsoluteSize.Y
		local gui = container:FindFirstAncestorWhichIsA("ScreenGui")
		local su = gui and gui:FindFirstChild("ScalaUI") :: UIScale?
		local k = if su and su.Scale > 0 then su.Scale else 1
		w, h = w / k, h / k
		if w < 50 then
			return
		end
		-- pagina stretta (telefono piccolo): record sopra, personaggio e statistiche sotto
		local stacked = w < 600
		local low = h < 420 -- telefono in orizzontale: record 58%, personaggio e statistiche 42%
		local sideW = if stacked then w elseif low then math.floor(w * 0.42) else math.clamp(math.floor(w * 0.36), 220, 360)
		local recH, sideH = 300, 470
		if stacked then
			recBox.Size = UDim2.new(1, 0, 0, recH)
			side.Position = UDim2.fromOffset(0, recH + 12)
			side.Size = UDim2.new(1, 0, 0, sideH)
			h = sideH
		else
			recBox.Size = UDim2.new(1, -(sideW + 12), 1, 0)
			side.Position = UDim2.new(1, -sideW, 0, 0)
			side.Size = UDim2.new(0, sideW, 1, 0)
		end
		local wantH = if stacked then recH + 12 + sideH else 0
		if container:GetAttribute("AltezzaMinima") ~= wantH then
			container:SetAttribute("AltezzaMinima", wantH)
			if ctx and ctx.fit then
				task.defer(ctx.fit)
			end
		end
		local statH = math.clamp(math.floor(h * 0.36), if low then 116 else 132, 190)
		-- sopra il pannello delle statistiche, che copre le gambe del personaggio
		front.Position = UDim2.new(1, -6, 1, -(math.floor(statH * 0.55) + 6))
		front.Size = UDim2.fromOffset(64, if low then 26 else 30)
		name.TextSize = if low then 20 else 26
		name.Size = UDim2.new(1, -90, 0, if low then 24 else 30)
		name.Position = UDim2.fromOffset(10, if low then 4 else 10)
		vf.Position = UDim2.fromOffset(0, if low then 26 else 40)
		vf.Size = UDim2.new(1, 0, 1, if low then -26 else -40)
		-- il palco continua dietro le statistiche: il pannello copre le gambe del personaggio
		stage.Size = UDim2.new(1, 0, 1, -math.floor(statH * 0.45))
		statBox.Position = UDim2.new(0, 0, 1, -statH)
		statBox.Size = UDim2.new(1, 0, 0, statH)
		local rowH = (statH - 20) / 4
		for i, r in statRows do
			local y = 10 + (i - 1) * rowH
			r.label.Position = UDim2.fromOffset(14, y)
			r.label.Size = UDim2.new(0, 92, 0, rowH - 4)
			-- (la cornice sta fuori dalla barra: barra un po' piu' bassa e rientrata)
			r.bar.Position = UDim2.fromOffset(116, y + rowH * 0.28)
			r.bar.Size = UDim2.new(1, -(116 + 84), 0, math.floor(rowH * 0.4))
			r.value.Position = UDim2.new(1, -66, 0, y)
			r.value.Size = UDim2.fromOffset(54, rowH - 4)
		end
		local gw = (if stacked then w else w - sideW - 12) - 32 - 8
		-- almeno due colonne anche sul telefono (tessere piu' strette ma leggibili)
		local cols = math.clamp(math.floor((gw + 10) / 240), if gw >= 260 then 2 else 1, 3)
		local cw = math.floor((gw - (cols - 1) * 10) / cols)
		grid.CellSize = UDim2.fromOffset(cw, if low then 64 else 84)
		recTitle.Visible = not low
		recGrid.Position = UDim2.fromOffset(if low then 8 else 16, if low then 8 else 52)
		recGrid.Size = UDim2.new(1, if low then -16 else -32, 1, if low then -16 else -64)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	local function tile(order: number, icon: string, value: string, label: string, color: Color3)
		-- tessera: superficie in rilievo, angoli vivi, numero bianco grande, segno colorato a sinistra
		local t = Theme.frame(recGrid, UiKit.RAISED, 0.3)
		t.LayoutOrder = order
		t.ZIndex = 3
		UiKit.edge(t)
		local bar = Theme.frame(t, color, 0)
		bar.Size = UDim2.new(0, 3, 1, 0)
		bar.ZIndex = 4
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Position = UDim2.fromOffset(14, 20)
		img.Size = UDim2.fromOffset(44, 44)
		img.ZIndex = 4
		img.Parent = t
		-- tessere strette (telefono): senza icona, il numero ha piu' spazio
		if not Ui.asset(img, icon) or grid.CellSize.X.Offset < 170 then
			img.Visible = false
		end
		-- tessere basse (telefono in orizzontale): icona, numero e nome piu' stretti
		local lowTile = grid.CellSize.Y.Offset < 80
		if lowTile then
			img.Position = UDim2.fromOffset(10, 12)
			img.Size = UDim2.fromOffset(38, 38)
		end
		local x = if img.Visible then (if lowTile then 56 else 66) else 18
		-- tessera di Codex: l'icona nel pozzetto a sinistra (sempre), numero e nome a destra
		if UiKit.Cornici.apply(t, "frame_record_tile") then
			UiKit.edge(t, UiKit.LINE, 1, 1)
			bar.Visible = false
			local th = grid.CellSize.Y.Offset
			local well = math.floor(172 * th / 168)
			local isz = math.floor(math.min(well * 0.66, th * 0.6))
			img.Visible = Ui.asset(img, icon)
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromOffset(math.floor(well / 2) + 1, math.floor(th / 2))
			img.Size = UDim2.fromOffset(isz, isz)
			x = well + 8
		end
		local v = UiKit.label(t, value, "stat", if lowTile then 22 else 28)
		v.Position = UDim2.fromOffset(x, if lowTile then 4 else 10)
		v.Size = UDim2.new(1, -x - 6, 0, if lowTile then 28 else 36)
		v.ZIndex = 4
		local l = UiKit.label(t, label, "status")
		l.TextTruncate = Enum.TextTruncate.None
		l.TextWrapped = true
		l.Position = UDim2.fromOffset(x, if lowTile then 32 else 46)
		l.Size = UDim2.new(1, -x - 6, 0, if lowTile then 28 else 32)
		l.TextYAlignment = Enum.TextYAlignment.Top
		l.ZIndex = 4
	end

	local function refresh()
		layout() -- prima le misure delle tessere, poi le tessere
		Ui.clear(recGrid)
		local data = dragonData()
		local dragons = if data then #(data.dragons or {}) else 0
		local best = player:GetAttribute("BestDescent")
		local bestLevel = 0
		for _, d in (if data then data.dragons or {} else {}) :: { any } do
			bestLevel = math.max(bestLevel, d.level or 1)
		end
		tile(1, "icon_quest", hours(stat("PlayTime")), "Time played", Theme.ACCENT)
		tile(2, "icon_dragons", tostring(dragons), "Dragons owned", Theme.PURPLE)
		tile(3, "icon_dragons", "Lv " .. bestLevel, "Strongest dragon", Theme.PINK)
		tile(4, "icon_altitude", fmt(stat("MaxAltitude")) .. " m", "Highest altitude", Theme.BLUE)
		tile(5, "icon_altitude", fmt(stat("Summits")), "Summits reached", Theme.TEAL)
		tile(6, "act_climb", fmt(stat("MetersClimbed")) .. " m", "Meters climbed", Theme.GOOD)
		tile(7, "act_throw", fmt(stat("Kills")), "Enemies defeated", Theme.BAD)
		tile(8, "act_shoot", fmt(stat("BossKills")), "Bosses defeated", Theme.ORANGE)
		tile(9, "icon_coin", if type(best) == "number" then string.format("%.1f s", best) else "-", "Fastest descent", Theme.ACCENT)
		tile(10, "icon_egg", fmt(stat("EggsIncubated")), "Eggs brought home", Theme.TEAL)
		tile(11, "icon_coin", fmt(stat("Coins")), "Coins now", Theme.ACCENT)
		tile(12, "icon_settings", fmt(stat("Rebirths")), "Rebirths", Theme.PURPLE)
		for i, s in ProfileUI.stats() do
			local r = statRows[i]
			r.label.Text = s.name
			r.label.TextColor3 = s.color
			UiKit.text(r.label, "name", 16)
			r.label.TextColor3 = s.color
			Slant.paint(r.bar:FindFirstChild("Pieno") :: Instance, s.color, 0)
			Slant.setFill(r.bar, s.value / s.max)
			r.value.Text = tostring(math.floor(s.value + 0.5))
		end
		rebuild()
		layout()
	end
	return refresh
end

return ProfileUI
