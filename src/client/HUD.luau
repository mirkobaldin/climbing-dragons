--!strict
-- HUD, pensato anche per il telefono (niente in basso a sinistra = joystick, niente in basso
-- a destra = salto):
--   in alto a sinistra  scheda del giocatore: avatar, nome, salute, stamina, chiodi
--   sotto               obiettivo del tutorial (con "Salta")
--   in alto al centro   monete
--   in alto a destra    ora e meteo, altimetro, calore, bussola delle uova
--   in basso al centro  suggerimenti e avvisi
-- Il centro dello schermo resta libero: le barre stavano in mezzo e coprivano la parete
-- proprio mentre la si scalava. Niente in basso a sinistra (joystick) ne' a destra (salto).

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

local WEATHER_NAMES = { Clear = "Clear", Cloudy = "Cloudy", Rain = "Rain", Thunderstorm = "Thunderstorm", Storm = "Storm", Snow = "Snow" }

-- Barra con riempimento e testo sopra
local function bar(parent: Instance, color: Color3, height: number): (Frame, Frame, TextLabel)
	local back = Theme.frame(parent, Theme.BG, 0.25)
	back.Size = UDim2.new(1, 0, 0, height)
	Theme.corner(back, height // 2)
	Theme.stroke(back, Color3.new(1, 1, 1), 1, 0.85)
	local fill = Theme.frame(back, color)
	fill.Size = UDim2.fromScale(1, 1)
	Theme.corner(fill, height // 2)
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	shine.Parent = fill
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = math.max(11, height - 6)
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.ZIndex = 3
	text.Parent = back
	return back, fill, text
end

-- scheda: vetro blu notte con sfumatura, bordo chiaro sottile e ombra morbida sotto
local function card(parent: Instance): Frame
	local f = Theme.frame(parent, Color3.new(1, 1, 1), 0.08)
	f.AutomaticSize = Enum.AutomaticSize.Y
	Theme.corner(f, 14)
	Theme.gradient(f, Color3.fromRGB(34, 46, 78), Color3.fromRGB(14, 18, 32), 90)
	Theme.stroke(f, Color3.fromRGB(150, 190, 255), 1.5, 0.6)
	return f
end

function HUD.start()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) -- usiamo la nostra barra
	end)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClimbHUD"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Monete (in alto al centro)
	local coins = card(gui)
	coins.AnchorPoint = Vector2.new(0.5, 0)
	coins.Position = UDim2.new(0.5, 0, 0, 6)
	coins.Size = UDim2.new(0, 150, 0, 34)
	coins.AutomaticSize = Enum.AutomaticSize.None
	-- bordo d'oro: la valuta si riconosce al volo
	local cs = coins:FindFirstChildOfClass("UIStroke")
	if cs then
		cs.Color = Theme.COIN
		cs.Transparency = 0.25
	end
	local coinIcon = Theme.frame(coins, Theme.COIN)
	coinIcon.AnchorPoint = Vector2.new(0, 0.5)
	coinIcon.Position = UDim2.new(0, 8, 0.5, 0)
	coinIcon.Size = UDim2.new(0, 20, 0, 20)
	Theme.corner(coinIcon, 10)
	Theme.stroke(coinIcon, Color3.fromRGB(180, 120, 0), 2, 0)
	local coinText = Theme.label(coins, "0", 18, Theme.COIN, true)
	coinText.Position = UDim2.new(0, 36, 0, 0)
	coinText.Size = UDim2.new(1, -42, 1, 0)
	coinText.TextXAlignment = Enum.TextXAlignment.Left

	-- Meteo (in alto a destra): icona grande del tempo, ora, quota, temperatura. Il fondo cambia
	-- colore col giorno, la notte e la tempesta
	local info = card(gui)
	info.AnchorPoint = Vector2.new(1, 0)
	info.Position = UDim2.new(1, -10, 0, 6)
	info.Size = UDim2.new(0, 220, 0, 0)
	Theme.padding(info, 10)
	Theme.list(info, 6)
	local sky = info:FindFirstChildOfClass("UIGradient") :: UIGradient
	local headRow = Theme.frame(info, nil, 1)
	headRow.Size = UDim2.new(1, 0, 0, 40)
	local weatherIcon = Theme.label(headRow, "☀️", 32, Theme.TEXT, true)
	weatherIcon.Size = UDim2.new(0, 42, 1, 0)
	weatherIcon.TextXAlignment = Enum.TextXAlignment.Center
	local timeBig = Theme.label(headRow, "12:00", 24, Theme.TEXT, true)
	timeBig.Font = Enum.Font.GothamBlack
	timeBig.Position = UDim2.new(0, 48, 0, -2)
	timeBig.Size = UDim2.new(1, -48, 0, 26)
	local clock = Theme.label(headRow, "", 12, Color3.fromRGB(190, 210, 240), true)
	clock.Position = UDim2.new(0, 48, 0, 24)
	clock.Size = UDim2.new(1, -48, 0, 16)
	local altitude = Theme.label(info, "", 14, Theme.TEXT, true)
	local warmthBack, warmthFill, warmthText = bar(info, Color3.fromRGB(255, 150, 70), 18)
	local finder = Theme.label(info, "", 12, Theme.ACCENT, true)
	local gearLabel = Theme.label(info, "", 11, Theme.MUTED)

	-- Scheda del giocatore (in alto a sinistra): avatar vero, salute e stamina in piccolo
	local me = card(gui)
	me.Position = UDim2.new(0, 10, 0, 6)
	me.Size = UDim2.new(0, 250, 0, 74)
	me.AutomaticSize = Enum.AutomaticSize.None

	local avatar = Instance.new("ImageLabel")
	avatar.AnchorPoint = Vector2.new(0, 0.5)
	avatar.Position = UDim2.new(0, 9, 0.5, 0)
	avatar.Size = UDim2.new(0, 56, 0, 56)
	avatar.BackgroundColor3 = Theme.CARD
	avatar.BorderSizePixel = 0
	avatar.Parent = me
	Theme.corner(avatar, 28)
	Theme.stroke(avatar, Theme.ACCENT, 2, 0.35)
	-- l'immagine del profilo arriva da Roblox, non e' un'icona scaricata
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then
			avatar.Image = url
		end
	end)

	local stack = Theme.frame(me, nil, 1)
	stack.Position = UDim2.new(0, 74, 0, 8)
	stack.Size = UDim2.new(1, -84, 1, -16)
	Theme.list(stack, 3)
	local nameLabel = Theme.label(stack, player.DisplayName, 13, Theme.TEXT, true)
	nameLabel.Size = UDim2.new(1, 0, 0, 16)
	local _, healthFill, healthText = bar(stack, Color3.fromRGB(220, 60, 60), 16)
	local staminaBack, staminaFill, staminaText = bar(stack, Color3.fromRGB(120, 200, 110), 14)
	-- scudo di ghiaccio (potenziamento): compare quando ce l'hai e la scheda si allunga
	local shieldBack, shieldFill, shieldText = bar(stack, Color3.fromRGB(120, 200, 255), 12)
	shieldBack.Visible = false

	-- Statistiche del drago al seguito, sempre a schermo sotto la scheda del giocatore (spostata a
	-- destra della colonna dei pulsanti, che sul telefono sale fin qui)
	local pet = card(gui)
	pet.Position = UDim2.new(0, 88, 0, 86)
	local function shieldLayout(on: boolean)
		shieldBack.Visible = on
		me.Size = UDim2.new(0, 250, 0, if on then 90 else 74)
		pet.Position = UDim2.new(0, 88, 0, if on then 102 else 86)
	end
	pet.Size = UDim2.new(0, 172, 0, 0)
	pet.Visible = false
	Theme.padding(pet, 8)
	Theme.list(pet, 3)
	local petName = Theme.label(pet, "", 13, Theme.TEXT, true)
	petName.RichText = true
	petName.Size = UDim2.new(1, 0, 0, 16)
	local petLevel = Theme.label(pet, "", 11, Theme.MUTED, true)
	petLevel.Size = UDim2.new(1, 0, 0, 14)
	local _, petXpFill, petXpText = bar(pet, Color3.fromRGB(110, 200, 255), 13)
	local petStats = Theme.label(pet, "", 11, Theme.TEXT)
	petStats.RichText = true
	petStats.Size = UDim2.new(1, 0, 0, 14)
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
		local lv = d.level or 1
		local need = DragonConfig.xpForLevel(lv)
		local stage = DragonConfig.STAGES[math.clamp(d.stage or 1, 1, #DragonConfig.STAGES)]
		local stageName = Names.t(stage.name)
		petName.Text = string.format("%s <font color=\"#ffc86a\">%s</font>", Names.t(d.element), Names.t(d.rarity))
		petLevel.Text = string.format("Lv %d · %s", lv, stageName)
		petXpFill.Size = UDim2.fromScale(math.clamp((d.xp or 0) / need, 0, 1), 1)
		petXpText.Text = string.format("%d / %d XP", math.floor(d.xp or 0), need)
		petStats.Text = string.format("ATK <b>%.1f</b> · Evo <b>%d%%</b>", 8 + 0.15 * lv, math.floor(math.clamp(lv / 100, 0, 1) * 100))
	end
	player:GetAttributeChangedSignal("DragonData"):Connect(refreshPet)
	refreshPet()

	-- Tutorial (sotto la scheda del giocatore)
	local quest = card(gui)
	quest.AnchorPoint = Vector2.new(0.5, 0)
	quest.Position = UDim2.new(0.5, 0, 0, 62) -- in alto al centro, sotto le monete: non copre le icone
	quest.Size = UDim2.new(0, 300, 0, 0)
	quest.Visible = false
	Theme.padding(quest, 10)
	Theme.list(quest, 4)
	local questTitle = Theme.label(quest, "Tutorial", 14, Theme.ACCENT, true)
	questTitle.LayoutOrder = 1
	local questText = Theme.label(quest, "", 14, Theme.TEXT)
	questText.LayoutOrder = 2
	questText.AutomaticSize = Enum.AutomaticSize.Y
	questText.Size = UDim2.new(1, 0, 0, 0)
	local skip = Instance.new("TextButton")
	skip.LayoutOrder = 3
	-- ben visibile (prima era grigio su grigio e nessuno lo trovava), con conferma: il primo
	-- tocco chiede "sicuro?", il secondo entro 4 secondi salta davvero
	skip.Size = UDim2.new(0, 170, 0, 36)
	skip.BackgroundColor3 = Theme.ACCENT
	skip.Font = Enum.Font.GothamBold
	skip.TextSize = 14
	skip.TextColor3 = Theme.BG
	skip.Text = "Skip tutorial"
	skip.Parent = quest
	Theme.corner(skip, 10)
	local armedAt = 0
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
		armedAt = 0
		skip.Text = "Skip tutorial"
		skip.BackgroundColor3 = Theme.ACCENT
		-- durante le missioni il pulsante salta la missione, non il tutorial
		local name = if player:GetAttribute("TutorialText") then "SkipTutorial" else "SkipMission"
		local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild(name)
		if remote then
			(remote :: RemoteEvent):FireServer()
		end
	end)

	local hint = Theme.label(gui, "", 16, Color3.fromRGB(255, 236, 190), true)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -120)
	hint.Size = UDim2.new(0.8, 0, 0, 44)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextYAlignment = Enum.TextYAlignment.Bottom
	hint.TextStrokeTransparency = 0.3

	local lastHint, hintTime = "", 0
	local lastNotice: any = nil
	local shownHealth = 1

	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

		coinText.Text = tostring(player:GetAttribute("Coins") or 0)

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
		staminaText.Text = string.format("%d%%  ·  %d pitons", math.floor(ratio * 100), player:GetAttribute("Pitons") or 0)
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
		local ICON = { Clear = if day then "☀️" else "🌙", Cloudy = "☁️", Rain = "🌧️", Thunderstorm = "⛈️", Storm = "🌪️", Snow = "❄️" }
		weatherIcon.Text = ICON[w] or (if day then "☀️" else "🌙")
		timeBig.Text = string.format("%02d:%02d", math.floor(t), math.floor((t % 1) * 60))
		clock.Text = string.format("%s  ·  %s", if day then "Day" else "Night", WEATHER_NAMES[w] or "Clear")
		-- fondo: azzurro di giorno, blu notte, grigio-viola in tempesta
		if sky then
			local top = if w == "Storm" or w == "Thunderstorm" then Color3.fromRGB(70, 60, 100) elseif day then Color3.fromRGB(46, 96, 160) else Color3.fromRGB(26, 30, 70)
			sky.Color = ColorSequence.new(top, Color3.fromRGB(14, 18, 32))
		end
		local alt = if root then math.max(0, math.floor(root.Position.Y - 20)) else 0
		altitude.Text = string.format("⛰️  %d m", alt)
		local warmth = (player:GetAttribute("Warmth") or 100) :: number
		warmthBack.Visible = warmth < 99.5 or alt > Gear.COLD_ALTITUDE - 20
		warmthFill.Size = UDim2.new(math.clamp(warmth / 100, 0, 1), 0, 1, 0)
		warmthFill.BackgroundColor3 = if warmth > 40 then Color3.fromRGB(255, 150, 70) else Color3.fromRGB(110, 170, 255)
		warmthText.Text = if warmth <= 0 then "🥶 Freezing!" else string.format("🌡️ Warmth %d%%", math.floor(warmth))

		local carrying = player:GetAttribute("CarryingEgg")
		local finderText = ClientState.eggFinder
		if type(carrying) == "string" then
			local parts = string.split(carrying, "|")
			finderText = string.format("Carrying an egg (%s %s): take it to your nest!", Names.t(parts[2]), Names.t(parts[1]))
		end
		finder.Visible = finderText ~= nil
		finder.Text = finderText or ""
		local owned = {}
		for _, recipe in Gear.RECIPES do
			if Gear.has(player, recipe.id) then
				table.insert(owned, recipe.name)
			end
		end
		gearLabel.Visible = #owned > 0
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
		if (ClientState :: any).dragonMode and type(ClientState.hint) == "string" and not string.find(ClientState.hint :: string, "XP", 1, true) then
			ClientState.hint = ""
		end
		if ClientState.hint ~= lastHint then
			lastHint = ClientState.hint
			hintTime = os.clock()
		end
		hint.Text = if os.clock() - hintTime < 4 then lastHint else ""
	end)
end

return HUD
