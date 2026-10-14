--!strict
-- Scene delle clip nuove (comandi admin clip21 ... clip25, girate da client/ClipNuove).
-- Il server mette in Workspace.ClipProps i modelli che il client non vede (draghi adulti, uova in
-- ServerStorage) e calcola i punti della montagna che servono (bordo di una parete a strapiombo,
-- discesa dalla vetta al campo base), negli attributi della cartella.
--   clip21  "rate every dragon": gli 8 adulti in fila davanti a te
--   clip22  "the summit had a guardian": il Guardiano che atterra davanti allo scalatore in vetta
--   clip23  "1 IQ vs 200 IQ": caduta da una parete vera, poi la stessa caduta salvata dal rampino
--   clip24  "shiny hatch": l'uovo che si schiude e il cucciolo SHINY
--   clip25  "4000 m descent": parapendio dalla vetta al campo base
--   clip26  "from baby to beast": il drago giovane si evolve in adulto, ci sali sul collo, volo sui
--           posti piu' belli (borgo, cascate, isole dei cristalli, isole della vetta) e duello con
--           un drago selvatico sopra la vetta

local ServerStorage = game:GetService("ServerStorage")

local DragonModels = require(script.Parent.DragonModels)

local ClipProps = {}

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function groundY(x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, 5200, z), Vector3.new(0, -6000, 0), terrainOnly)
	return hit and hit.Position.Y
end

local function marker(name: string): Vector3?
	local markers = workspace:FindFirstChild("MapMarkers")
	local m = markers and markers:FindFirstChild(name, true)
	return if m and m:IsA("BasePart") then m.Position else nil
end

