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
	local function layoutPlayer()
		local h = if shieldOn then 132 else 114
		P(me, 0, 16, 0, 16, 340, h)
		P(Ui.node(me, "Name"), 0, 62, 0, 14, 262, 22)
		P(me.HealthIcon, 0, 22, 0, 42, 30, 30)
		P(me.Health, 0, 62, 0, 44, 258, 26)
		P(me.StaminaIcon, 0, 24, 0, 76, 26, 26)
		P(me.Stamina, 0, 62, 0, 78, 258, 20)
		P(me.Shield, 0, 62, 0, 104, 258, 14)
		local y = 16 + h + 8
		P(coins, 0, 16, 0, y, 340, 50)
		P(pet, 0, 16, 0, y + 58, 340, 96)
		gui:SetAttribute("LeftBottom", y + 58 + (if pet.Visible then 96 else 0) + 10)
	end
	shieldLayout = function(on: boolean)
		shieldOn = on
		shieldBack.Visible = on
		layoutPlayer()
	end
	-- testi: grandi e dentro i riquadri
	Ui.text(Ui.node(me, "Name"), 18, true)
	Ui.text(healthText, 15, true)
	Ui.text(staminaText, 13, true)
	Ui.text(shieldText, 10, true)
	Ui.text(coinText, 24, true)
	Ui.text(pitonText, 24, true)
	P(coins.Icon, 0, 14, 0, 8, 34, 34)
	P(coinText, 0, 56, 0, 0, 120, 50)
	P(coins.PitonIcon, 0, 186, 0, 8, 34, 34)
	P(pitonText, 0, 226, 0, 0, 100, 50)
	Ui.text(petName, 17, true)
	Ui.text(petLevel, 14)
	Ui.text(petXpText, 12, true)
	petStats.Visible = false -- l'attacco va nella riga del livello
	P(pet.Element, 0, 16, 0, 12, 44, 44)
	P(petName, 0, 70, 0, 10, 254, 22)
	P(petLevel, 0, 70, 0, 34, 254, 20)
	P(pet.XP, 0, 18, 0, 62, 304, 18)
	Ui.text(weatherFallback, 30)
	Ui.text(timeBig, 32, true)
	Ui.text(clock, 16)
	Ui.text(altitude, 17, true)
	Ui.text(warmthText, 13, true)
	Ui.text(finder, 13, true)
	gearLabel.Visible = false -- l'elenco degli attrezzi era illeggibile: sta nello zaino
	for _, l in { timeBig, clock, altitude } do
		(l :: TextLabel).TextXAlignment = Enum.TextXAlignment.Left
	end
	Ui.text(questTitle, 19, true)
	Ui.text(questText, 15)
	Ui.text(skip, 13, true)
	Ui.text(noticePanel.Text, 17, true)
	Ui.text(hint, 19, true)
	local function layoutWeather()
		local h = if finder.Visible then 186 else 148
		P(info, 1, -16, 0, 16, 252, h, 1, 0)
		P(weatherIcon, 0, 16, 0, 16, 58, 58)
		P(weatherFallback, 0, 16, 0, 16, 58, 58)
		P(timeBig, 0, 88, 0, 14, 148, 34)
		P(clock, 0, 88, 0, 50, 148, 20)
		P(altitude, 0, 20, 0, 84, 212, 22)
		P(warmthBack, 0, 20, 0, 114, 212, 18)
		P(finder, 0, 20, 0, 140, 212, 36)
	end
	finder:GetPropertyChangedSignal("Visible"):Connect(layoutWeather)
	Ui.viewportChanged(function(vp)
		local logical = Ui.fitScale(gui, vp)
		local portrait = logical.X < 340 + 470 + 252 + 64
		layoutPlayer()
		layoutWeather()
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
		noticePosition = noticePanel.Position
		P(noticePanel.Text, 0, 22, 0, 6, math.min(520, logical.X - 32) - 44, 46)
		P(hint, 0.5, 0, 1, -120, math.min(640, logical.X - 32), 32, 0.5, 1)
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
		petLevel.Text = string.format("Lv %d · %s · ATK %.1f", lv, stageName, 8 + 0.15 * lv)
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
		warmthBack.Visible = warmth < 99.5 or alt > Gear.COLD_ALTITUDE - 20
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
		finder.Visible = finderText ~= nil
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
		quest.Visible = type(questLine) == "string"
		questText.Text = if type(questLine) == "string" then questLine else ""
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
