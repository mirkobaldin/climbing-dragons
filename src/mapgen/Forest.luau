--!strict
-- Alberi: ciliegi in basso (piana, valli, rive dei fiumi), latifoglie a mezza costa e
-- conifere in alto, a macchie. Usa i modelli di alberi che trova in ServerStorage (anche
-- dentro pack come "Realistic Trees Pack"): nome con "cherry"/"sakura"/"ciliegio" = ciliegio,
-- "pine"/"pino"/"abete" = conifera, gli altri latifoglie. Se una categoria manca si usano le
-- altre; se non c'e' nessun modello, un pino segnaposto a cilindri.
-- Gli script dentro i modelli del Toolbox vengono rimossi (a volte sono virus).

local ServerStorage = game:GetService("ServerStorage")
local Heightmap = require(script.Parent.Heightmap)
local Noise = require(script.Parent.Noise)

local readu8 = buffer.readu8
local floor, sqrt = math.floor, math.sqrt

local Forest = {}

local TRUNK = Color3.fromRGB(78, 58, 42)
local NEEDLES = { Color3.fromRGB(38, 66, 40), Color3.fromRGB(46, 76, 44), Color3.fromRGB(33, 58, 38) }
local CHERRY_WORDS = { "cherry", "sakura", "blossom", "ciliegi" }