local function still(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("LuaSourceContainer") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end

local function adult(element: string): Model?
	local store = ServerStorage:FindFirstChild("Draghi")
	local t = store and store:FindFirstChild("Drago_" .. element .. "_Adulto")
	if not t or not t:IsA("Model") then
		return nil
	end
	local m = t:Clone()
	still(m)
	m:SetAttribute("AnimKey", t.Name)
	m:SetAttribute("AnimBaseScale", t:GetScale()) -- grande come il rig (client/KfsPlayer)
	return m
end

-- bordo di una parete a strapiombo sulla montagna: dove il terreno scende di piu' in pochi passi
local function findCliff(): (Vector3?, Vector3?)
	local summit = marker("Summit")
	if not summit then
		return nil, nil
	end
	local best, bestDrop, bestDir = nil, 0, nil
	for r = 400, 1400, 200 do
		for k = 0, 23 do
			local a = k / 24 * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local p = summit + dir * r
			local top = groundY(p.X, p.Z)
			local q = p + dir * 50
			local low = groundY(q.X, q.Z)
			if top and low and top - low > bestDrop then
				best, bestDrop, bestDir = Vector3.new(p.X, top, p.Z), top - low, dir
			end
		end
	end
	return best, bestDir
end

function ClipProps.prepare(kind: string, player: Player): string?
	local old = workspace:FindFirstChild("ClipProps")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "ClipProps"
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if kind == "clip21" then
		if not root then
			return "Serve il personaggio"
		end
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		local side = look:Cross(Vector3.yAxis)
		local order = { "Gelo", "Roccia", "Ossa", "Gas", "Tempesta", "Cosmico", "FulmineNero", "Eclissi" }
		for k, el in order do
			local m = adult(el)
			if m then
				local at = root.Position + look * 80 + side * ((k - 4.5) * 75)
				local y = groundY(at.X, at.Z) or at.Y
				local _, size = m:GetBoundingBox()
				local base = Vector3.new(at.X, y + size.Y / 2, at.Z)
				m:PivotTo(CFrame.lookAt(base, base - look))
				m:SetAttribute("Order", k)
				m.Parent = folder
			end
		end
	elseif kind == "clip22" then
		local summit = marker("Summit")
		local m = adult("Eclissi")
		if not summit or not m then
			return "Manca la vetta o il drago Eclissi adulto"
		end
		m:ScaleTo(m:GetScale() * 1.6)
		m.Name = "Guardiano"
		m:PivotTo(CFrame.new(summit + Vector3.new(0, -800, 0)))
		m.Parent = folder
		local top = groundY(summit.X, summit.Z) or summit.Y
		folder:SetAttribute("Summit", Vector3.new(summit.X, top, summit.Z))
		-- il bordo dello spiazzo verso la valle (fuori dal santuario): dove il terreno inizia a scendere
		local hub = marker("HubSpawn") or (summit + Vector3.xAxis)
		local dir = Vector3.new(hub.X - summit.X, 0, hub.Z - summit.Z).Unit
		local edge = summit
		for d = 10, 300, 4 do
			local p = summit + dir * d
			local y = groundY(p.X, p.Z)
			if y and y < top - 10 then
				break
			end
			edge = Vector3.new(p.X, y or top, p.Z)
		end
		folder:SetAttribute("Edge", edge)
		folder:SetAttribute("Dir", dir)
	elseif kind == "clip23" then
		local top, dir = findCliff()
		if not top or not dir then
			return "Nessuna parete trovata"
		end
		folder:SetAttribute("CliffTop", top)
		folder:SetAttribute("CliffDir", dir)
		local bottom = top + dir * 30
		folder:SetAttribute("CliffBottom", Vector3.new(bottom.X, groundY(bottom.X, bottom.Z) or (top.Y - 200), bottom.Z))
	elseif kind == "clip24" then
		if not root then
			return "Serve il personaggio"
		end
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		local at = root.Position + look * 12
		local y = groundY(at.X, at.Z) or at.Y
		local ok, egg = pcall(DragonModels.egg, "Cosmico", "Leggendario")
		if ok and egg then
			still(egg)
			egg.Name = "Uovo"
			local _, s = egg:GetBoundingBox()
			egg:PivotTo(CFrame.new(at.X, y + s.Y / 2, at.Z))
			egg.Parent = folder
		end
		local ok2, cub = pcall(DragonModels.dragon, "Cosmico", "Leggendario", 1, 1)
		if ok2 and cub then
			still(cub)
			cub.Name = "Cucciolo"
			cub:SetAttribute("Shiny", true)
			cub:PivotTo(CFrame.new(at.X, y - 400, at.Z))
			cub.Parent = folder
		end
		folder:SetAttribute("Spot", Vector3.new(at.X, y, at.Z))
		folder:SetAttribute("Look", -look)
	elseif kind == "clip25" then
		local summit = marker("Summit")
		local hub = marker("HubSpawn")
		if not summit or not hub then
			return "Manca la vetta o il campo base"
		end
		-- la planata: dritta verso il campo, sempre 30-60 studs sopra il terreno
		local N = 24
		for k = 0, N do
			local u = k / N
			local p = summit:Lerp(hub, u)
			local g = groundY(p.X, p.Z) or p.Y
			local glideY = summit.Y + 30 - (summit.Y - hub.Y) * (u ^ 0.8)
			folder:SetAttribute("P" .. k, Vector3.new(p.X, math.max(g + 35, glideY), p.Z))
		end
		folder:SetAttribute("Points", N)
	elseif kind == "clip26" then
		local summit = marker("Summit")
		local hub = marker("HubSpawn")
		if not summit or not hub then
			return "Manca la vetta o il campo base"
		end
		-- i tre draghi: il tuo giovane e il tuo adulto (Tempesta), il rivale (Fulmine Nero)
		local function make(element: string, stage: number, name: string): Model?
			local ok, m = pcall(DragonModels.dragon, element, "Leggendario", stage, 50)
			if not ok or not m then
				return nil
			end
			still(m)
			m.Name = name
			m:PivotTo(CFrame.new(hub + Vector3.new(0, -600, 0)))
			m.Parent = folder
			return m
		end
		make("Tempesta", 2, "Giovane")
		make("Tempesta", 3, "Adulto")
		local rival = make("Fulmine", 3, "Rivale")
		if rival then
			rival:ScaleTo(rival:GetScale() * 1.15)
		end
		-- l'evoluzione: davanti alle costole del drago gigante (fanno da sfondo)
		local landmarks = workspace:FindFirstChild("Landmarks")
		local ribs = landmarks and landmarks:FindFirstChild("DragonRibs")
		local base = if ribs and ribs:IsA("Model") then ribs:GetPivot().Position else hub
		local toHub = Vector3.new(hub.X - base.X, 0, hub.Z - base.Z)
		toHub = if toHub.Magnitude > 1 then toHub.Unit else Vector3.xAxis
		local spot = base + toHub * 320 -- fuori dal portale dell'arena (a 170 si stava fra i muri)
		folder:SetAttribute("Spot", Vector3.new(spot.X, groundY(spot.X, spot.Z) or spot.Y, spot.Z))
		folder:SetAttribute("Look", toHub) -- il drago guarda la piana, dietro di lui le costole
		-- i tratti di volo (A -> B), sempre ben sopra il terreno
		local function air(p: Vector3, clear: number): Vector3
			local g = groundY(p.X, p.Z) or p.Y
			return Vector3.new(p.X, math.max(p.Y, g + clear), p.Z)
		end
		local segs = {}
		local borghi = workspace:FindFirstChild("Borghi")
		local village = borghi and (borghi:FindFirstChild("MISTY TERRACES") or borghi:FindFirstChild("RIVERBEND"))
		local vm = village and village:FindFirstChildWhichIsA("Model", true)
		if vm then
			local v = vm:GetPivot().Position
			table.insert(segs, { air(v + Vector3.new(-170, 30, -90), 38), air(v + Vector3.new(150, 40, 80), 38) })
		end
		local falls = workspace:FindFirstChild("MapMarkers") and (workspace :: any).MapMarkers:FindFirstChild("Waterfalls")
		if falls then
			local lo, hi
			for _, w in falls:GetChildren() do
				if w:IsA("BasePart") then
					if not lo or w.Position.Y < lo.Y then
						lo = w.Position
					end
					if not hi or w.Position.Y > hi.Y then
						hi = w.Position
					end
				end
			end
			if lo and hi then
				-- risale la cascata un po' di lato, dal fondo alla cima
				local out = Vector3.new(lo.X - 1300, 0, lo.Z).Unit
				table.insert(segs, { air(lo + out * 70 - Vector3.new(0, 20, 0), 25), air(hi + out * 60 + Vector3.new(0, 40, 0), 25) })
			end
		end
		local isles = workspace:FindFirstChild("IsoleVolanti")
		local storm = isles and isles:FindFirstChild("STORM RIDGE")
		if storm then
			local pts = {}
			for _, c in storm:GetChildren() do
				if c:IsA("Model") and string.find(c.Name, "Isola") then
					table.insert(pts, c:GetPivot().Position)
				end
			end
			if #pts >= 2 then
				table.insert(segs, { pts[1] + (pts[1] - pts[2]).Unit * 90 + Vector3.new(0, 15, 0), pts[2] + (pts[2] - pts[1]).Unit * 90 + Vector3.new(0, 25, 0) })
			end
		end
		-- l'ultimo tratto: tra le isole sopra la vetta, fino al punto del duello
		local dir = Vector3.new(hub.X - summit.X, 0, hub.Z - summit.Z).Unit
		local fight = summit + dir * 170 + Vector3.new(0, 90, 0)
		table.insert(segs, { summit + dir * 520 + Vector3.new(0, 40, 0), fight })
		for k, sg in segs do
			folder:SetAttribute("Seg" .. k .. "A", sg[1])
			folder:SetAttribute("Seg" .. k .. "B", sg[2])
		end
		folder:SetAttribute("Segs", #segs)
		folder:SetAttribute("Fight", fight)
		folder:SetAttribute("FightDir", -dir) -- il rivale arriva dalla vetta
	else
		return "Clip sconosciuta"
	end
	folder:SetAttribute("Kind", kind)
	folder:SetAttribute("Take", os.clock())
	folder.Parent = workspace
	task.delay(90, function()
		if folder.Parent then
			folder:Destroy()
		end
	end)
	return nil
end

return ClipProps
