--!strict
-- Isole volanti coi modelli di Blender (ServerStorage.BorghiKit: IsolaPiccola/Media/Grande,
-- Nuvola A-D, padiglione, torii, lanterne):
--   * sopra le zone del drago Tempesta e del drago Fulmine Nero: isole coi cristalli di Mirko di
--     quell'elemento (ServerStorage.Modelli, "Cristallo_tempesta", "Cristallo_fulminenero")
--   * sopra la montagna: un anello di isole con padiglione, torii e lanterne di pietra
--   * nuvole attorno a tutte
-- Si rifa' da sola (non serve rigenerare la mappa):
--   require(game.ServerStorage.MapGen:Clone().Isole).build()

local ServerStorage = game:GetService("ServerStorage")

local Isole = {}

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- i cristalli di Mirko per l'elemento (come ThemeZones: maiuscole, spazi e "_" non contano;
-- "fulminenero" = Fulmine)
local function crystalModels(element: string): { Model }
	local out = {}
	local store = ServerStorage:FindFirstChild("Modelli")
	local want = "cristallo" .. string.lower(element)
	for _, m in (if store then store:GetChildren() else {}) :: { Instance } do
		local n = string.gsub(string.lower((string.gsub(m.Name, "[%s_]", ""))), "fulminenero", "fulmine")
		if m:IsA("Model") and n == want then
			table.insert(out, m)
		end
	end
	return out
end

-- un cristallo di Mirko alto h appoggiato in cf (niente script, niente collisioni come nelle zone)
local function crystal(tpl: Model, parent: Instance, cf: CFrame, h: number, element: string)
	local m = tpl:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	local _, s0 = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * h / math.max(s0.Y, 0.05))
	m:PivotTo(cf)
	local box, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, cf.Y - (box.Position.Y - s.Y / 2) - s.Y * 0.1, 0))
	m:SetAttribute("Element", element) -- effetti sul client (client/CrystalFX)
	m.Name = "Cristallo"
	m.Parent = parent
end

local function kit(name: string): Model?
	local f = ServerStorage:FindFirstChild("BorghiKit")
	local m = f and f:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

local function place(name: string, parent: Instance, cf: CFrame, scale: number?): Model?
	local t = kit(name)
	if not t then
		return nil
	end
	local m = t:Clone()
	if scale and math.abs(scale - 1) > 0.01 then
		m:ScaleTo(scale)
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

-- l'isola ci sta se attorno (fino al bordo e sotto) non c'e' terreno
local function free(at: Vector3, radius: number, depth: number): boolean
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		if workspace:Raycast(at, dir * (radius + 15), terrainOnly) then
			return false
		end
		if workspace:Raycast(at + dir * radius * 0.6, Vector3.new(0, -(depth + 25), 0), terrainOnly) then
			return false
		end
	end
	return workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -(depth + 70), 0), terrainOnly) == nil
end

-- un punto sulla cima dell'isola (raggio dentro l'isola stessa)
local function onTop(island: Model, x: number, z: number): CFrame?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { island }
	local p = island:GetPivot():PointToWorldSpace(Vector3.new(x, 0, z))
	local hit = workspace:Raycast(p + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), params)
	if not hit or hit.Instance.Name ~= "GRASS" then
		return nil
	end
	return CFrame.new(hit.Position) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
end

local SIZES = { IsolaPiccola = 14, IsolaMedia = 24, IsolaGrande = 38, IsolaTerreno = 38 }

