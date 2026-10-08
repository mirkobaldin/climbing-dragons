--!strict
-- Scena per il trailer e le clip di TikTok (comandi admin "trailer", "clip1", "clip2", "clip3"):
-- il server mette in Workspace.TrailerProps i draghi di scena (sempre inviati al client, anche
-- con lo streaming) e scrive negli attributi della cartella i punti della mappa che il client
-- inquadra. Poi la scena la gira il client (client/Trailer).

local DragonModels = require(script.Parent.DragonModels)

local TrailerProps = {}

local function persistent(model: Model, name: string, parent: Instance)
	model.Name = name
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:PivotTo(CFrame.new(0, -500, 0)) -- nascosti finche' il client non li usa
	model.Parent = parent
end

local takes = 0

-- prepara la scena e restituisce il numero della ripresa (il client aspetta proprio quella)
function TrailerProps.prepare(): string
	local old = workspace:FindFirstChild("TrailerProps")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "TrailerProps"
	-- punti della mappa
	local markers = workspace:FindFirstChild("MapMarkers")
	local summit = markers and markers:FindFirstChild("Summit")
	if summit and summit:IsA("BasePart") then
		folder:SetAttribute("Summit", summit.Position)
	end
	for _, name in { "TrainingCenter", "GasCenter" } do
		folder:SetAttribute(name, workspace:GetAttribute(name))
	end
	-- grotta di ghiaccio: le luci lungo la galleria fanno da binario per la camera
	local glacier = workspace:FindFirstChild("Glacier")
	local ice = glacier and glacier:FindFirstChild("Ghiaccio")
	local lights = ice and ice:FindFirstChild("LuciGrottaGhiaccio")
	if lights then
		local list = lights:GetChildren()
		for k = 1, math.min(#list, 12) do
			local p = list[k]
			if p:IsA("BasePart") then
				folder:SetAttribute("Cave" .. k, p.Position)
			end
		end
		folder:SetAttribute("CaveCount", math.min(#list, 12))
	end
	-- draghi di scena
	persistent(DragonModels.dragon("Eclissi", "Leggendario", 1, 1), "EclissiCucciolo", folder)
	persistent(DragonModels.dragon("Eclissi", "Leggendario", 3, 1), "EclissiAdulto", folder)
	persistent(DragonModels.dragon("Gas", "Epico", 2, 30), "Gas", folder)
	persistent(DragonModels.dragon("Gelo", "Raro", 1, 10), "Gelo", folder)
	-- lo stormo del trailer: tutti gli altri draghi
	-- gli 8 draghi coi modelli (Eclissi adulto guida, gli altri 7 dietro)
	for _, e in { "Roccia", "Gelo", "Cosmico", "Tempesta", "Fulmine", "Ossa", "Gas" } do
		local m = DragonModels.dragon(e, "Epico", 2, 30)
		m:ScaleTo(m:GetScale() * 2.2) -- nello stormo si vedono da lontano
		persistent(m, "Stormo" .. e, folder)
	end
	-- clip11 (giorno 1 / giorno 30): una tenda e uno chalet di scena sui terreni giusti (senza case)
	local village = workspace:FindFirstChild("Village")
	local plots = village and village:FindFirstChild("Plots")
	local templates = game:GetService("ServerStorage"):FindFirstChild("PlotBuildings")
	local KEY = { [1] = "Tent", [2] = "Cabin", [3] = "Chalet" }
	for name, level in { Tenda = 1, Baita = 2, Chalet = 3 } do
		local plot: Model? = nil
		for _, p in (if plots then plots:GetChildren() else {}) :: { Instance } do
			if p:IsA("Model") and p:GetAttribute("Level") == level and not p:FindFirstChild("House") then
				plot = p
				break
			end
		end
		local tpl = templates and templates:FindFirstChild(name)
		if plot and tpl and tpl:IsA("Model") then
			local house = tpl:Clone()
			for _, d in house:GetDescendants() do
				if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") then
					d:Destroy()
				end
			end
			persistent(house, "Casa" .. name, folder)
			folder:SetAttribute(KEY[level] .. "CF", (plot :: Model):GetPivot())
		end
	end
	-- percorsi calcolati QUI sul server, che ha tutta la mappa (il client vede solo il terreno
	-- vicino: i suoi raggi passavano attraverso la montagna non ancora caricata)
	local mcv = workspace:GetAttribute("CineCenter")
	local top = if summit and summit:IsA("BasePart") then summit.Position.Y else 4000
	if typeof(mcv) == "Vector3" then
		local mc = Vector3.new(mcv.X, 0, mcv.Z)
		local solid = RaycastParams.new()
		solid.FilterType = Enum.RaycastFilterType.Exclude
		solid.FilterDescendantsInstances = { folder, workspace:FindFirstChild("Pets") :: Instance, workspace:FindFirstChild("Nemici") :: Instance }
		local function surfaceR(a: number, y: number): number
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local hit = workspace:Raycast(Vector3.new(mc.X, y, mc.Z) + dir * 5000, -dir * 5000, solid)
			return if hit then (Vector3.new(hit.Position.X, 0, hit.Position.Z) - mc).Magnitude else 0
		end
		-- giro della mappa (clip7): 23 punti attorno alla montagna, sale fino a meta' e riscende
		local face = workspace:GetAttribute("GrandCaveFace")
		local a0 = if typeof(face) == "Vector3" then math.atan2(face.Z - mc.Z, face.X - mc.X) else 0
		local N = 22
		for k = 0, N do
			local f = k / N
			local a = a0 + f * 2 * math.pi
			local y = 520 + (top * 0.55 - 520) * (0.5 - 0.5 * math.cos(f * 2 * math.pi))
			local r = math.max(surfaceR(a, y), surfaceR(a, y - 110), surfaceR(a, y + 110)) + 200
			folder:SetAttribute("Orbit" .. k, Vector3.new(mc.X + math.cos(a) * r, y, mc.Z + math.sin(a) * r))
		end
		folder:SetAttribute("OrbitCount", N + 1)
		-- parete di roccia vera per lo scalatore (clip 8 e 9): ripida, libera davanti, lontana dalle
		-- zone dei draghi e dalle grotte
		local bad: { Vector3 } = {}
		for i = 1, (workspace:GetAttribute("ThemeZoneCount") or 0) :: number do
			local c = workspace:GetAttribute("ThemeZone" .. i .. "Center")
			if typeof(c) == "Vector3" then
				table.insert(bad, c)
			end
		end
		for _, key in { "GrandCaveCenter", "CraterCaveCenter" } do
			local v = workspace:GetAttribute(key)
			if typeof(v) == "Vector3" then
				table.insert(bad, v)
			end
		end
		local terrainOnly = RaycastParams.new()
		terrainOnly.FilterType = Enum.RaycastFilterType.Include
		terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
		local y = top * 0.21
		for k = 0, 143 do
			local a = k / 144 * 2 * math.pi + 0.11
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local hit = workspace:Raycast(Vector3.new(mc.X, y, mc.Z) + dir * 5000, -dir * 5000, terrainOnly)
			if hit and math.abs(hit.Normal.Y) < 0.3 and hit.Material ~= Enum.Material.Ice and hit.Material ~= Enum.Material.Glacier then
				local ok = not workspace:Raycast(hit.Position + hit.Normal * 2, hit.Normal * 80, solid)
				for _, b in bad do
					if (b - hit.Position).Magnitude < 320 then
						ok = false
					end
				end
				local n = hit.Normal
				local above = workspace:Raycast(hit.Position + n * 3 + Vector3.new(0, 10, 0), -n * 8, terrainOnly)
				local below = workspace:Raycast(hit.Position + n * 3 - Vector3.new(0, 10, 0), -n * 8, terrainOnly)
				if ok and above and below then
					folder:SetAttribute("WallSpot", hit.Position)
					folder:SetAttribute("WallNormal", Vector3.new(n.X, 0, n.Z).Unit)
					break
				end
			end
		end
	end
	-- la Grande Grotta (punti scritti dal generatore della mappa)
	folder:SetAttribute("GrandCenter", workspace:GetAttribute("GrandCaveCenter"))
	folder:SetAttribute("GrandOut", workspace:GetAttribute("GrandCaveOut"))
	folder:SetAttribute("GrandFace", workspace:GetAttribute("GrandCaveFace"))
	takes += 1
	local take = tostring(takes)
	folder:SetAttribute("Take", take)
	folder.Parent = workspace
	return take
end

return TrailerProps
