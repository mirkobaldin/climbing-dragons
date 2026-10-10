--!strict
-- Riempie i prati vuoti (piana della base, pianure attorno alle costole e ai piedi della
-- montagna) con cose naturali, dopo case e strade e prima del bosco:
--   * affioramenti di roccia: massi tondi mezzi sepolti nel prato, a gruppi
--   * rovine: colonne spezzate e archi di pietra con il muschio, sparsi e rari
-- Se in ServerStorage c'e' una cartella "Decor" con dei Model, si usano quelli al posto delle
-- rovine fatte a blocchi (pivot = centro a terra; gli script vengono tolti).
-- Ogni pezzo diventa una radura per il bosco (map.features.clearings).

local ServerStorage = game:GetService("ServerStorage")
local Heightmap = require(script.Parent.Heightmap)

local Scatter = {}

local MOSS = Color3.fromRGB(96, 112, 74)
local STONE = Color3.fromRGB(150, 146, 136)

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- colonna spezzata, inclinata, con il capitello caduto accanto
local function brokenColumn(parent: Instance, at: Vector3, rng: Random)
	local h = rng:NextNumber(8, 22)
	local cf = CFrame.new(at) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6.28), rng:NextNumber(-0.12, 0.12))
	part(parent, Vector3.new(4.6, 1.2, 4.6), cf * CFrame.new(0, 0.2, 0), STONE, Enum.Material.Cobblestone)
	local col = part(parent, Vector3.new(h, 3.2, 3.2), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Limestone)
	col.Shape = Enum.PartType.Cylinder
	part(parent, Vector3.new(3.4, 0.5, 3.4), cf * CFrame.new(0, h * 0.55, 0), MOSS, Enum.Material.Grass).CanCollide = false
	if rng:NextNumber() < 0.6 then
		part(parent, Vector3.new(4.4, 1.6, 4.4), CFrame.new(at + Vector3.new(rng:NextNumber(-7, 7), 0.6, rng:NextNumber(-7, 7))) * CFrame.Angles(0.3, rng:NextNumber(0, 6), 0.2), STONE, Enum.Material.Cobblestone)
	end
end

-- arco di pietra in rovina (due piedritti e l'architrave, a volte crollato a meta')
local function ruinArch(parent: Instance, at: Vector3, rng: Random)
	local cf = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local h, w = rng:NextNumber(14, 20), rng:NextNumber(12, 18)
	for _, x in { -w / 2, w / 2 } do
		part(parent, Vector3.new(3.4, h, 3.4), cf * CFrame.new(x, h / 2, 0), STONE, Enum.Material.Limestone)
		part(parent, Vector3.new(3.6, 0.6, 3.6), cf * CFrame.new(x, h + 0.2, 0), MOSS, Enum.Material.Grass).CanCollide = false
	end
	if rng:NextNumber() < 0.6 then
		part(parent, Vector3.new(w + 5, 3, 4), cf * CFrame.new(0, h + 1.5, 0), STONE, Enum.Material.Limestone)
	else
		part(parent, Vector3.new(w * 0.6, 3, 4), cf * CFrame.new(w * 0.2, 1.6, 4) * CFrame.Angles(0, 0.4, 0.15), STONE, Enum.Material.Limestone)
	end
end

