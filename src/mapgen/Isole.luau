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

local SIZES = { IsolaPiccola = 14, IsolaMedia = 24, IsolaGrande = 38 }

local function island(rng: Random, parent: Instance, at: Vector3, kind: string, scale: number, theme: string): Model?
	local R = SIZES[kind] * scale
	if not free(at, R, R * 1.3) then
		return nil
	end
	local m = place(kind, parent, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), scale)
	if not m then
		return nil
	end
	-- sopra: i cristalli dell'elemento, o (sulla montagna) padiglione, torii e lanterne
	local crystals = if theme == "Cielo" then {} else crystalModels(theme)
	local props = { "Padiglione", "Torii", "LanternaPietra", "LanternaPietra" }
	local n = if kind == "IsolaGrande" then 4 elseif kind == "IsolaMedia" then 3 else 1
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
				-- il padiglione e il torii solo sulle isole grandi
				if (name == "Padiglione" or name == "Torii") and kind == "IsolaPiccola" then
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
	local msg = "[Isole] " .. table.concat(report, ", ")
	print(msg)
	return msg
end

return Isole
