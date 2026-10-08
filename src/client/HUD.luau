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
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer

local HUD = {}

local WEATHER_NAMES = { Clear = "Sereno", Cloudy = "Nuvoloso", Rain = "Pioggia", Thunderstorm = "Temporale", Storm = "Tempesta", Snow = "Neve" }

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

local function card(parent: Instance): Frame
	local f = Theme.frame(parent, Theme.BG, 0.3)
	f.AutomaticSize = Enum.AutomaticSize.Y
	Theme.corner(f, 10)
	Theme.stroke(f, Color3.new(1, 1, 1), 1, 0.88)
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

	-- Info (in alto a destra)
	local info = card(gui)
	info.AnchorPoint = Vector2.new(1, 0)
	info.Position = UDim2.new(1, -10, 0, 6)
	info.Size = UDim2.new(0, 200, 0, 0)
	Theme.padding(info, 8)
	Theme.list(info, 4)
	local clock = Theme.label(info, "", 13, Theme.TEXT, true)
	local altitude = Theme.label(info, "", 13, Theme.TEXT, true)
	local warmthBack, warmthFill, warmthText = bar(info, Color3.fromRGB(255, 150, 70), 16)
	local finder = Theme.label(info, "", 12, Theme.ACCENT, true)
	local gearLabel = Theme.label(info, "", 11, Theme.MUTED)

	-- Scheda del giocatore (in alto a sinistra): avatar vero, salute e stamina in piccolo
	local me = card(gui)
	me.Position = UDim2.new(0, 10, 0, 6)
	me.Size = UDim2.new(0, 250, 0, 74)
	me.AutomaticSize = Enum.AutomaticSize.None
	Theme.gradient(me, Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 208, 220))

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
	skip.Text = "Salta il tutorial  ✕"
	skip.Parent = quest
	Theme.corner(skip, 10)
	local armedAt = 0
	skip.Activated:Connect(function()
		if os.clock() - armedAt > 4 then
			armedAt = os.clock()
			skip.Text = "Sicuro? Tocca ancora"
			skip.BackgroundColor3 = Theme.BAD
			task.delay(4, function()
				if os.clock() - armedAt >= 4 then
					skip.Text = "Salta il tutorial  ✕"
					skip.BackgroundColor3 = Theme.ACCENT
				end
			end)
			return
		end
		armedAt = 0
		skip.Text = "Salta il tutorial  ✕"
		skip.BackgroundColor3 = Theme.ACCENT
		local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("SkipTutorial")
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
		staminaText.Text = string.format("%d%%  ·  %d chiodi", math.floor(ratio * 100), player:GetAttribute("Pitons") or 0)

		-- ora, meteo, quota, calore
		local t = Lighting.ClockTime
		clock.Text = string.format(
			"%s %02d:%02d  ·  %s",
			if t >= 6 and t < 19 then "Giorno" else "Notte",
			math.floor(t),
			math.floor((t % 1) * 60),
			WEATHER_NAMES[workspace:GetAttribute("Weather") :: any] or "Sereno"
		)
		local alt = if root then math.max(0, math.floor(root.Position.Y - 20)) else 0
		altitude.Text = string.format("Altitudine  %d m", alt)
		local warmth = (player:GetAttribute("Warmth") or 100) :: number
		warmthBack.Visible = warmth < 99.5 or alt > Gear.COLD_ALTITUDE - 20
		warmthFill.Size = UDim2.new(math.clamp(warmth / 100, 0, 1), 0, 1, 0)
		warmthFill.BackgroundColor3 = if warmth > 40 then Color3.fromRGB(255, 150, 70) else Color3.fromRGB(110, 170, 255)
		warmthText.Text = if warmth <= 0 then "Congelamento!" else string.format("Calore %d%%", math.floor(warmth))

		local carrying = player:GetAttribute("CarryingEgg")
		local finderText = ClientState.eggFinder
		if type(carrying) == "string" then
			finderText = "Porti un uovo " .. (string.gsub(carrying, "|", " ")) .. ": al nido!"
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

		-- tutorial
		local questLine = player:GetAttribute("TutorialText")
		quest.Visible = type(questLine) == "string"
		questText.Text = if type(questLine) == "string" then questLine else ""

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
