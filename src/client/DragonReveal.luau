--!strict
-- Momento della ricompensa (Mirko 16/10): quando nasce un drago o si evolve, una schermata breve
-- sopra tutto: attesa (bagliore del colore dell'elemento che pulsa), poi il drago che compare
-- girando, il nome, la rarita', il badge SHINY se lo e', e per l'evoluzione lo stadio nuovo
-- ("ADULT FORM", "RIDING UNLOCKED"). Tocco o CONTINUE per chiudere, si chiude da sola dopo 7 s.
-- Solo grafica: il server resta l'unico che decide (si guardano le differenze in DragonData).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
local DragonConfig = require(Shared:WaitForChild("DragonConfig"))
local Names = require(Shared:WaitForChild("Names"))
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Sfx = require(script.Parent.Sfx)
local DragonUI = require(script.Parent.DragonUI)
local EggHatch = require(script.Parent.EggHatch)

local player = Players.LocalPlayer
local DragonReveal = {}

type Reveal = { kind: string, d: any }

local function decode(): any
	local raw = player:GetAttribute("DragonData")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(data) == "table" then data else nil
end

function DragonReveal.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RivelazioneDrago"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local veil = Instance.new("TextButton") -- tocco ovunque = continua
	veil.Name = "Velo"
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.BackgroundColor3 = UiKit.INK
	veil.BackgroundTransparency = 0.35
	veil.Size = UDim2.fromScale(1, 1)
	veil.Parent = gui
	local panel = Instance.new("Frame")
	panel.Name = "Pannello"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(520, 440)
	panel.Parent = gui
	UiKit.panel(panel, { transparency = 0.15 })
	local fit = Instance.new("UIScale")
	fit.Parent = panel
	local glow = Instance.new("Frame") -- bagliore dell'elemento dietro il drago
	glow.Name = "Bagliore"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.43)
	glow.Size = UDim2.fromOffset(300, 300)
	glow.BackgroundTransparency = 0.7
	glow.BorderSizePixel = 0
	glow.Parent = panel
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0.5, 0)
	gc.Parent = glow
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	gg.Rotation = 90
	gg.Parent = glow
	local stage = Instance.new("Frame")
	stage.Name = "Palco"
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0)
	stage.Position = UDim2.new(0.5, 0, 0, 44)
	stage.Size = UDim2.fromOffset(300, 260)
	stage.Parent = panel
	local head = UiKit.label(panel, "", "section", 18)
	head.TextXAlignment = Enum.TextXAlignment.Center
	head.Position = UDim2.fromOffset(0, 12)
	head.Size = UDim2.new(1, 0, 0, 26)
	head.TextColor3 = UiKit.ACCENT
	local title = UiKit.label(panel, "", "title", 36)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Position = UDim2.fromOffset(0, 300)
	title.Size = UDim2.new(1, 0, 0, 44)
	local sub = UiKit.label(panel, "", "name", 20)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.Position = UDim2.fromOffset(0, 344)
	sub.Size = UDim2.new(1, 0, 0, 28)
	local shiny = Instance.new("TextLabel")
	shiny.Name = "Shiny"
	shiny.AnchorPoint = Vector2.new(1, 0)
	shiny.Position = UDim2.new(1, -16, 0, 50)
	shiny.Size = UDim2.fromOffset(96, 30)
	shiny.Text = "SHINY"
	shiny.BackgroundColor3 = UiKit.ACCENT
	shiny.Parent = panel
	UiKit.text(shiny, "button", 18)
	shiny.TextColor3 = Color3.fromRGB(40, 24, 0)
	local go = Instance.new("TextButton")
	go.AnchorPoint = Vector2.new(0.5, 1)
	go.Position = UDim2.new(0.5, 0, 1, -14)
	go.Size = UDim2.fromOffset(220, 46)
	go.Text = "CONTINUE"
	go.Parent = panel
	UiKit.button(go, "primary")

	local queue: { Reveal } = {}
	local showing = false
	local version = 0
	local showNext: () -> ()

	local function close()
		version += 1
		gui.Enabled = false
		showing = false
		for _, c in stage:GetChildren() do
			c:Destroy()
		end
		if #queue > 0 then
			task.defer(showNext)
		end
	end
	veil.Activated:Connect(close)
	go.Activated:Connect(close)

	showNext = function()
		if showing or #queue == 0 then
			return
		end
		showing = true
		version += 1
		local v = version
		local r = table.remove(queue, 1) :: Reveal
		local d = r.d
		-- schiusa: la sequenza 3D dell'uovo (client/EggHatch); l'evoluzione resta qui sotto
		if r.kind == "hatch" then
			EggHatch.play(d, function()
				showing = false
				if #queue > 0 then
					task.defer(showNext)
				end
			end)
			return
		end
		local el = DragonConfig.element(d.element)
		local tone = if el then el.glow else Theme.ACCENT
		local rarity = Theme.RARITY[d.rarity]
		local cam = workspace.CurrentCamera
		fit.Scale = if cam and cam.ViewportSize.Y < 520 then math.max(0.6, cam.ViewportSize.Y / 520) else 1
		glow.BackgroundColor3 = tone
		gui.Enabled = true
		-- 1) attesa: il bagliore pulsa, il titolo dice cosa sta succedendo
		head.Text = if r.kind == "hatch" then "AN EGG IS HATCHING" else "YOUR DRAGON IS EVOLVING"
		title.Text = ""
		sub.Text = ""
		shiny.Visible = false
		go.Visible = false
		glow.Size = UDim2.fromOffset(120, 120)
		TweenService:Create(glow, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(320, 320) }):Play()
		Sfx.play("CristalloScarica", nil, 1)
		task.delay(0.95, function()
			if version ~= v then
				return
			end
			-- 2) il drago
			local vf = DragonUI.view(stage, d, true)
			vf.AnchorPoint = Vector2.new(0.5, 0.5)
			vf.Position = UDim2.fromScale(0.5, 0.5)
			vf.Size = UDim2.fromScale(0.6, 0.6)
			TweenService:Create(vf, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1.15, 1.15) }):Play()
			Sfx.play("Ruggito", nil, 1)
			local name = if type(d.name) == "string" and d.name ~= "" then d.name else Names.dragon(d.element)
			local st = DragonConfig.STAGES[math.clamp(d.stage or 1, 1, #DragonConfig.STAGES)]
			if r.kind == "hatch" then
				head.Text = "NEW DRAGON"
				title.Text = string.upper(name)
				sub.Text = string.upper(Names.t(d.rarity) .. "  ·  " .. Names.t(d.element))
			else
				head.Text = "EVOLVED"
				title.Text = string.upper(Names.t(st.name) .. " FORM")
				-- l'adulto si puo' cavalcare (con la Sella)
				sub.Text = if (d.stage or 1) >= #DragonConfig.STAGES then "RIDING UNLOCKED" else string.upper(name)
			end
			sub.TextColor3 = if rarity then rarity[1] else UiKit.MUTED
			if d.shiny then
				shiny.Visible = true
				local s = Instance.new("UIScale")
				s.Scale = 1.6
				s.Parent = shiny
				TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				Sfx.play("Stelle", nil, 1)
			end
			go.Visible = true
		end)
		task.delay(7, function()
			if version == v then
				close()
			end
		end)
	end

	-- differenze nei dati dei draghi: id nuovo = schiuso, stadio piu' alto = evoluto
	local known: { [number]: number } = {}
	local ready = false
	local function scan()
		local data = decode()
		if not data then
			return
		end
		local found: { Reveal } = {}
		for _, d in data.dragons or {} do
			local id = tonumber(d.id)
			if id then
				local stageNow = d.stage or 1
				local before = known[id]
				if ready then
					if before == nil then
						table.insert(found, { kind = "hatch", d = d })
					elseif stageNow > before then
						table.insert(found, { kind = "evolve", d = d })
					end
				end
				known[id] = stageNow
			end
		end
		-- tanti draghi "nuovi" insieme = il salvataggio appena caricato, non una schiusa
		if #found <= 2 then
			for _, r in found do
				table.insert(queue, r)
			end
		end
		ready = ready or #(data.dragons or {}) > 0
		showNext()
	end
	player:GetAttributeChangedSignal("DragonData"):Connect(scan)
	scan()
end

return DragonReveal
