--!strict
-- Crea lo SpawnLocation e dei marker invisibili nei punti importanti della mappa
-- (workspace.MapMarkers). Gli script di gioco li useranno per checkpoint, minerali,
-- boss, suoni delle cascate, ecc. senza dover ricalcolare nulla.

local Heightmap = require(script.Parent.Heightmap)

local Markers = {}

local function marker(parent: Instance, name: string, p: Heightmap.Point, kind: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(4, 4, 4)
	part.Position = Vector3.new(p.x, p.y + 2, p.z)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part:SetAttribute("Kind", kind)
	part.Parent = parent
	return part
end

local function group(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Markers.place(map: Heightmap.Map)
	local old = workspace:FindFirstChild("MapMarkers")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "MapMarkers"
	local f = map.features

	-- Spawn principale al centro del cerchio delle tende (lato mare del falo').
	-- Il server comunque appoggia il personaggio sul terreno vero con un raycast.
	local camp = f.campCenter or f.hub
	local sx, sz = camp.x - 16, camp.z
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(sx, Heightmap.sampleH(map, sx, sz) + 0.6, sz)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(96, 98, 100)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = root

	-- Vetta: spiazzo d'erba con bandiera (easter egg)
	local summit = marker(root, "Summit", f.summit, "Summit")
	local pole = Instance.new("Part")
	pole.Name = "SummitFlagPole"
	pole.Size = Vector3.new(0.6, 14, 0.6)
	-- sul bordo del pianoro: al centro c'e' il santuario con l'altare (Landmarks)
	local edge = (f.summit.radius or 0) * 0.85
	pole.Position = Vector3.new(f.summit.x + edge, f.summit.y + 7, f.summit.z)
	pole.Anchored = true
	pole.Material = Enum.Material.Wood
	pole.Color = Color3.fromRGB(90, 66, 44)
	pole.Parent = summit
	local flag = Instance.new("Part")
	flag.Name = "SummitFlag"
	flag.Size = Vector3.new(5, 3, 0.2)
	flag.Position = pole.Position + Vector3.new(2.8, 5, 0)
	flag.Anchored = true
	flag.Material = Enum.Material.Fabric
	flag.Color = Color3.fromRGB(196, 40, 28)
	flag.Parent = summit

	-- Anfratto segreto con un cristallo luminoso (collezionabile segnaposto)
	if f.niche then
		local niche = marker(root, "SecretNiche", f.niche, "Secret")
		local crystal = Instance.new("Part")
		crystal.Name = "SecretCrystal"
		crystal.Size = Vector3.new(1.5, 3, 1.5)
		crystal.CFrame = CFrame.new(f.niche.x, f.niche.y + 1.5, f.niche.z) * CFrame.Angles(0.3, 0.5, 0.2)
		crystal.Anchored = true
		crystal.CanCollide = false
		crystal.Material = Enum.Material.Neon
		crystal.Color = Color3.fromRGB(90, 220, 255)
		crystal:SetAttribute("Collectible", "SecretNiche")
		crystal.Parent = niche
	end

	for _, name in { "lake", "caveEntrance", "caveWindow", "caveExit", "catacomb", "catacombShaft" } do
		if f[name] then
			marker(root, name:sub(1, 1):upper() .. name:sub(2), f[name], name)
		end
	end

	local lists = {
		{ "Rivers", f.rivers, "River" },
		{ "Waterfalls", f.falls, "Waterfall" },
		{ "OreRooms", f.oreRooms, "OreRoom" },
		{ "SecretExits", f.secretExits, "SecretExit" },
		{ "IceCaves", f.iceCaves, "IceCave" },
		{ "PathPoints", f.path, "PathPoint" },
		{ "BaseCamps", f.camps, "BaseCamp" },
		{ "CaveEntrances", f.caveEntrances, "CaveEntrance" },
		{ "MineChambers", f.mineChambers, "MineChamber" },
		{ "Ponds", f.ponds, "Pond" },
	}
	for _, entry in lists do
		local folder = group(root, entry[1])
		for k, p in entry[2] or {} do
			if entry[3] == "River" then
				local m = marker(folder, p.name, p.source, "RiverSource")
				m:SetAttribute("MouthPosition", Vector3.new(p.mouth.x, p.mouth.y, p.mouth.z))
			elseif entry[3] == "Waterfall" then
				local m = marker(folder, "Waterfall" .. k, { x = p.x, y = p.bottom, z = p.z }, "Waterfall")
				m:SetAttribute("Height", p.top - p.bottom)
			else
				marker(folder, entry[3] .. k, p, entry[3])
			end
		end
	end

	local gaps = group(root, "PathGaps")
	for k, g in f.gaps or {} do
		if g.from then
			local m = marker(gaps, "Gap" .. k, g.from, "PathGap")
			m:SetAttribute("GapKind", g.kind)
			if g.to then
				m:SetAttribute("Landing", Vector3.new(g.to.x, g.to.y, g.to.z))
			end
		end
	end

	root.Parent = workspace
end

return Markers
