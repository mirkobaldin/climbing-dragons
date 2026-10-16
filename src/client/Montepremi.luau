--!strict
-- Montepremi stile Squid Game in alto al centro dello schermo (nella fila della barra di Roblox):
-- "PRIZE POOL" rosa e il numero dorato che scorre quando sale, piu' il messaggio dell'ultimo
-- evento ("+50  Mario fell", "Luca reached the summit and won 2,350!") che scende e sparisce.
-- I valori arrivano dagli attributi del Workspace (server/Montepremi).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)

local Theme = require(script.Parent.Theme)
local Slant = require(script.Parent.Slant)
local Cornici = require(script.Parent.Cornici)
local Ui = require(game:GetService("ReplicatedStorage").Shared.UiView)
local Montepremi = {}

local GOLD = Theme.ACCENT
local PINK = Theme.BAD

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function Montepremi.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Montepremi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- sta nella fila della barra di Roblox, al centro (libero)
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	-- striscia in alto al centro (schizzo di Mirko 15/10): monete | montepremi | pietre del drago
	local strip = Instance.new("Frame")
	strip.Name = "Striscia"
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.new(0.5, 0, 0, 4)
	strip.Size = UDim2.fromOffset(600, 40)
	strip.Parent = gui
	local function side(x: number, anchor: number, slantSide: string, icon: string, color: Color3): (Frame, TextLabel)
		local f = Slant.new(strip, Theme.DARK, 0.12, 18, slantSide)
		f.AnchorPoint = Vector2.new(anchor, 0.5)
		f.Position = UDim2.new(x, 0, 0.5, 0)
		f.Size = UDim2.fromOffset(160, 32)
		-- contatore di Codex (ferro e oro con le punte ai lati) al posto del parallelogramma
		local framed = Cornici.apply(f, "frame_currency_counter", { fill = Theme.DARK, fillTransparency = 0.12 }) ~= nil
		if framed then
			Slant.paint(f, Theme.DARK, 1)
		end
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0, 0.5)
		img.Position = UDim2.new(0, if framed then 16 elseif slantSide == "left" then 24 else 8, 0.5, 0)
		img.Size = UDim2.fromOffset(24, 24)
		img.ZIndex = 3
		img.Parent = f
		if not Ui.asset(img, icon) then
			-- pietra del drago senza immagine: un rombo del suo colore
			img.Visible = true
			img.Image = ""
			img.BackgroundTransparency = 0
			img.BackgroundColor3 = color
			img.Rotation = 45
			img.Size = UDim2.fromOffset(16, 16)
			img.Position = UDim2.new(0, if slantSide == "left" then 28 else 12, 0.5, 0)
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 3)
			c.Parent = img
		end
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(if framed then 44 elseif slantSide == "left" then 54 else 38, 0)
		l.Size = UDim2.new(1, if framed then -60 else -72, 1, 0)
		l.Font = Enum.Font.GothamBlack
		l.TextSize = 18
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.3
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = "0"
		l.ZIndex = 3
		l.Parent = f
		return f, l
	end
	local _, coinsText = side(0, 0, "left", "icon_coin", GOLD)
	local _, stonesText = side(1, 1, "right", "icon_stone", Theme.PURPLE)
	local box = Instance.new("Frame")
	box.Name = "Riquadro"
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 0)
	box.Size = UDim2.fromOffset(260, 40)
	box.BackgroundColor3 = Theme.DARK
	box.BackgroundTransparency = 0.08
	box.Parent = strip
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Color = PINK
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke:SetAttribute("KeepStroke", true)
	stroke.Parent = box
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(10, 4)
	title.Size = UDim2.new(0, 104, 1, -8)
	title.Font = Enum.Font.Arcade
	title.TextScaled = true
	title.TextWrapped = true
	title.TextColor3 = PINK
	title.Text = "PRIZE POOL"
	title.Parent = box
	local num = Instance.new("TextLabel")
	num.BackgroundTransparency = 1
	num.Position = UDim2.fromOffset(118, 4)
	num.Size = UDim2.new(1, -128, 1, -8)
	num.Font = Enum.Font.Arcade
	num.TextScaled = true
	num.TextColor3 = GOLD
	num.TextXAlignment = Enum.TextXAlignment.Right
	num.Text = "0"
	num.Parent = box
	local function counters()
		coinsText.Text = fmt((player:GetAttribute("Coins") or 0) :: number)
		local stones = 0
		local raw = player:GetAttribute("DragonData")
		if type(raw) == "string" then
			local ok, data = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), raw)
			if ok and type(data) == "table" then
				stones = tonumber(data.stones) or 0
			end
		end
		stonesText.Text = fmt(stones)
	end
	player:GetAttributeChangedSignal("Coins"):Connect(counters)
	player:GetAttributeChangedSignal("DragonData"):Connect(counters)
	counters()
	local scale = Instance.new("UIScale")
	scale.Parent = box
	local fit = Instance.new("UIScale") -- telefono: striscia piu' piccola
	fit.Parent = strip

	local pop = Instance.new("TextLabel")
	pop.Name = "Evento"
	pop.AnchorPoint = Vector2.new(0.5, 0)
	pop.BackgroundTransparency = 1
	pop.Position = UDim2.new(0.5, 0, 0, 58)
	pop.Size = UDim2.fromOffset(420, 26)
	pop.Font = Enum.Font.GothamBlack
	pop.TextSize = 18
	pop.TextColor3 = GOLD
	pop.TextStrokeTransparency = 0.2
	pop.TextTransparency = 1
	pop.TextStrokeColor3 = Color3.new(0, 0, 0)
	pop.Parent = gui
	Theme.fitText(title, 12, false)
	Theme.fitText(num, 18, false)
	Theme.fitText(pop, 16, true)
	local popY = 220
	Ui.viewportChanged(function(vp)
		popY = Ui.menuMetrics(vp).y + 144
		fit.Scale = if Ui.compact(vp) then 0.75 else 1
		pop.Size = UDim2.fromOffset(math.min(420, vp.X - 24), 48)
	end)

	-- il numero scorre fino al valore nuovo (come un contatore)
	local shown = (workspace:GetAttribute("Montepremi") or 0) :: number
	local target = shown
	num.Text = fmt(shown)
	workspace:GetAttributeChangedSignal("Montepremi"):Connect(function()
		local v = (workspace:GetAttribute("Montepremi") or 0) :: number
		local up = v > target
		target = v
		if up then
			scale.Scale = 1.15
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			stroke.Color = GOLD
			TweenService:Create(stroke, TweenInfo.new(0.8), { Color = PINK }):Play()
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local pg = player.PlayerGui
		local menu = pg:FindFirstChild("MainMenu")
		local travel = pg:FindFirstChild("Teletrasporto")
		local travelPanel = travel and travel:FindFirstChild("Panel") :: GuiObject?
		local death = pg:FindFirstChild("DeathScreen")
		gui.Enabled = not ((menu and menu:GetAttribute("MenuOpen") == true) or (travelPanel and travelPanel.Visible)
			or player:GetAttribute("HudNascosto") == true or (death and death:IsA("ScreenGui") and death.Enabled) or player:GetAttribute("SchiusaInCorso") == true)
		if math.abs(target - shown) < 0.5 then
			if shown ~= target then
				shown = target
				num.Text = fmt(shown)
			end
			return
		end
		shown += (target - shown) * math.min(1, dt * 5)
		num.Text = fmt(shown + (if target > shown then 0.5 else -0.5))
	end)
	-- ultimo evento: scende sotto il riquadro e sparisce dopo 4 s
	local version = 0
	workspace:GetAttributeChangedSignal("MontepremiT"):Connect(function()
		local text = workspace:GetAttribute("MontepremiTesto")
		if type(text) ~= "string" then
			return
		end
		version += 1
		local mine = version
		pop.Text = text
		pop.Position = UDim2.new(0.5, 0, 0, popY)
		pop.TextTransparency = 0
		pop.TextStrokeTransparency = 0.2
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, 0, 0, popY) }):Play()
		if string.find(text, "won") then
			Sfx.play("Ruggito", nil, 1.2)
		end
		task.delay(4, function()
			if version == mine then
				TweenService:Create(pop, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end)
end

return Montepremi
