--!strict
-- Giacimenti di minerali sulle pareti delle caverne-miniera e delle stanze in fondo ai
-- cunicoli. Il tipo dipende dalla quota: piu' sali, piu' e' raro e prezioso.
-- Ogni giacimento ha il tag "OreNode" e gli attributi "OreType" e "Amount" (colpi di piccone):
-- il server (Mining) li trova con CollectionService.
-- Modello: se in ServerStorage o Workspace c'e' un Model "piedras" (il kit dei minerali) o
-- "Minerale", usa quello ricolorato; altrimenti blocchi e cristalli fatti con Part.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Heightmap = require(script.Parent.Heightmap)

local Ores = {}

type OreType = { name: string, color: Color3, material: Enum.Material, glow: Color3?, minFrac: number, maxFrac: number }

local TYPES: { OreType } = {
	{ name = "Carbone", color = Color3.fromRGB(38, 38, 42), material = Enum.Material.Basalt, minFrac = 0, maxFrac = 0.2 },
	{ name = "Ferro", color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Metal, minFrac = 0, maxFrac = 0.3 },
	{ name = "Oro", color = Color3.fromRGB(255, 176, 0), material = Enum.Material.Metal, minFrac = 0.15, maxFrac = 0.45 },
	{
		name = "Cristallo",
		color = Color3.fromRGB(0, 230, 255),
		material = Enum.Material.Glass,
		glow = Color3.fromRGB(80, 220, 255),
		minFrac = 0.3,
		maxFrac = 0.65,
	},
	{
		name = "Rubino",
		color = Color3.fromRGB(230, 20, 30),
		material = Enum.Material.Glass,
		glow = Color3.fromRGB(255, 60, 60),
		minFrac = 0.45,
		maxFrac = 0.8,
	},
	{
		name = "Cosmico",
		color = Color3.fromRGB(255, 0, 191),
		material = Enum.Material.Neon,
		glow = Color3.fromRGB(220, 60, 255),
		minFrac = 0.6,
		maxFrac = 2,
	},
}