local function island(rng: Random, parent: Instance, at: Vector3, kind: string, scale: number, theme: string, bare: boolean?): Model?
	local R = SIZES[kind] * scale
	if not free(at, R, R * 1.3) then
		return nil
	end
	local m = place(kind, parent, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), scale)
	if not m then
		return nil
	end
	-- sopra: i cristalli dell'elemento, o (sulla montagna) padiglione e lanterne. Niente torii:
	-- Mirko non vuole i "pali giapponesi" in mezzo alle isole. Le isole dei terreni (bare) restano
	-- vuote: in mezzo ci va la casa
	local crystals = if theme == "Cielo" then {} else crystalModels(theme)
	local props = { "Padiglione", "LanternaPietra", "LanternaPietra" }
	local n = if bare then 0 elseif kind == "IsolaGrande" then 4 elseif kind == "IsolaMedia" then 3 else 1
	if #crystals > 0 then
		n += 2
	end
	local used = 0
	for _ = 1, n * 6 do
		if used >= n then
			break
		end
		local r = R * 0.55 * math.sqrt(rng:NextNumber())
		local a = rng:NextNumber(0, math.pi * 2)
		local cf = onTop(m, math.cos(a) * r / scale, math.sin(a) * r / scale)
		if cf then
			if #crystals > 0 then
				crystal(crystals[rng:NextInteger(1, #crystals)], m, cf, rng:NextNumber(7, 16) * scale, theme)
				used += 1
			else
				local name = props[rng:NextInteger(1, #props)]
				-- il padiglione solo sulle isole grandi
				if name == "Padiglione" and kind == "IsolaPiccola" then
					name = "LanternaPietra"
				end
				if place(name, m, cf) then
					used += 1
				end
			end
		end
	end
	-- nuvole attorno, un po' sotto la cima
	for _ = 1, rng:NextInteger(1, 3) do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = R * rng:NextNumber(1.1, 2.0)
		local c = at + Vector3.new(math.cos(a) * d, rng:NextNumber(-R * 0.9, R * 0.2), math.sin(a) * d)
		local cl = place(({ "NuvolaA", "NuvolaB", "NuvolaC", "NuvolaD" })[rng:NextInteger(1, 4)], parent, CFrame.new(c) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.8, 1.8))
		if cl then
			cl.Name = "Nuvola"
		end
	end
	return m
end

-- Terreni di livello 4 (Sky Chalet, server/Economy): grandi isole sopra la piana attorno al campo
-- base, con il terreno (tag "Plot", Level 4, Zone "Cielo") al centro. Si rifanno da sole:
--   require(game.ServerStorage.MapGen:Clone().Isole).skyPlots()
function Isole.skyPlots(): string
	local root = workspace:FindFirstChild("IsoleVolanti")
	if not root then
		root = Instance.new("Folder")
		root.Name = "IsoleVolanti"
		root.Parent = workspace
	end
	local old = root:FindFirstChild("TerreniCielo")
	if old then
		old:Destroy()
	end
	-- IsolaTerreno: come la grande ma senza massi sopra (spuntavano dalla pedana) e piu' piatta
	local KIND = if kit("IsolaTerreno") then "IsolaTerreno" else "IsolaGrande"
	if not kit(KIND) then
		return "[Isole] manca BorghiKit.IsolaGrande"
	end
	-- Mirko: non alla base della montagna ma "un attimo piu' in alto" degli Chalet. Si parte dai
	-- terreni degli Chalet (Level 3, sui costoni) e si va verso fuori dalla montagna, 170-260
	-- studs piu' in alto, dove c'e' aria libera per un'isola grande (casa, pedana e recinto)
	local MOUNT = Vector3.new(1300, 0, 0) -- centro della montagna (Config.MOUNTAIN)
	local chalets = {}
	for _, p in game:GetService("CollectionService"):GetTagged("Plot") do
		if p:IsA("Model") and p:GetAttribute("Level") == 3 then
			table.insert(chalets, p:GetPivot().Position)
		end
	end
	if #chalets == 0 then
		return "[Isole] nessun terreno degli Chalet (Level 3): rigenera la mappa"
	end
	table.sort(chalets, function(a, b)
		return a.X + a.Z * 0.001 < b.X + b.Z * 0.001
	end)
	local folder = Instance.new("Folder")
	folder.Name = "TerreniCielo"
	folder.Parent = root
	local rng = Random.new(20261014)
	local made = 0
	local SCALE = 4.6 -- isola grande: ci stanno il Mega Chalet in scala 5, la pedana e il recinto
	local used: { Vector3 } = {}
	for _, base in chalets do
		if made >= 4 then
			break
		end
		local out = Vector3.new(base.X - MOUNT.X, 0, base.Z - MOUNT.Z)
		out = if out.Magnitude > 1 then out.Unit else Vector3.xAxis
		local isl: Model? = nil
		local at = base
		-- (la roccia sotto e' profonda ~225 studs: sotto serve aria per almeno 280)
		for _, try in { { 320, 200 }, { 420, 220 }, { 520, 240 }, { 620, 220 }, { 720, 260 }, { 820, 240 } } do
			local side = Vector3.new(-out.Z, 0, out.X) * rng:NextNumber(-80, 80)
			local p = base + out * try[1] + side
			local ground = workspace:Raycast(Vector3.new(p.X, 5200, p.Z), Vector3.new(0, -6000, 0), terrainOnly)
			local gy = if ground then ground.Position.Y else 0
			at = Vector3.new(p.X, math.max(base.Y + try[2], gy + 290), p.Z)
			local near = false
			for _, u in used do
				if (u - at).Magnitude < 38 * SCALE * 2.6 then
					near = true
				end
			end
			if not near then
				isl = island(rng, folder, at, KIND, SCALE, "Cielo", true)
				if isl then
					break
				end
			end
			task.wait()
		end
		if isl then
			table.insert(used, at)
			-- il terreno al centro della cima, con l'ingresso (-Z) verso la montagna (si arriva da li')
			local top = onTop(isl, 0, 0)
			if top then
				local toHub = Vector3.new(MOUNT.X - at.X, 0, MOUNT.Z - at.Z).Unit
				local cf = CFrame.lookAt(top.Position, top.Position + toHub)
				local plot = Instance.new("Model")
				plot.Name = "TerrenoCielo" .. (made + 1)
				plot:SetAttribute("Level", 4)
				plot:SetAttribute("Zone", "Cielo")
				local function block(size: Vector3, c: CFrame, name: string): Part
					local b = Instance.new("Part")
					b.Name = name
					b.Size = size
					b.CFrame = c
					b.Anchored = true
					b.Color = Color3.fromRGB(150, 110, 70)
					b.Material = Enum.Material.WoodPlanks
					b.Parent = plot
					return b
				end
				-- cartello davanti all'angolo della pedana (il Mega Chalet in scala 5 e' largo ~125 studs:
				-- a (38, -52) finiva dentro la casa), appoggiato sul prato dell'isola
				local signCf = cf * CFrame.new(58, 0, -96)
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = { isl }
				local hitSign = workspace:Raycast(signCf.Position + Vector3.new(0, 40, 0), Vector3.new(0, -90, 0), params)
				if hitSign then
					signCf = CFrame.new(hitSign.Position) * cf.Rotation
				end
				local post = block(Vector3.new(0.6, 5, 0.6), signCf * CFrame.new(0, 2.5, 0), "PlotPost")
				local board = block(Vector3.new(6, 3, 0.3), signCf * CFrame.new(0, 5, -0.2), "PlotSign")
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Front
				gui.PixelsPerStud = 40
				gui.Parent = board
				local text = Instance.new("TextLabel")
				text.Name = "Owner"
				text.Size = UDim2.fromScale(1, 1)
				text.BackgroundTransparency = 1
				text.Font = Enum.Font.GothamBold
				text.TextScaled = true
				text.TextColor3 = Color3.fromRGB(50, 34, 20)
				text.Text = "Free plot"
				text.Parent = gui
				local anchor = block(Vector3.one, cf, "HouseAnchor")
				anchor.Transparency = 1
				anchor.CanCollide = false
				anchor.CanQuery = false
				local _ = post
				plot.WorldPivot = cf
				plot.Parent = folder
				game:GetService("CollectionService"):AddTag(plot, "Plot")
				made += 1
			else
				isl:Destroy()
			end
		end
		task.wait()
	end
	local msg = "[Isole] terreni del Sky Chalet: " .. made
	print(msg)
	return msg
end

function Isole.build(): string
	local old = workspace:FindFirstChild("IsoleVolanti")
	if old then
		old:Destroy()
	end
	if not kit("IsolaMedia") then
		return "manca ServerStorage.BorghiKit (importa borghi.fbx e lancia BorghiKit.prepare)"
	end
	local root = Instance.new("Folder")
	root.Name = "IsoleVolanti"
	root.Parent = workspace
	local rng = Random.new(20261010)
	local report = {}
	local kinds = { "IsolaPiccola", "IsolaMedia", "IsolaMedia", "IsolaGrande" }
	-- sopra le zone del drago Tempesta e del drago Fulmine Nero
	for i = 1, (workspace:GetAttribute("ThemeZoneCount") or 0) :: number do
		local el = workspace:GetAttribute("ThemeZone" .. i .. "Element")
		local c = workspace:GetAttribute("ThemeZone" .. i .. "Center")
		local r = workspace:GetAttribute("ThemeZone" .. i .. "Radius")
		if (el == "Tempesta" or el == "Fulmine") and typeof(c) == "Vector3" and type(r) == "number" then
			local folder = Instance.new("Folder")
			folder.Name = (workspace:GetAttribute("ThemeZone" .. i .. "Title") or el) :: string
			folder.Parent = root
			local made = 0
			for _ = 1, 40 do
				if made >= 4 then
					break
				end
				local a = rng:NextNumber(0, math.pi * 2)
				local d = r * rng:NextNumber(0.2, 1.3)
				local at = c + Vector3.new(math.cos(a) * d, rng:NextNumber(45, 150), math.sin(a) * d)
				local ok = true
				for _, other in folder:GetChildren() do
					if other:IsA("Model") and other.Name ~= "Nuvola" and (other:GetPivot().Position - at).Magnitude < 70 then
						ok = false
					end
				end
				if ok and island(rng, folder, at, kinds[rng:NextInteger(1, #kinds)], rng:NextNumber(0.9, 1.4), el :: string) then
					made += 1
				end
				task.wait()
			end
			table.insert(report, folder.Name .. " " .. made)
		end
	end
	-- sopra la montagna: anello di isole attorno alla vetta
	local markers = workspace:FindFirstChild("MapMarkers")
	local summit = markers and markers:FindFirstChild("Summit")
	if summit and summit:IsA("BasePart") then
		local folder = Instance.new("Folder")
		folder.Name = "SopraLaMontagna"
		folder.Parent = root
		local made = 0
		for k = 0, 15 do
			if made >= 6 then
				break
			end
			local a = k / 16 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
			local d = rng:NextNumber(110, 230)
			local at = summit.Position + Vector3.new(math.cos(a) * d, rng:NextNumber(50, 190), math.sin(a) * d)
			if island(rng, folder, at, kinds[rng:NextInteger(2, #kinds)], rng:NextNumber(1.0, 1.5), "Cielo") then
				made += 1
			end
			task.wait()
		end
		table.insert(report, "montagna " .. made)
	end
	table.insert(report, Isole.skyPlots()) -- (la cartella si rifa' da capo: anche i terreni del cielo)
	local msg = "[Isole] " .. table.concat(report, ", ")
	print(msg)
	return msg
end

return Isole