local function placeholderPine(parent: Instance, base: Vector3, scale: number, yaw: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Pine"
	local height = 16 * scale
	local trunk = Instance.new("Part")
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(height, 1.4 * scale, 1.4 * scale)
	trunk.CFrame = CFrame.new(base + Vector3.new(0, height / 2 - 1, 0)) * CFrame.Angles(0, yaw, math.pi / 2)
	trunk.Material = Enum.Material.Wood
	trunk.Color = TRUNK
	trunk.Anchored = true
	trunk.Parent = model
	local color = NEEDLES[rng:NextInteger(1, #NEEDLES)]
	-- Chioma a palchi: dischi sempre piu' stretti verso la punta
	for k = 0, 3 do
		local layer = Instance.new("Part")
		layer.Shape = Enum.PartType.Cylinder
		local radius = (7 - k * 1.6) * scale
		layer.Size = Vector3.new(3.2 * scale, radius * 2, radius * 2)
		layer.CFrame = CFrame.new(base + Vector3.new(0, (5 + k * 3.4) * scale, 0)) * CFrame.Angles(0, yaw + k, math.pi / 2)
		layer.Material = Enum.Material.Grass
		layer.Color = color
		layer.Anchored = true
		layer.CanCollide = false
		layer.CanQuery = false
		layer.Parent = model
	end
	model.PrimaryPart = trunk
	model.Parent = parent
end

-- Cerca i modelli di alberi in tutto ServerStorage (anche dentro pack e sottocartelle)
local CATEGORY_WORDS = {
	cherry = CHERRY_WORDS,
	pine = { "pine", "pino", "fir", "abete", "spruce", "conifer" },
}
local TREE_WORDS = { "tree", "albero", "sakura", "cherry", "pine", "pino", "oak", "quercia", "abete" }
-- nomi che contengono una parola da albero ma non lo sono ("Rampino" contiene "pino": il rampino
-- finiva piantato fra gli alberi)
local NOT_TREE_WORDS = { "rampino", "grappl", "hook", "uncino" }

local function hasWord(name: string, words: { string }): boolean
	local lower = string.lower(name)
	for _, word in words do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end

-- Prepara un modello: via script, suoni e ossa (gli alberi del pack sono mesh deformabili per lo
-- SmartBone: ferme come le usiamo noi costavano solo calcolo, 25.000 ossa su 6.000 alberi),
-- tutto ancorato, pivot alla base del tronco
local function prepare(source: Model): Model
	local model = source:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Bone") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanQuery = false -- l'arrampicata e i raycast ignorano le chiome
			d.CanTouch = false
			if d.Transparency >= 1 then
				d.CanCollide = false -- vecchie collisioni invisibili del pack
			end
		end
	end
	local cf, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
	model:SetAttribute("TemplateHeight", size.Y)
	return model
end

type Templates = { cherry: { Model }, pine: { Model }, other: { Model } }

local function loadTemplates(): Templates
	local t: Templates = { cherry = {}, pine = {}, other = {} }
	local function scan(parent: Instance)
		for _, child in parent:GetChildren() do
			if child:IsA("Model") and hasWord(child.Name, TREE_WORDS) and not hasWord(child.Name, NOT_TREE_WORDS) and child:FindFirstChildWhichIsA("BasePart", true) then
				local kind = if hasWord(child.Name, CATEGORY_WORDS.cherry)
					then "cherry"
					elseif hasWord(child.Name, CATEGORY_WORDS.pine) then "pine"
					else "other"
				table.insert((t :: any)[kind], prepare(child))
			elseif child:IsA("Folder") or (child:IsA("Model") and not child:FindFirstChildWhichIsA("BasePart")) then
				scan(child) -- cartelle e pack
			end
		end
	end
	scan(ServerStorage)
	return t
end

-- Collisione del tronco: un cilindro invisibile (le mesh del pack non collidono)
local function trunkCollider(tree: Model, base: Vector3, height: number)
	local c = Instance.new("Part")
	c.Name = "TrunkCollider"
	c.Shape = Enum.PartType.Cylinder
	c.Size = Vector3.new(height * 0.45, math.max(1.2, height * 0.05), math.max(1.2, height * 0.05))
	c.CFrame = CFrame.new(base + Vector3.new(0, height * 0.225, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	c.Transparency = 1
	c.Anchored = true
	c.CanTouch = false
	c.Parent = tree
end

function Forest.plant(map: Heightmap.Map, yield: () -> (), progress: (string, number) -> ())
	local cfg = map.cfg
	local F = cfg.FOREST
	local old = workspace:FindFirstChild("Forest")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Forest"
	folder.Parent = workspace

	local T = loadTemplates()
	local all = {}
	for _, list in { T.cherry, T.pine, T.other } do
		for _, m in list do
			table.insert(all, m)
		end
	end
	local function pick(list: { Model }, rng: Random): Model?
		local pool = if #list > 0 then list elseif #all > 0 then all else nil
		return if pool then pool[rng:NextInteger(1, #pool)] else nil
	end
	print(string.format("[MapGen] Alberi: %d ciliegi, %d conifere, %d altri modelli", #T.cherry, #T.pine, #T.other))
	if #all == 0 then
		warn("[MapGen] Nessun modello di albero trovato in ServerStorage: uso i pini segnaposto")
	end

	local rng = Random.new(cfg.SEED + 7)
	local V = cfg.VOXEL
	local topY = cfg.MOUNTAIN.HEIGHT * cfg.BIOMES.FOREST_TOP + F.ABOVE_FOREST_TOP
	local HUB = cfg.HUB
	local campX, campZ = HUB.X + HUB.CAMP.DX, HUB.Z + HUB.CAMP.DZ
	local entrance = map.features.caveEntrance
	local Zone = Heightmap.Zone
	local okZone = { [Zone.NATURAL] = true, [Zone.RIVERBANK] = true, [Zone.HUB] = true }
	local okMat = {}
	for code, name in Heightmap.MATERIALS do
		okMat[code] = name == "Grass" or name == "LeafyGrass" or name == "Ground"
	end

	local count = 0
	local x0, z0 = map.minX, map.minZ
	local x1, z1 = x0 + cfg.MAP_X - F.CELL, z0 + cfg.MAP_Z - F.CELL
	for x = x0, x1, F.CELL do
		for z = z0, z1, F.CELL do
			local px, pz = x + rng:NextNumber(0, F.CELL), z + rng:NextNumber(0, F.CELL)
			local ix, iz = floor((px - x0) / V), floor((pz - z0) / V)
			if ix < 1 or iz < 1 or ix >= map.nx - 1 or iz >= map.nz - 1 then
				continue
			end
			local i = ix + iz * map.nx
			local zone = readu8(map.zone, i)
			if not okZone[zone] or not okMat[readu8(map.surf, i)] then
				continue
			end
			local h = Heightmap.sampleH(map, px, pz)
			if h < cfg.WATER_LEVEL + 6 or h > topY then
				continue
			end
			local slope = sqrt(
				((Heightmap.sampleH(map, px + V, pz) - Heightmap.sampleH(map, px - V, pz)) / (2 * V)) ^ 2
					+ ((Heightmap.sampleH(map, px, pz + V) - Heightmap.sampleH(map, px, pz - V)) / (2 * V)) ^ 2
			)
			if slope > 0.85 then
				continue
			end
			-- Radure: cerchio delle tende, mezzaluna delle case, davanti al teschio
			local campD2 = (px - campX) ^ 2 + (pz - campZ) ^ 2
			if campD2 < (HUB.CRESCENT.OUTER + 25) ^ 2 then
				-- nella piana solo qualche ciliegio sparso tra le case, lontano dal cerchio
				if campD2 < (HUB.CAMP.RADIUS + 30) ^ 2 or rng:NextNumber() > 0.12 then
					continue
				end
			end
			if entrance and (px - entrance.x) ^ 2 + (pz - entrance.z) ^ 2 < 110 ^ 2 then
				continue
			end
			local cleared = false
			for _, c in map.features.clearings or {} do
				if (px - c.x) ^ 2 + (pz - c.z) ^ 2 < c.r * c.r then
					cleared = true
					break
				end
			end
			if cleared then
				continue -- terreni delle case (vedi Village)
			end
			local roads = map.features.roadCells
			if roads and roads[floor(px / 16) .. "," .. floor(pz / 16)] then
				continue -- strade dei borghi (vedi Borghi)
			end
			local tut = map.features.tutorial
			if tut and (px - tut.x) ^ 2 + (pz - tut.z) ^ 2 < (tut.radius + 30) ^ 2 then
				continue
			end
			local skull = map.features.dragonSkull
			if skull and (px - skull.x) ^ 2 + (pz - skull.z) ^ 2 < (cfg.DRAGON.SKULL_LENGTH * 0.6) ^ 2 then
				continue
			end
			local density = Noise.smoothstep(-0.05, 0.2, Noise.fbm(px / 400, pz / 400, cfg.SEED % 997 + 0.37, 2))
			if zone == Zone.RIVERBANK or zone == Zone.HUB then
				density = math.max(density, 0.6) -- rive dei fiumi alberate
			end
			if rng:NextNumber() > density * F.DENSITY then
				continue
			end

			-- Ciliegi in basso, latifoglie a mezza costa, conifere in alto (con un po' di misto)
			local roll = rng:NextNumber()
			local list = if h < F.CHERRY_MAX_Y
				then (if roll < 0.8 then T.cherry else T.other)
				elseif h < F.PINE_MIN_Y then (if roll < 0.6 then T.other else T.pine)
				else (if roll < 0.85 then T.pine else T.other)
			local template = pick(list, rng)
			local scale = if rng:NextNumber() < F.GIANT_CHANCE
				then rng:NextNumber(F.GIANT_SCALE[1], F.GIANT_SCALE[2])
				else rng:NextNumber(F.SCALE[1], F.SCALE[2])
			local yaw = rng:NextNumber(0, 2 * math.pi)
			local base = Vector3.new(px, h - 0.8, pz)
			if template then
				local tree = template:Clone()
				tree:PivotTo(CFrame.new(base) * CFrame.Angles(0, yaw, 0))
				tree:ScaleTo(tree:GetScale() * scale)
				-- effetti (petali, foglie che cadono) solo su qualche albero: sono pesanti
				if count % F.EFFECTS_EVERY ~= 0 then
					for _, d in tree:GetDescendants() do
						if d:IsA("ParticleEmitter") then
							d:Destroy()
						end
					end
				end
				trunkCollider(tree, base, (template:GetAttribute("TemplateHeight") or 20) * scale)
				tree.Parent = folder
			else
				placeholderPine(folder, base, scale, yaw, rng)
			end
			count += 1
			if count >= F.MAX_TREES then
				progress("Bosco", 1)
				return
			end
		end
		yield()
		progress("Bosco", (x - x0) / (x1 - x0))
	end
end


-- anche per altri generatori (mapgen/IsolaDraghi: alberi sull'isola)
Forest.loadTemplates = loadTemplates
Forest.trunkCollider = trunkCollider

return Forest
