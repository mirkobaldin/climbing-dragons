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

function HUD.start()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	local gui = Ui.screen("ClimbHUD")
	local me, coins, info, pet, quest =
		Ui.node(gui, "Player"),
		Ui.node(gui, "Coins"),
		Ui.node(gui, "Weather"),
		Ui.node(gui, "Pet"),
		Ui.node(gui, "Quest")
	local coinText, pitonText = coins.Text, coins.Pitons
	-- un colore per riquadro (prima tutti blu scuro uguali): sfumatura leggera sotto la cornice
	for panel, tone in { [me] = Color3.fromRGB(200, 60, 60), [coins] = Color3.fromRGB(225, 165, 40), [pet] = Color3.fromRGB(140, 70, 210), [info] = Color3.fromRGB(50, 140, 220) } do
		Ui.tint(panel, tone, false, 0.03)
		local fill = panel:FindFirstChild("Tinta") :: Frame?
		if fill then
			fill.BackgroundTransparency = 0.45
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
		noticePanel.Position = UDim2.fromScale(goal.X.Scale, goal.Y.Scale - 0.04)
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
		local x, w = if compact then 10 else 16, if compact then 250 else 340
		local y0 = if compact then 8 else 16
		local h
		if compact then
			h = if shieldOn then 96 else 80
			P(me, 0, x, 0, y0, w, h)
			P(Ui.node(me, "Name"), 0, 46, 0, 9, 192, 20)
			P(me.HealthIcon, 0, 14, 0, 32, 24, 24)
			P(me.Health, 0, 46, 0, 34, 192, 20)
			P(me.StaminaIcon, 0, 16, 0, 57, 20, 20)
			P(me.Stamina, 0, 46, 0, 59, 192, 14)
			P(me.Shield, 0, 46, 0, 77, 192, 14)
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
			local ph = if compact then 62 else 98
			P(pet, 0, x, 0, y, w, ph)
			if compact then
				P(pet.Element, 0, 10, 0, 9, 40, 40)
				P(petName, 0, 58, 0, 5, 184, 20)
				P(petLevel, 0, 58, 0, 25, 184, 16)
				P(pet.XP, 0, 58, 0, 43, 180, 13)
			else
				P(pet.Element, 0, 16, 0, 12, 44, 44)
				P(petName, 0, 70, 0, 10, 254, 22)
				P(petLevel, 0, 70, 0, 34, 254, 20)
				P(pet.XP, 0, 18, 0, 64, 304, 22)
			end
			y += ph + 6
		end
		local ch = if compact then 34 else 50
		P(coins, 0, x, 0, y, w, ch)
		if compact then
			P(coins.Icon, 0, 10, 0, 5, 24, 24)
			P(coinText, 0, 40, 0, 0, 112, 34)
			P(coins.PitonIcon, 0, 160, 0, 5, 24, 24)
			P(pitonText, 0, 190, 0, 0, 52, 34)
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
		local k = if compact then 0.8 else 1
		Ui.text(Ui.node(me, "Name"), math.floor(18 * k), true)
		Ui.text(healthText, math.floor(15 * k), true)
		Ui.fit(staminaText, if compact then 11 else 14, 9, true)
		Ui.fit(shieldText, if compact then 11 else 14, 9, true)
		Ui.fit(coinText, math.floor(24 * k), 12, true) -- 9 cifre andavano a capo
		Ui.text(pitonText, math.floor(24 * k), true)
		Ui.text(petName, if compact then 14 else 17, true)
		Ui.text(petLevel, if compact then 12 else 14)
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
	chevron.TextColor3 = Color3.fromRGB(200, 210, 230)
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
			P(info, 1, -10, 0, 8, 190, h, 1, 0)
			P(weatherIcon, 0, 8, 0, 7, 44, 44)
			P(weatherFallback, 0, 8, 0, 7, 44, 44)
			P(timeBig, 0, 58, 0, 5, 120, 26)
			P(clock, 0, 58, 0, 31, 120, 18)
			P(warmthBack, 0, 10, 0, 58, 170, 14)
		elseif folded then
			local h = 84 + (if frozen then 30 else 0)
			P(info, 1, -16, 0, 16, 240, h, 1, 0)
			P(weatherIcon, 0, 12, 0, 13, 58, 58)
			P(weatherFallback, 0, 12, 0, 13, 58, 58)
			P(timeBig, 0, 82, 0, 12, 140, 34)
			P(clock, 0, 82, 0, 48, 140, 20)
			P(warmthBack, 0, 16, 0, 84, 208, 18)
		elseif compact then
			local h = 76 + (if warmthBack.Visible then 22 else 0) + (if finder.Visible then 34 else 0)
			P(info, 1, -10, 0, 8, 226, h, 1, 0)
			P(weatherIcon, 0, 10, 0, 10, 44, 44)
			P(weatherFallback, 0, 10, 0, 10, 44, 44)
			P(timeBig, 0, 62, 0, 6, 142, 26)
			P(clock, 0, 62, 0, 32, 142, 16)
			P(altitude, 0, 62, 0, 50, 142, 18)
			P(warmthBack, 0, 12, 0, 76, 190, 14)
			P(finder, 0, 12, 0, h - 34, 202, 28)
		else
			local h = 122 + (if warmthBack.Visible then 30 else 0) + (if finder.Visible then 42 else 0)
			P(info, 1, -16, 0, 16, 272, h, 1, 0)
			P(weatherIcon, 0, 16, 0, 16, 58, 58)
			P(weatherFallback, 0, 16, 0, 16, 58, 58)
			P(timeBig, 0, 88, 0, 14, 148, 34)
			P(clock, 0, 88, 0, 50, 148, 20)
			P(altitude, 0, 20, 0, 84, 212, 22)
			P(warmthBack, 0, 20, 0, 118, 232, 18)
			P(finder, 0, 20, 0, h - 42, 232, 36)
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
		if compact then
			-- missione sotto la fila delle icone del menu, fra la colonna e il meteo
			local x = 272
			local w = math.clamp(logical.X - x - 234, 260, 470)
			P(quest, 0, x, 0, 82, w, 66)
			P(quest.Icon, 0, 10, 0, 10, 30, 30)
			P(questTitle, 0, 48, 0, 6, w - 170, 20)
			P(skip, 1, -8, 0, 6, 112, 26, 1, 0)
			P(questText, 0, 48, 0, 28, w - 58, 34)
			P(noticePanel, 0, x, 0, 154, w, 46)
			P(noticePanel.Text, 0, 14, 0, 4, w - 28, 38)
			P(hint, 0.5, 0, 1, -150, math.min(560, logical.X - 32), 26, 0.5, 1)
		else
			local portrait = logical.X < 340 + 470 + 252 + 64
			if portrait then
				-- schermo stretto: la missione sotto la colonna di sinistra
				local below = (gui:GetAttribute("LeftBottom") or 300) :: number
				P(quest, 0, 16, 0, below, math.min(470, logical.X - 32), 100)
			else
				P(quest, 0.5, 0, 0, 16, 470, 100, 0.5, 0)
			end
			P(quest.Icon, 0, 16, 0, 16, 40, 40)
			P(questTitle, 0, 66, 0, 12, 250, 24)
			P(skip, 1, -16, 0, 12, 130, 32, 1, 0)
			P(questText, 0, 66, 0, 40, 388, 50)
			P(noticePanel, 0.5, 0, 0, if portrait then 16 else 124, math.min(520, logical.X - 32), 58, 0.5, 0)
			P(noticePanel.Text, 0, 22, 0, 6, math.min(520, logical.X - 32) - 44, 46)
			P(hint, 0.5, 0, 1, -120, math.min(640, logical.X - 32), 32, 0.5, 1)
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
		pet.Visible = d ~= nil
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
			then Color3.fromRGB(120, 200, 110)
			elseif ratio > 0.2 then Color3.fromRGB(230, 190, 70)
			else Color3.fromRGB(220, 70, 60)
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
			then Color3.fromRGB(255, 150, 70)
			else Color3.fromRGB(110, 170, 255)
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
	end)
end

return HUD