local function typeFor(frac: number, rng: Random): OreType
	local options = {}
	for _, t in TYPES do
		if frac >= t.minFrac and frac <= t.maxFrac then
			table.insert(options, t)
		end
	end
	if #options == 0 then
		return TYPES[#TYPES]
	end
	return options[rng:NextInteger(1, #options)]
end

-- Modello del kit: il "piedras" piu' grande che troviamo, ripulito da script e rig di animazione
local function loadTemplate(): Model?
	local best: Model? = nil
	local bestSize = 0
	for _, container in { ServerStorage, workspace } do
		for _, d in container:GetDescendants() do
			if d:IsA("Model") and (d.Name == "piedras" or d.Name == "Minerale") and d:FindFirstChildWhichIsA("BasePart") then
				local _, size = d:GetBoundingBox()
				if size.Magnitude > bestSize then
					best, bestSize = d, size.Magnitude
				end
			end
		end
	end
	if not best then
		return nil
	end
	local model = (best :: Model):Clone()
	for _, d in model:GetDescendants() do
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("Humanoid")
			or d:IsA("JointInstance")
			or d:IsA("ObjectValue")
			or (d:IsA("BasePart") and d.Name == "HumanoidRootPart")
		then
			d:Destroy()
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = true
		end
	end
	local cf = model:GetBoundingBox()
	model.WorldPivot = cf
	return model
end

local function addGlow(p: BasePart, ore: OreType)
	if ore.glow then
		local light = Instance.new("PointLight")
		light.Color = ore.glow
		light.Range = 16
		light.Brightness = 1.4
		light.Parent = p
	end
end

local function fromTemplate(template: Model, base: CFrame, ore: OreType, rng: Random): Model
	local model = template:Clone()
	local _, size = model:GetBoundingBox()
	local target = rng:NextNumber(5, 8)
	model:ScaleTo(model:GetScale() * target / math.max(size.X, size.Y, size.Z, 0.1))
	model:PivotTo(base * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28)))
	local first: BasePart? = nil
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Color = ore.color
			if ore.glow then
				p.Material = ore.material
			end
			first = first or p
		end
	end
	if first then
		addGlow(first, ore)
	end
	return model
end

local function fromParts(base: CFrame, ore: OreType, rng: Random): Model
	local model = Instance.new("Model")
	local crystal = ore.glow ~= nil
	for k = 1, 4 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.Material = ore.material
		p.Color = ore.color
		if crystal then
			-- cristalli allungati che spuntano dalla roccia
			p.Size = Vector3.new(rng:NextNumber(0.6, 1.2), rng:NextNumber(0.6, 1.2), rng:NextNumber(2.5, 5))
			p.CFrame = base * CFrame.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1.5, 1.5), -1)
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5), 0)
			p.Transparency = if ore.material == Enum.Material.Glass then 0.2 else 0
		else
			-- blocchi di minerale incastrati nella parete
			p.Size = Vector3.new(rng:NextNumber(1.5, 2.8), rng:NextNumber(1.2, 2.2), rng:NextNumber(1.2, 2))
			p.CFrame = base * CFrame.new(rng:NextNumber(-1.8, 1.8), rng:NextNumber(-1.2, 1.2), 0.3)
				* CFrame.Angles(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		end
		p.Parent = model
		if k == 1 then
			model.PrimaryPart = p
			addGlow(p, ore)
		end
	end
	return model
end

-- Cerca la parete della caverna partendo dal centro; se non la trova usa il raggio atteso
local function wallPoint(center: Vector3, dir: Vector3, radius: number, params: RaycastParams): (Vector3, Vector3)
	local hit = workspace:Raycast(center, dir * radius * 1.6, params)
	if hit then
		return hit.Position, hit.Normal
	end
	return center + dir * radius * 0.85, -dir
end

function Ores.place(map: Heightmap.Map)
	local old = workspace:FindFirstChild("Ores")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Ores"
	folder.Parent = workspace
	local rng = Random.new(map.cfg.SEED + 55)
	local H = map.cfg.MOUNTAIN.HEIGHT
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local template = loadTemplate()
	print("[MapGen] Minerali: " .. (if template then "uso il modello del kit (piedras)" else "blocchi a Part"))

	local function around(x: number, y: number, z: number, radius: number, count: number)
		local center = Vector3.new(x, y, z)
		local ore = typeFor(y / H, rng)
		for k = 1, count do
			local a = (k / count) * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
			local dir = Vector3.new(math.cos(a), rng:NextNumber(-0.1, 0.35), math.sin(a)).Unit
			local pos, normal = wallPoint(center, dir, radius, params)
			if rng:NextNumber() < 0.35 then
				ore = typeFor(y / H, rng) -- a volte un minerale diverso nella stessa caverna
			end
			-- mezzo incastrato nella roccia
			local base = CFrame.lookAt(pos - normal * 1.2, pos - normal * 1.2 + normal)
			local model = if template then fromTemplate(template, base, ore, rng) else fromParts(base, ore, rng)
			model.Name = "Ore_" .. ore.name
			CollectionService:AddTag(model, "OreNode")
			local amount = rng:NextInteger(3, 7)
			model:SetAttribute("OreType", ore.name)
			model:SetAttribute("Amount", amount)
			model:SetAttribute("MaxAmount", amount)
			model.Parent = folder
		end
	end

	for _, c in map.features.mineChambers or {} do
		around(c.x, c.y + 4, c.z, c.radius, 7)
	end
	for _, r in map.features.oreRooms or {} do
		around(r.x, r.y + 5, r.z, 12, 2)
	end
	-- stanze lungo la galleria: giacimenti e una luce calda, cosi' si vedono dal tunnel
	for _, r in map.features.tunnelRooms or {} do
		around(r.x, r.y + 4, r.z, r.radius, 4)
		local lamp = Instance.new("Part")
		lamp.Name = "LuceStanza"
		lamp.Anchored, lamp.CanCollide, lamp.CanQuery, lamp.CanTouch = true, false, false, false
		lamp.Transparency = 1
		lamp.Size = Vector3.one
		lamp.Position = Vector3.new(r.x, r.y + 8, r.z)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 190, 120)
		light.Range = math.min(r.radius * 1.6, 40)
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = lamp
		lamp.Parent = folder
	end
end

return Ores