function Scatter.place(map: Heightmap.Map)
	local old = workspace:FindFirstChild("Decorazioni")
	if old then
		old:Destroy()
	end
	local cfg = map.cfg
	local folder = Instance.new("Folder")
	folder.Name = "Decorazioni"
	local rng = Random.new(cfg.SEED + 515)
	local Zone = Heightmap.Zone
	local OK = { [Zone.NATURAL] = true, [Zone.HUB] = true }
	local decor = ServerStorage:FindFirstChild("Decor")
	local models: { Model } = {}
	if decor then
		for _, m in decor:GetChildren() do
			if m:IsA("Model") then
				local c = m:Clone()
				for _, d in c:GetDescendants() do
					if d:IsA("LuaSourceContainer") then
						d:Destroy() -- mai script dentro i modelli della mappa
					end
				end
				table.insert(models, c)
			end
		end
	end
	map.features.clearings = map.features.clearings or {}
	local function free(x: number, z: number, r: number): boolean
		-- niente massi sulle strade dei borghi (celle di 16 stud, vedi Borghi)
		local roads = map.features.roadCells
		if roads then
			local n = math.ceil(r / 16)
			for i = -n, n do
				for j = -n, n do
					if roads[(math.floor(x / 16) + i) .. "," .. (math.floor(z / 16) + j)] then
						return false
					end
				end
			end
		end
		for _, c in map.features.clearings do
			if (x - c.x) ^ 2 + (z - c.z) ^ 2 < (c.r + r) ^ 2 then
				return false
			end
		end
		local tut = map.features.tutorial
		if tut and (x - tut.x) ^ 2 + (z - tut.z) ^ 2 < (tut.radius + 40 + r) ^ 2 then
			return false
		end
		local camp = map.features.campCenter
		return not camp or (x - camp.x) ^ 2 + (z - camp.z) ^ 2 > (cfg.HUB.CAMP.RADIUS + 60 + r) ^ 2
	end
	local V = cfg.VOXEL
	local rocks, ruins = 0, 0
	local T = workspace.Terrain
	for _ = 1, 4000 do
		local x = rng:NextNumber(map.minX + 200, map.minX + cfg.MAP_X - 200)
		local z = rng:NextNumber(map.minZ + 200, map.minZ + cfg.MAP_Z - 200)
		local ix = math.clamp(math.floor((x - map.minX) / V), 0, map.nx - 1)
		local iz = math.clamp(math.floor((z - map.minZ) / V), 0, map.nz - 1)
		if not OK[buffer.readu8(map.zone, ix + iz * map.nx)] then
			continue
		end
		local hit = workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -2200, 0), terrainOnly)
		if not hit or hit.Position.Y < cfg.WATER_LEVEL + 4 or hit.Position.Y > 420 or hit.Normal.Y < 0.85 then
			continue
		end
		local m = hit.Material
		if m ~= Enum.Material.Grass and m ~= Enum.Material.LeafyGrass and m ~= Enum.Material.Ground then
			continue
		end
		local p = hit.Position
		local roll = rng:NextNumber()
		if roll < 0.75 and rocks < 140 and free(x, z, 22) then
			-- affioramento: 3-6 massi tondi, i piu' grossi al centro, mezzo sepolti
			local n = rng:NextInteger(3, 6)
			for k = 1, n do
				local r = rng:NextNumber(5, 13) * (if k == 1 then 1.3 else 1)
				local o = Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14)) * (if k == 1 then 0.2 else 1)
				T:FillBall(p + o - Vector3.new(0, r * 0.45, 0), r, if rng:NextNumber() < 0.5 then Enum.Material.Rock else Enum.Material.Slate)
			end
			table.insert(map.features.clearings, { x = x, z = z, r = 26 })
			rocks += 1
		elseif roll >= 0.75 and ruins < 40 and free(x, z, 24) then
			if #models > 0 then
				local c = models[rng:NextInteger(1, #models)]:Clone()
				c:PivotTo(CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
				c.Parent = folder
			elseif rng:NextNumber() < 0.5 then
				ruinArch(folder, p, rng)
			else
				for _ = 1, rng:NextInteger(2, 4) do
					brokenColumn(folder, p + Vector3.new(rng:NextNumber(-16, 16), -0.5, rng:NextNumber(-16, 16)), rng)
				end
			end
			table.insert(map.features.clearings, { x = x, z = z, r = 28 })
			ruins += 1
		end
		if rocks >= 140 and ruins >= 40 then
			break
		end
	end
	folder.Parent = workspace
	print(string.format("[MapGen] Prati: %d affioramenti di roccia, %d rovine", rocks, ruins))
end

return Scatter
