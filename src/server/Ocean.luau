--!strict
-- Oceano fino all'orizzonte. Il mare di Terrain finisce a qualche chilometro dall'isola: dalla
-- vetta (o nella cinematica) si vedeva il suo bordo dritto contro il cielo. Attorno al mare vero
-- si mettono quattro fasce piatte dello stesso colore, appena sotto il pelo dell'acqua, fino a
-- decine di chilometri. Solo da vedere: non si tocca e non blocca niente.

local Ocean = {}

local SURFACE = 19.9 -- pelo dell'acqua di Terrain (WATER_LEVEL 20)
local REACH = 60000 -- fin dove arriva
local COLOR = Color3.fromRGB(14, 82, 100)

local terrainWater = RaycastParams.new()
terrainWater.FilterType = Enum.RaycastFilterType.Include
terrainWater.FilterDescendantsInstances = { workspace.Terrain }
terrainWater.IgnoreWater = false

-- fin dove arriva l'acqua di Terrain lungo una direzione (si parte gia' in mare aperto)
local function waterEdge(dir: Vector3, from: number): number
	local last = from
	for d = from, 30000, 32 do
		local p = dir * d
		local hit = workspace:Raycast(Vector3.new(p.X, 300, p.Z), Vector3.new(0, -600, 0), terrainWater)
		if not hit or hit.Material ~= Enum.Material.Water then
			return last
		end
		last = d
	end
	return last
end

local function strip(parent: Instance, minX: number, maxX: number, minZ: number, maxZ: number)
	-- le Part arrivano a 2048 studs: la misura vera la da' la mesh
	local part = Instance.new("Part")
	part.Name = "Mare"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Glass
	part.Color = COLOR
	part.Reflectance = 0
	part.Size = Vector3.new(16, 1, 16)
	part.CFrame = CFrame.new((minX + maxX) / 2, SURFACE - 0.5, (minZ + maxZ) / 2)
	local mesh = Instance.new("BlockMesh")
	mesh.Scale = Vector3.new((maxX - minX) / 16, 1, (maxZ - minZ) / 16)
	mesh.Parent = part
	part.Parent = parent
end

function Ocean.setup()
	local old = workspace:FindFirstChild("Oceano")
	if old then
		old:Destroy()
	end
	local ex = math.min(waterEdge(Vector3.xAxis, 4000), waterEdge(-Vector3.xAxis, 4000))
	local ez = math.min(waterEdge(Vector3.zAxis, 3000), waterEdge(-Vector3.zAxis, 3000))
	if ex <= 4000 or ez <= 3000 then
		return -- mappa non generata o mare diverso dal previsto: meglio niente che un mare storto
	end
	local model = Instance.new("Model")
	model.Name = "Oceano"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	-- un po' dentro il mare vero, per non lasciare fessure (sotto l'acqua non si vede)
	ex -= 8
	ez -= 8
	strip(model, -REACH, REACH, ez, REACH) -- nord
	strip(model, -REACH, REACH, -REACH, -ez) -- sud
	strip(model, ex, REACH, -ez, ez) -- est
	strip(model, -REACH, -ex, -ez, ez) -- ovest
	model.Parent = workspace
end

return Ocean
