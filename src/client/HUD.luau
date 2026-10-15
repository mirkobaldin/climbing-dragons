--!strict
-- HUD da StarterGui: salute e stamina a sinistra, meteo a destra, missione al centro.
-- Pannello del drago persistente e avvisi dall alto; gli angoli inferiori restano liberi.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local ClimbConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClimbConfig"))
local Gear = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Gear"))
local Names = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Names"))
local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer

local HUD = {}

local WEATHER_NAMES =
	{ Clear = "Clear", Cloudy = "Cloudy", Rain = "Rain", Thunderstorm = "Thunderstorm", Storm = "Storm", Snow = "Snow" }

local Ui = require(ReplicatedStorage.Shared.UiView)

-- Barra degli attrezzi: stessi Tool e Humanoid del backpack Roblox, con icona e nome separati.
local function toolBar(gui: ScreenGui)
	local UIS = game:GetService("UserInputService")
	local UiAssets = require(ReplicatedStorage.Shared.UiAssets)
	local order = { ClimbConfig.TOOL_NAME, ClimbConfig.PICKAXE_NAME, ClimbConfig.GRAPPLE_NAME, ClimbConfig.TORCH_NAME }
	local icons = { "item_Piccozza", "item_Piccone", "item_Rampino", "item_Torcia" }
	local bar = Theme.scroll(gui)
	bar.Name = "ToolBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.ScrollingDirection = Enum.ScrollingDirection.X
	bar.AutomaticCanvasSize = Enum.AutomaticSize.X
	bar.ScrollBarThickness = 3
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar
	local tools: {Tool} = {}
	-- telefono: caselle piccole con la sola icona (prima 86x80 col nome: coprivano Ride e Z)
	local small = false
	local function equip(index: number)
		if not gui.Enabled then return end
		local tool = tools[index]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not tool or not humanoid or humanoid.Health <= 0 then return end
		if tool.Parent == character then humanoid:UnequipTools() else humanoid:EquipTool(tool) end
	end
	local function refresh()
		Ui.clear(bar)
		table.clear(tools)
		for _, parent in { player:FindFirstChildOfClass("Backpack"), player.Character } do
			if parent then
				for _, tool in parent:GetChildren() do
					if tool:IsA("Tool") then table.insert(tools, tool) end
				end
			end
		end
		table.sort(tools, function(a, b)
			local x, y = table.find(order, a.Name) or 99, table.find(order, b.Name) or 99
			return if x == y then a.Name < b.Name else x < y
		end)
		for i, tool in tools do
			local button = Theme.button(bar, "", Theme.BLUE, if small then UDim2.fromOffset(54, 54) else UDim2.fromOffset(86, 80))
			button.LayoutOrder = i
			Theme.action(button, if tool.Parent == player.Character then "main" else "alt")
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, if small then 6 else 4)
			icon.Size = if small then UDim2.fromOffset(40, 40) else UDim2.fromOffset(34, 34)
			icon.ZIndex = 3
			icon.Parent = button
			local known = table.find(order, tool.Name)
			local id = known and UiAssets.get(icons[known])
			icon.Image = id or tool.TextureId
			local name = Theme.label(button, tool.Name, 12, Theme.TEXT, true)
			name.Position = UDim2.fromOffset(3, 40)
			name.Size = UDim2.new(1, -6, 0, 36)
			name.ZIndex = 3
			name.TextXAlignment = Enum.TextXAlignment.Center
			Theme.fitText(name, 12, true)
			name.Visible = not small
			local key = Theme.label(button, tostring(i), 12, Theme.TEXT, true)
			key.Size = UDim2.fromOffset(20, 20)
			key.ZIndex = 4
			button.Activated:Connect(function() equip(i) end)
		end
	end
	local pending = false
	local function queue()
		if pending then return end
		pending = true
		task.defer(function() pending = false; refresh() end)
	end
	local connections: {RBXScriptConnection} = {}
	local function characterAdded(character: Model)
		for _, c in connections do c:Disconnect() end
		table.clear(connections)
		for _, parent in { player:WaitForChild("Backpack"), character } do
			table.insert(connections, parent.ChildAdded:Connect(queue))
			table.insert(connections, parent.ChildRemoved:Connect(queue))
		end
		queue()
	end
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then task.spawn(characterAdded, player.Character) end
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }
	UIS.InputBegan:Connect(function(input, processed)
		if processed or UIS:GetFocusedTextBox() then return end
		local i = table.find(keys, input.KeyCode)
		if i then equip(i) end
	end)
	Ui.viewportChanged(function(vp)
		local logical = Ui.fitScale(gui, vp)
		local was = small
		small = Ui.compact(vp) or Ui.touch()
		-- sul telefono un po' a sinistra del centro: a destra c'e' l'arco dei comandi (salto, Ride, Z)
		bar.Position = if logical.X < 600 then UDim2.new(0.5, 0, 1, -190) elseif small then UDim2.new(0.42, 0, 1, -6) else UDim2.new(0.5, 0, 1, -8)
		bar.Size = if small then UDim2.fromOffset(4 * 60 - 6, 58) else UDim2.fromOffset(math.min(4 * 92 - 6, logical.X - 24), 84)
		if was ~= small then
			queue()
		end
	end)
	gui:SetAttribute("CustomToolBar", true)
	-- in groppa o nella forma di drago gli attrezzi non si usano: barra nascosta
	local function ridingBar()
		bar.Visible = player:GetAttribute("Riding") ~= true
	end
	player:GetAttributeChangedSignal("Riding"):Connect(ridingBar)
	ridingBar()
