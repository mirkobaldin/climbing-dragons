--!strict
-- Effetti "3D" dell'interfaccia (Mirko 15/10: "cerchi raggianti che girano per dare senso di
-- 3D"): anelli luminosi che ruotano attorno a pulsanti e anteprime, e raggi che girano piano
-- dietro i draghi. Niente immagini: UIStroke + UIGradient che ruota. Un solo ciclo per tutti,
-- salta quelli non visibili (anelli, raggi, fondo scuro con brace e scintille).

local RunService = game:GetService("RunService")

local UiGlow = {}

type Spin = { gradient: UIGradient?, frame: GuiObject?, speed: number, host: GuiObject, base: number }
local spins: { Spin } = {}
local running = false

local function shown(o: GuiObject): boolean
	local cur: Instance? = o
	while cur do
		if cur:IsA("GuiObject") and not cur.Visible then
			return false
		end
		if cur:IsA("ScreenGui") then
			return cur.Enabled
		end
		cur = cur.Parent
	end
	return false
end

local function start()
	if running then
		return
	end
	running = true
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		for i = #spins, 1, -1 do
			local s = spins[i]
			if not s.host.Parent then
				table.remove(spins, i)
			elseif shown(s.host) then
				local a = (s.base + t * s.speed) % 360
				if s.gradient then
					s.gradient.Rotation = a
				end
				if s.frame then
					s.frame.Rotation = a
				end
			end
		end
	end)
end

-- anello luminoso attorno a target (tondo se round): un arco chiaro che gira sul bordo e un
-- alone piu' largo e tenue. Restituisce il riquadro dell'anello (per cambiarne il colore con
-- UiGlow.color o nasconderlo)
function UiGlow.ring(target: GuiObject, color: Color3, opts: { round: boolean?, speed: number?, thickness: number?, pad: number?, halo: boolean? }?): Frame
	local o = opts or {}
	local old = target:FindFirstChild("AnelloLuce")
	if old then
		old:Destroy()
	end
	local pad = o.pad or 4
	local ring = Instance.new("Frame")
	ring.Name = "AnelloLuce"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, pad * 2, 1, pad * 2)
	ring.ZIndex = target.ZIndex + 5
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if o.round == false then UDim.new(0, 14) else UDim.new(0.5, 0)
	corner.Parent = ring
	if o.round ~= false then
		-- tondo vero anche su un pulsante non quadrato (prima veniva una pillola squadrata)
		local square = Instance.new("UIAspectRatioConstraint")
		square.AspectRatio = 1
		square.Parent = ring
	end
	-- arco che gira: colore pieno su un quarto del giro, il resto quasi trasparente
	local arc = Instance.new("UIStroke")
	arc.Name = "Arco"
	arc.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	arc.Thickness = o.thickness or 3
	arc.Color = Color3.new(1, 1, 1)
	arc.Parent = ring
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, color),
	})
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.4, 0.5),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.6, 0.5),
		NumberSequenceKeypoint.new(1, 0.85),
	})
	g.Parent = arc
	-- alone esterno largo e tenue, gira al contrario (sembra profondita')
	local halo = Instance.new("Frame")
	halo.Name = "Alone"
	halo.BackgroundTransparency = 1
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.new(1, 6, 1, 6)
	halo.ZIndex = ring.ZIndex - 1
	local hc = corner:Clone()
	hc.Parent = halo
	local hs = Instance.new("UIStroke")
	hs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hs.Thickness = (o.thickness or 3) + 4
	hs.Color = color
	hs.Transparency = 0.55
	hs.Parent = halo
	local hg = Instance.new("UIGradient")
	hg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	hg.Parent = hs
	halo.Parent = ring
	halo.Visible = o.halo ~= false
	ring.Parent = target
	local speed = o.speed or 120
	table.insert(spins, { gradient = g, frame = nil, speed = speed, host = ring, base = math.random(0, 359) })
	table.insert(spins, { gradient = hg, frame = nil, speed = -speed * 0.6, host = ring, base = 0 })
	start()
	return ring
end

-- colore di un anello gia' fatto (es. grigio durante la ricarica)
function UiGlow.color(ring: Frame?, color: Color3, dim: boolean?)
	if not ring then
		return
	end
	local arc = ring:FindFirstChild("Arco") :: UIStroke?
	local g = arc and arc:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.5, if dim then color else Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, color),
		})
	end
	local halo = ring:FindFirstChild("Alone")
	local hs = halo and halo:FindFirstChildOfClass("UIStroke")
	if hs then
		hs.Color = color
		hs.Enabled = not dim
	end
end

-- raggi che girano piano dietro un'anteprima (drago, uovo): linee sottili che sfumano verso
-- l'esterno, piu' un alone tondo al centro. Vanno sotto il contenuto (ZIndex basso)
function UiGlow.rays(parent: GuiObject, color: Color3, count: number?, speed: number?): Frame
	local old = parent:FindFirstChild("RaggiLuce")
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Frame")
	holder.Name = "RaggiLuce"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.55)
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 0
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = holder
	-- alone tondo al centro
	local glow = Instance.new("Frame")
	glow.Name = "Alone"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.7, 0.7)
	glow.BackgroundColor3 = color
	glow.BorderSizePixel = 0
	glow.ZIndex = 0
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0.5, 0)
	gc.Parent = glow
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	gg.Parent = glow
	glow.Parent = holder
	local n = count or 8
	local sp = speed or 10
	for k = 1, n do
		local line = Instance.new("Frame")
		line.Name = "Raggio"
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.new(1.15, 0, 0, if k % 2 == 0 then 10 else 4)
		line.BackgroundColor3 = color
		line.BorderSizePixel = 0
		line.ZIndex = 0
		local lg = Instance.new("UIGradient")
		lg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.75),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.7, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		})
		lg.Parent = line
		line.Parent = holder
		table.insert(spins, { gradient = nil, frame = line, speed = sp, host = line, base = (k - 1) * 180 / n })
	end
	holder.Parent = parent
	start()
	return holder