end

function HUD.start()
	-- la salute la mostra la nostra HUD (cuore e barra): quella di Roblox (barra in alto e bordo
	-- rosso quando prendi danni) si spegne all'avvio, a ogni respawn e ogni 2 secondi, perche' le
	-- clip e il rampino rimettono "tutta" l'interfaccia di Roblox (CoreGuiType.All) e la
	-- riaccendevano: un giocatore la vedeva sovrapposta alla nostra
	local function hideRobloxHealth()
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			if StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Health) then
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			end
		end)
	end
	hideRobloxHealth()
	player.CharacterAdded:Connect(function()
		task.defer(hideRobloxHealth)
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			hideRobloxHealth()
		end
	end)
	local gui = Ui.screen("ClimbHUD")
	toolBar(gui)
	local me, coins, info, pet, quest =
		Ui.node(gui, "Player"),
		Ui.node(gui, "Coins"),
		Ui.node(gui, "Weather"),
		Ui.node(gui, "Pet"),
		Ui.node(gui, "Quest")
	local coinText, pitonText = coins.Text, coins.Pitons
	-- un colore per riquadro (prima tutti blu scuro uguali): sfumatura leggera sotto la cornice
	-- riquadri blu notte come il mockup dell'HUD (prima rosso, arancio, viola e azzurro insieme):
	-- il colore resta nelle barre e nelle icone
	for _, panel in { me, coins, pet, info } do
		Ui.tint(panel, Theme.DARK2, false, 0)
		local fill = panel:FindFirstChild("Tinta") :: Frame?
		if fill then
			fill.BackgroundTransparency = 0.18
		end
	end
	local weatherIcon, weatherFallback, timeBig, clock, altitude =
		info.Icon, info.Fallback, info.Time, info.Clock, info.Altitude
	local warmthBack, warmthFill, warmthText = info.Warmth, info.Warmth.Fill, info.Warmth.Text
	local finder, gearLabel = info.Finder, info.Gear
	Ui.node(me, "Name").Text = player.DisplayName
	local healthFill, healthText = me.Health.Fill, me.Health.Text
	local staminaBack, staminaFill, staminaText = me.Stamina, me.Stamina.Fill, me.Stamina.Text
	local shieldBack, shieldFill, shieldText = me.Shield, me.Shield.Fill, me.Shield.Text
	local petName, petLevel, petXpFill, petXpText, petStats =
		Ui.node(pet, "Name"), pet.Level, pet.XP.Fill, pet.XP.Text, pet.Stats
	local shieldLayout: (boolean) -> () = function(on: boolean)
		shieldBack.Visible = on
	end
	local questTitle, questText, skip = quest.Title, quest.Text, quest.Skip
	local hint = Ui.node(gui, "Hint")
	local noticePanel = Ui.node(gui, "Notice")
	local noticePosition = noticePanel.Position
	local noticeVersion = 0
	local function showNotice()
		local message = player:GetAttribute("Notice")
		if type(message) ~= "string" or message == "" then
			return
		end
		noticeVersion += 1
		local version = noticeVersion
		noticePanel.Text.Text = message
		local goal = noticePosition
		noticePanel.Position = goal - UDim2.fromOffset(0, 8)
		Ui.open(noticePanel)
		game:GetService("TweenService"):Create(noticePanel, TweenInfo.new(0.18), { Position = goal }):Play()
		task.delay(4, function()
			if noticeVersion == version then
				noticePanel.Visible = false
			end
		end)
	end
	player:GetAttributeChangedSignal("NoticeTime"):Connect(showNotice)
	-- Impaginazione in pixel logici (UiView.fitScale adatta tutto allo schermo). A sinistra in
	-- colonna: giocatore, monete, drago (poi i pulsanti del menu); a destra il meteo; in alto al
	-- centro la missione e sotto gli avvisi. Prima le misure erano in percentuale dello schermo
	-- e i testi minuscoli uscivano dai riquadri.
	local P = Ui.px
	local shieldOn = false
	local compact = false
	local logical = Vector2.new(1280, 680)
	-- colonna di sinistra: giocatore, subito sotto il drago (prima stava sotto le monete), poi
	-- le monete. Sul telefono tutto piu' stretto e basso (UiView.compact).
	local function layoutPlayer()
		-- sul telefono pannelli stretti e bassi (prima larghi 250 e alti 80: un terzo dello schermo)
		local x, w = if compact then 8 else 16, if compact then 196 else 340
		local y0 = Ui.menuMetrics(logical).y
		local h
		if compact then
			h = if shieldOn then 64 else 50
			P(me, 0, x, 0, y0, w, h)
			P(Ui.node(me, "Name"), 0, 10, 0, 4, 176, 16)
			P(me.HealthIcon, 0, 6, 0, 22, 14, 14)
			P(me.Health, 0, 24, 0, 22, 164, 13)
			P(me.StaminaIcon, 0, 6, 0, 37, 14, 14)
			P(me.Stamina, 0, 24, 0, 38, 164, 9)
			P(me.Shield, 0, 24, 0, 51, 164, 9)
		else
			-- (il nome toccava la cornice in alto: piu' giu' e pannello piu' alto)
			h = if shieldOn then 144 else 120
			P(me, 0, x, 0, y0, w, h)
			P(Ui.node(me, "Name"), 0, 62, 0, 20, 262, 22)
			P(me.HealthIcon, 0, 22, 0, 48, 30, 30)
			P(me.Health, 0, 62, 0, 50, 258, 26)
			P(me.StaminaIcon, 0, 24, 0, 82, 26, 26)
			P(me.Stamina, 0, 62, 0, 84, 258, 20)
			P(me.Shield, 0, 62, 0, 110, 258, 20)
		end
		local y = y0 + h + 6
		if pet.Visible then
			local ph = if compact then 42 else 98
			P(pet, 0, x, 0, y, w, ph)
			if compact then
				P(pet.Element, 0, 6, 0, 5, 32, 32)
				P(petName, 0, 44, 0, 3, 146, 16)
				P(petLevel, 0, 44, 0, 18, 146, 13)
				P(pet.XP, 0, 44, 0, 32, 146, 6)
			else
				P(pet.Element, 0, 16, 0, 12, 44, 44)
				P(petName, 0, 70, 0, 10, 254, 22)
				P(petLevel, 0, 70, 0, 34, 254, 20)
				P(pet.XP, 0, 18, 0, 64, 304, 22)
			end
			y += ph + 6
		end
		local ch = if compact then 26 else 50
		-- tasto Hide del menu (attributo UiCollapsed): via anche le monete
		coins.Visible = player:GetAttribute("UiCollapsed") ~= true
		P(coins, 0, x, 0, y, w, ch)
		if compact then
			P(coins.Icon, 0, 6, 0, 3, 20, 20)
			P(coinText, 0, 30, 0, 0, 100, 26)
			P(coins.PitonIcon, 0, 136, 0, 3, 20, 20)
			P(pitonText, 0, 158, 0, 0, 34, 26)
		else
			P(coins.Icon, 0, 14, 0, 8, 34, 34)
			P(coinText, 0, 56, 0, 0, 150, 50)
			P(coins.PitonIcon, 0, 216, 0, 8, 34, 34)
			P(pitonText, 0, 256, 0, 0, 70, 50)
		end
		gui:SetAttribute("LeftBottom", y + ch + 10)
	end
	shieldLayout = function(on: boolean)
		shieldOn = on
		shieldBack.Visible = on
		layoutPlayer()
	end
	local function texts()
		local k = if compact then 0.7 else 1
		Ui.text(Ui.node(me, "Name"), math.floor(18 * k), true)
		Ui.text(healthText, if compact then 10 else 15, true)
		-- telefono: barre sottili senza scritta (stamina, scudo e XP si leggono dal colore)
		staminaText.Visible = not compact
		shieldText.Visible = not compact
		petXpText.Visible = not compact
		Ui.fit(staminaText, if compact then 11 else 14, 9, true)
		Ui.fit(shieldText, if compact then 11 else 14, 9, true)
		Ui.fit(coinText, math.floor(24 * k), 12, true) -- 9 cifre andavano a capo
		Ui.text(pitonText, math.floor(24 * k), true)
		Ui.text(petName, if compact then 12 else 17, true)
		Ui.text(petLevel, if compact then 10 else 14)
		Ui.fit(petXpText, if compact then 11 else 14, 9, true)
		Ui.text(weatherFallback, if compact then 24 else 30)
		Ui.text(timeBig, if compact then 22 else 32, true)
		Ui.text(clock, if compact then 12 else 16)
		Ui.text(altitude, if compact then 13 else 17, true)
		Ui.text(warmthText, if compact then 10 else 13, true)
		Ui.fit(finder, if compact then 12 else 15, 10, true)
		finder.TextXAlignment = Enum.TextXAlignment.Center
		Ui.text(questTitle, if compact then 15 else 19, true)
		Ui.text(questText, if compact then 13 else 15)
		Ui.text(skip, if compact then 11 else 13, true)
		Ui.text(noticePanel.Text, if compact then 14 else 17, true)
		Ui.text(hint, if compact then 15 else 19, true)
		for _, l in { timeBig, clock, altitude, petName, petLevel, Ui.node(me, "Name"), questTitle, questText } do
			(l :: TextLabel).TextXAlignment = Enum.TextXAlignment.Left
		end
		questText.TextTruncate = Enum.TextTruncate.AtEnd
		petName.TextTruncate = Enum.TextTruncate.AtEnd
		petLevel.TextTruncate = Enum.TextTruncate.AtEnd
	end
	petStats.Visible = false -- l'attacco va nella riga del livello
	gearLabel.Visible = false -- l'elenco degli attrezzi era illeggibile: sta nello zaino
	-- meteo compresso (tocco sul riquadro): solo icona, ora e condizioni. Sul telefono parte
	-- compresso, perche' copriva i pulsanti Ride e Fire; il calore torna se fa molto freddo
	local folded = false
	local foldedSet = false
	local chevron = Instance.new("TextLabel")
	chevron.Name = "Piega"
	chevron.BackgroundTransparency = 1
	chevron.TextColor3 = Theme.TEXT
	chevron.Font = Enum.Font.GothamBlack
	chevron.TextSize = 14
	chevron.AnchorPoint = Vector2.new(1, 0)
	chevron.Position = UDim2.new(1, -6, 0, 4)
	chevron.Size = UDim2.fromOffset(18, 18)
	chevron.Parent = info
	local function layoutWeather()
		local frozen = warmthBack.Visible
		chevron.Text = if folded then "▼" else "▲"
		altitude.Visible = not folded
		if compact and folded then
			local h = 58 + (if frozen then 22 else 0)
			P(info, 1, -10, 0, Ui.menuMetrics(logical).y, 190, h, 1, 0)
			P(weatherIcon, 0, 8, 0, 7, 44, 44)
			P(weatherFallback, 0, 8, 0, 7, 44, 44)
			P(timeBig, 0, 58, 0, 5, 120, 26)
			P(clock, 0, 58, 0, 31, 120, 18)
			P(warmthBack, 0, 10, 0, 58, 170, 18)
		elseif folded then
			local h = 84 + (if frozen then 30 else 0)
			P(info, 1, -16, 0, Ui.menuMetrics(logical).y, 240, h, 1, 0)
			P(weatherIcon, 0, 12, 0, 13, 58, 58)
			P(weatherFallback, 0, 12, 0, 13, 58, 58)
			P(timeBig, 0, 82, 0, 12, 140, 34)
			P(clock, 0, 82, 0, 48, 140, 20)
			P(warmthBack, 0, 16, 0, 84, 208, 18)
		elseif compact then
			local h = 76 + (if warmthBack.Visible then 22 else 0) + (if finder.Visible then 34 else 0)
			P(info, 1, -10, 0, Ui.menuMetrics(logical).y, 226, h, 1, 0)
			P(weatherIcon, 0, 10, 0, 10, 44, 44)
			P(weatherFallback, 0, 10, 0, 10, 44, 44)
			P(timeBig, 0, 62, 0, 6, 142, 26)
			P(clock, 0, 62, 0, 32, 142, 16)
			P(altitude, 0, 62, 0, 50, 142, 18)
			P(warmthBack, 0, 12, 0, 76, 190, 18)
			P(finder, 0, 12, 0, h - 34, 202, 28)
		else
			local h = 122 + (if warmthBack.Visible then 30 else 0) + (if finder.Visible then 42 else 0)
			P(info, 1, -16, 0, Ui.menuMetrics(logical).y, 272, h, 1, 0)
			P(weatherIcon, 0, 16, 0, 16, 58, 58)
			P(weatherFallback, 0, 16, 0, 16, 58, 58)
			P(timeBig, 0, 88, 0, 14, 148, 34)
			P(clock, 0, 88, 0, 50, 148, 20)
			P(altitude, 0, 20, 0, 84, 212, 22)
			P(warmthBack, 0, 20, 0, 118, 232, 18)
			P(finder, 0, 20, 0, h - 42, 232, 36)
		end
  if logical.X < 600 then
   info.AnchorPoint = Vector2.zero
   info.Position = UDim2.fromOffset(10, ((gui:GetAttribute("LeftBottom") or 300) :: number) + 4)
   info.Size = UDim2.fromOffset(logical.X - 20, 80)
  end
 end
 local relayingWeather = false
	local function relayWeather()
		if relayingWeather then
			return
		end
		relayingWeather = true
		layoutWeather()
		relayingWeather = false
	end
	finder:GetPropertyChangedSignal("Visible"):Connect(relayWeather)
	warmthBack:GetPropertyChangedSignal("Visible"):Connect(relayWeather)
	info.Active = true
	info.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			folded = not folded
			foldedSet = true
			relayWeather()
		end
	end)
	local function layoutAll()
		texts()
		layoutPlayer()
		layoutWeather()
		local portrait = logical.X < 600
  local top = Ui.menuMetrics(logical).y
  local x = if portrait then 10 elseif compact then 214 else 370
  local w = if portrait then logical.X - 20 else math.max(220, logical.X - x - (if compact then 210 else 300))
  local y = if portrait then ((gui:GetAttribute("LeftBottom") or 300) :: number) + 92 else top
  -- missione: sul telefono piu' bassa e stretta, a destra dei pannelli
  if compact and not portrait then
   w = math.min(w, 340)
  end
  P(quest, 0, x, 0, y, w, if compact then 96 else 136)
  P(quest.Icon, 0, 10, 0, 10, 30, 30)
  P(questTitle, 0, 46, 0, 8, w - 58, 28)
  P(questText, 0, 10, 0, 42, w - 20, 44)
  P(skip, 1, -10, 1, -6, math.min(150, w - 20), 44, 1, 1)
  P(noticePanel, 0, x, 0, y + 144, w, 44)
  P(noticePanel.Text, 0, 8, 0, 6, w - 16, 32)
  P(hint, 0.5, 0, 1, -90, math.min(560, logical.X - 32), 40, 0.5, 1)
  if portrait then
   me.Size = UDim2.fromOffset(logical.X - 20, me.Size.Y.Offset)
   pet.Size = UDim2.fromOffset(logical.X - 20, pet.Size.Y.Offset)
   coins.Size = UDim2.fromOffset(logical.X - 20, coins.Size.Y.Offset)
  end
		noticePosition = noticePanel.Position
	end
	Ui.viewportChanged(function(vp)
		logical = Ui.fitScale(gui, vp)
		compact = Ui.compact(vp)
		if not foldedSet then
			folded = compact
		end
		layoutAll()
	end)
	pet:GetPropertyChangedSignal("Visible"):Connect(layoutPlayer)
	local function refreshPet()
		local ok, data = pcall(function()
			return game:GetService("HttpService"):JSONDecode(player:GetAttribute("DragonData") :: string)
		end)
		local d: any = nil
		if ok and type(data) == "table" and data.equipped then
			for _, x in data.dragons or {} do
				if x.id == data.equipped[1] then
					d = x
				end
			end
		end
		pet.Visible = d ~= nil and player:GetAttribute("UiCollapsed") ~= true
		if not d then
			return
		end
		Ui.asset(pet.Element, "elem_" .. d.element)
		local lv = d.level or 1
		local need = DragonConfig.xpForLevel(lv)
		local stage = DragonConfig.STAGES[math.clamp(d.stage or 1, 1, #DragonConfig.STAGES)]
		local stageName = Names.t(stage.name)
		petName.Text = string.format('%s <font color="#ffc86a">%s</font>', Names.t(d.element), Names.t(d.rarity))
		local grade = DragonConfig.grade(d)
		-- meno scritte (Mirko: "troppe scritte"): livello e stadio; attacco e voto stanno nel menu
		petLevel.Text = string.format("Lv %d · %s", lv, stageName)
		local _ = grade
		petXpFill.Size = UDim2.fromScale(math.clamp((d.xp or 0) / need, 0, 1), 1)
		petXpText.Text = string.format("%d / %d XP", math.floor(d.xp or 0), need)
		petStats.Text = string.format(
			"ATK <b>%.1f</b> · Evo <b>%d%%</b>",
			8 + 0.15 * lv,
			math.floor(math.clamp(lv / 100, 0, 1) * 100)
		)
	end
	player:GetAttributeChangedSignal("DragonData"):Connect(refreshPet)
	-- tasto Hide del menu: drago e monete si piegano insieme ai pulsanti
	player:GetAttributeChangedSignal("UiCollapsed"):Connect(function()
		refreshPet()
		layoutPlayer()
	end)
	refreshPet()
	local armedAt = -math.huge
	skip.Activated:Connect(function()
		if os.clock() - armedAt > 4 then
			armedAt = os.clock()
			skip.Text = "Sure? Tap again"
			skip.BackgroundColor3 = Theme.BAD
			task.delay(4, function()
				if os.clock() - armedAt >= 4 then
					skip.Text = "Skip tutorial"
					skip.BackgroundColor3 = Theme.ACCENT
				end
			end)
			return
		end
		armedAt = -math.huge
		skip.Text = "Skip tutorial"
		skip.BackgroundColor3 = Theme.ACCENT
		-- durante le missioni il pulsante salta la missione, non il tutorial
		local name = if player:GetAttribute("TutorialText") then "SkipTutorial" else "SkipMission"
		local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild(name)
		if remote then
			(remote :: RemoteEvent):FireServer()
		end
	end)
	local lastHint, hintTime = "", 0
	local lastNotice: any = nil
	local shownHealth = 1
	local lastWeather = ""

	RunService.RenderStepped:Connect(function(dt)
  local pg = player.PlayerGui
  local menu = pg:FindFirstChild("MainMenu")
  local travel = pg:FindFirstChild("Teletrasporto")
  local death = pg:FindFirstChild("DeathScreen")
  local travelPanel = travel and travel:FindFirstChild("Panel") :: GuiObject?
  gui.Enabled = not ((menu and menu:GetAttribute("MenuOpen") == true)
   or (travelPanel and travelPanel.Visible) or (death and death:IsA("ScreenGui") and death.Enabled))
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

		coinText.Text = tostring(player:GetAttribute("Coins") or 0)
		pitonText.Text = tostring(player:GetAttribute("Pitons") or 0)

		-- salute (scende in modo fluido)
		local health = if humanoid then math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1) else 0
		shownHealth += (health - shownHealth) * math.min(1, dt * 8)
		healthFill.Size = UDim2.new(shownHealth, 0, 1, 0)
		healthText.Text = if humanoid then tostring(math.ceil(humanoid.Health)) else ""

		-- stamina (si vede quando serve)
		local ratio = ClientState.stamina / ClimbConfig.STAMINA_MAX
		staminaBack.Visible = true
		staminaFill.Size = UDim2.new(ratio, 0, 1, 0)
		staminaFill.BackgroundColor3 = if ratio > 0.5
			then Theme.GOOD
			elseif ratio > 0.2 then Theme.ACCENT
			else Theme.BAD
		staminaText.Text = string.format("%d%%", math.floor(ratio * 100))
		local shieldMax = (player:GetAttribute("ShieldMax") or 0) :: number
		if (shieldMax > 0) ~= shieldBack.Visible then
			shieldLayout(shieldMax > 0)
		end
		if shieldMax > 0 then
			local sh = (player:GetAttribute("Shield") or 0) :: number
			shieldFill.Size = UDim2.new(math.clamp(sh / shieldMax, 0, 1), 0, 1, 0)
			shieldText.Text = string.format("Shield %d", sh)
		end

		-- ora, meteo, quota, calore
		local t = Lighting.ClockTime
		local day = t >= 6 and t < 19
		local w = workspace:GetAttribute("Weather") :: any
		local ICON = {
			Clear = if day then "☀️" else "🌙",
			Cloudy = "☁️",
			Rain = "🌧️",
			Thunderstorm = "⛈️",
			Storm = "🌪️",
			Snow = "❄️",
		}
		local weatherKey = ({
			Clear = if day then "clear" else "night",
			Cloudy = "cloudy",
			Rain = "rain",
			Thunderstorm = "thunder",
			Storm = "storm",
			Snow = "snow",
		})[w] or (if day then "clear" else "night")
		if weatherKey ~= lastWeather then
			lastWeather = weatherKey
			weatherFallback.Visible = not Ui.asset(weatherIcon, "weather_" .. weatherKey)
			weatherFallback.Text = ICON[w] or (if day then "☀️" else "🌙")
		end
		timeBig.Text = string.format("%02d:%02d", math.floor(t), math.floor((t % 1) * 60))
		clock.Text = string.format("%s  ·  %s", if day then "Day" else "Night", WEATHER_NAMES[w] or "Clear")
		local alt = if root then math.max(0, math.floor(root.Position.Y - 20)) else 0
		altitude.Text = string.format("Altitude  %d m", alt)
		local warmth = (player:GetAttribute("Warmth") or 100) :: number
		-- compresso: il calore si vede solo quando fa davvero freddo
		warmthBack.Visible = if folded then warmth < 40 else (warmth < 99.5 or alt > Gear.COLD_ALTITUDE - 20)
		warmthFill.Size = UDim2.new(math.clamp(warmth / 100, 0, 1), 0, 1, 0)
		warmthFill.BackgroundColor3 = if warmth > 40
			then Theme.ORANGE
			else Theme.BLUE
		warmthText.Text = if warmth <= 0
			then "🥶 Freezing!"
			else string.format("🌡️ Warmth %d%%", math.floor(warmth))

		local carrying = player:GetAttribute("CarryingEgg")
		local finderText = ClientState.eggFinder
		if type(carrying) == "string" then
			local parts = string.split(carrying, "|")
			finderText =
				string.format("Carrying an egg (%s %s): take it to your nest!", Names.t(parts[2]), Names.t(parts[1]))
		end
		finder.Visible = finderText ~= nil and not folded
		finder.Text = finderText or ""
		local owned = {}
		for _, recipe in Gear.RECIPES do
			if Gear.has(player, recipe.id) then
				table.insert(owned, recipe.name)
			end
		end
		gearLabel.Text = table.concat(owned, " · ")

		-- tutorial, poi le missioni (stesso riquadro)
		local tutorialLine = player:GetAttribute("TutorialText")
		local questLine = if type(tutorialLine) == "string" then tutorialLine else player:GetAttribute("MissionText")
		local menu = player.PlayerGui:FindFirstChild("MainMenu")
		local menuOpen = menu ~= nil and menu:GetAttribute("MenuOpen") == true
		info.Visible = not menuOpen
		quest.Visible = type(questLine) == "string" and not menuOpen
		-- comandi giusti per computer o telefono (UiView.hintText)
		questText.Text = if type(questLine) == "string" then Ui.hintText(questLine) else ""
		local inTutorial = type(tutorialLine) == "string"
		questTitle.Text = if inTutorial then "Tutorial" else "Mission"
		if os.clock() - armedAt > 4 then
			skip.Text = if inTutorial then "Skip tutorial" else "Skip mission"
		end

		-- avvisi dal server e suggerimenti (restano 4 secondi)
		local notice = player:GetAttribute("Notice")
		local noticeTime = player:GetAttribute("NoticeTime")
		if type(notice) == "string" and noticeTime ~= lastNotice then
			lastNotice = noticeTime
			ClientState.hint = notice
		end
		-- nell'arena sei il drago: niente suggerimenti dell'arrampicata ("nessuna parete" ecc.)
		if
			(ClientState :: any).dragonMode
			and type(ClientState.hint) == "string"
			and not string.find(ClientState.hint :: string, "XP", 1, true)
		then
			ClientState.hint = ""
		end
		if ClientState.hint ~= lastHint then
			lastHint = ClientState.hint
			hintTime = os.clock()
		end
		hint.Text = if os.clock() - hintTime < 4 then lastHint else ""
		local combat = gui.Parent and gui.Parent:FindFirstChild("CombatHUD")
		hint.Visible = not combat or (Ui.node(combat, "Timer").Text == "" and Ui.node(combat, "Event").Text == "")
		if compact and (quest.Visible or noticePanel.Visible) then hint.Visible = false end
	end)
end

return HUD