end

-- fondo scuro stile menu zombie di Black Ops 2: carbone, fumo che si muove piano, bagliore di
-- brace dal basso e scintille che salgono. Va sotto il contenuto (ZIndex 0)
type Ember = { f: Frame, x: number, y: number, vy: number, drift: number, life: number, age: number }
local emberSets: { { host: GuiObject, list: { Ember } } } = {}
local emberLoop = false

local function respawn(e: Ember)
	e.x = math.random()
	e.y = 1.02
	e.vy = 0.05 + math.random() * 0.09
	e.drift = (math.random() - 0.5) * 0.04
	e.life = 4 + math.random() * 5
	e.age = 0
	local s = math.random(2, 5)
	e.f.Size = UDim2.fromOffset(s, s)
end

function UiGlow.darkBackground(parent: GuiObject, accent: Color3?, embers: number?): Frame
	local old = parent:FindFirstChild("FondoScuro")
	if old then
		old:Destroy()
	end
	local ember = accent or Color3.fromRGB(255, 106, 36)
	local back = Instance.new("Frame")
	back.Name = "FondoScuro"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(11, 17, 31)
	back.BackgroundTransparency = 0.08
	back.BorderSizePixel = 0
	back.ZIndex = 0
	back.ClipsDescendants = true
	local own = parent:FindFirstChildOfClass("UICorner")
	if own then
		own:Clone().Parent = back
	end
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 42, 66)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(15, 22, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 12, 24)),
	})
	g.Parent = back
	-- bagliore di brace dal basso
	local glow = Instance.new("Frame")
	glow.Name = "Brace"
	glow.AnchorPoint = Vector2.new(0.5, 1)
	glow.Position = UDim2.fromScale(0.5, 1.25)
	glow.Size = UDim2.fromScale(1.4, 0.75)
	glow.BackgroundColor3 = ember
	glow.BorderSizePixel = 0
	glow.ZIndex = 0
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0.5, 0)
	gc.Parent = glow
	local gg = Instance.new("UIGradient")
	gg.Rotation = 90
	gg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.78),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	gg.Parent = glow
	glow.Parent = back
	-- due veli di fumo che scorrono lenti
	for k = 1, 2 do
		local smoke = Instance.new("Frame")
		smoke.Name = "Fumo"
		smoke.Size = UDim2.fromScale(2, 0.5)
		smoke.Position = UDim2.fromScale(-0.5, 0.15 + k * 0.25)
		smoke.BackgroundColor3 = Color3.fromRGB(120, 112, 110)
		smoke.BorderSizePixel = 0
		smoke.ZIndex = 0
		local sg = Instance.new("UIGradient")
		sg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.93),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(0.55, 0.9),
			NumberSequenceKeypoint.new(0.75, 1),
			NumberSequenceKeypoint.new(0.9, 0.94),
			NumberSequenceKeypoint.new(1, 1),
		})
		sg.Parent = smoke
		smoke.Parent = back
		-- scorrimento lento avanti e indietro
		task.spawn(function()
			local t = math.random() * 10
			while smoke.Parent do
				t += 1 / 20
				if shown(smoke) then
					sg.Offset = Vector2.new(math.sin(t * 0.08 * k) * 0.25, 0)
				end
				task.wait(1 / 20)
			end
		end)
	end
	local list: { Ember } = {}
	for _ = 1, embers or 18 do
		local f = Instance.new("Frame")
		f.Name = "Scintilla"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = ember:Lerp(Color3.fromRGB(255, 220, 120), math.random() * 0.6)
		f.BorderSizePixel = 0
		f.ZIndex = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		f.Parent = back
		local e: Ember = { f = f, x = 0, y = 0, vy = 0, drift = 0, life = 1, age = 0 }
		respawn(e)
		e.age = math.random() * e.life
		e.y = 1 - e.vy * e.age
		table.insert(list, e)
	end
	table.insert(emberSets, { host = back, list = list })
	back.Parent = parent
	if not emberLoop then
		emberLoop = true
		RunService.RenderStepped:Connect(function(dt)
			for i = #emberSets, 1, -1 do
				local set = emberSets[i]
				if not set.host.Parent then
					table.remove(emberSets, i)
				elseif shown(set.host) then
					for _, e in set.list do
						e.age += dt
						if e.age >= e.life then
							respawn(e)
						end
						e.y -= e.vy * dt
						e.x += e.drift * dt + math.sin(e.age * 2 + e.life) * 0.0015
						local k = e.age / e.life
						e.f.Position = UDim2.fromScale(e.x, e.y)
						e.f.BackgroundTransparency = 0.15 + 0.85 * math.max(k, 1 - math.min(1, e.age * 2))
					end
				end
			end
		end)
	end
	return back
end

return UiGlow
