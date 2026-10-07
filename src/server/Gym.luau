--!strict
-- Palestra "Muscle Beach" (come quella di Venice Beach): spiaggia di sabbia, palme, attrezzi
-- da allenamento. Ogni esercizio (tieni premuto il prompt) da' punti Fitness: ogni 5 punti un
-- livello, e ogni livello toglie l'1% di fatica in arrampicata e nella corsa (fino al 40%).
-- Posizione: una Part (o un Model) chiamata "Gym" nel Workspace, messa da Mirko a mano: la
-- palestra si costruisce li' e la Part sparisce. Se non c'e', un prato piano lontano da tutto.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Gym = {}

Gym.MAX_LEVEL = 40
Gym.XP_PER_LEVEL = 5

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function groundAt(p: Vector3): Vector3
	local hit = workspace:Raycast(Vector3.new(p.X, p.Y + 300, p.Z), Vector3.new(0, -800, 0), terrainOnly)
	return if hit then hit.Position else p
end

local IRON = Color3.fromRGB(52, 54, 60)
local CHROME = Color3.fromRGB(190, 192, 198)
local RED = Color3.fromRGB(200, 50, 45)
local WOOD = Color3.fromRGB(150, 110, 70)
local TEAL = Color3.fromRGB(40, 170, 170)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- bilanciere: sbarra cromata e due dischi per lato
local function barbell(parent: Instance, cf: CFrame, len: number)
	part(parent, "Sbarra", Vector3.new(len, 0.35, 0.35), cf * CFrame.Angles(0, 0, 0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, s in { -1, 1 } do
		for k = 0, 1 do
			part(parent, "Disco", Vector3.new(0.5, 2.6 - k * 0.6, 2.6 - k * 0.6), cf * CFrame.new(s * (len / 2 - 0.6 - k * 0.55), 0, 0), if k == 0 then RED else IRON, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	end
end

local function palm(parent: Instance, base: Vector3, rng: Random)
	local h = rng:NextNumber(18, 28)
	local lean = CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6.28), rng:NextNumber(-0.15, 0.15))
	local cf = CFrame.new(base) * lean
	for k = 0, 5 do
		part(parent, "Tronco", Vector3.new(h / 6 + 0.4, 1.3 - k * 0.08, 1.3 - k * 0.08), cf * CFrame.new(0, h * (k + 0.5) / 6, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(130, 100, 70), Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	local top = cf * CFrame.new(0, h, 0)
	for k = 0, 6 do
		local a = k / 7 * 2 * math.pi
		local leaf = part(parent, "Foglia", Vector3.new(1.6, 0.3, 9), top * CFrame.Angles(0, a, 0) * CFrame.new(0, -0.6, -4) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(60, 140, 60), Enum.Material.Grass)
		leaf.CanCollide = false
	end
end

-- prompt di un attrezzo
local function station(parent: Instance, anchor: BasePart, action: string, name: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = name
	prompt.HoldDuration = 3
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	CollectionService:AddTag(anchor, "GymStation")
	local _ = parent
end

local function build(center: Vector3, facing: Vector3): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Palestra"
	local rng = Random.new(77)
	local T = workspace.Terrain
	-- spiaggia piatta
	T:FillCylinder(CFrame.new(center - Vector3.new(0, 5, 0)), 10, 70, Enum.Material.Sand)
	T:FillCylinder(CFrame.new(center + Vector3.new(0, 30, 0)), 60, 70, Enum.Material.Air)
	local look = CFrame.lookAt(center, center + facing)
	local function at(x: number, z: number): CFrame
		return look * CFrame.new(x, 0, z)
	end
	-- pedana di gomma con il recinto basso (come la gabbia di Muscle Beach)
	part(folder, "Pedana", Vector3.new(56, 0.6, 40), at(0, 0) * CFrame.new(0, 0.3, 0), Color3.fromRGB(60, 60, 66), Enum.Material.Rubber)
	for _, side in { -1, 1 } do
		part(folder, "Ringhiera", Vector3.new(56, 0.3, 0.3), at(0, side * 20) * CFrame.new(0, 3.2, 0), CHROME, Enum.Material.Metal)
		part(folder, "Ringhiera", Vector3.new(0.3, 0.3, 40), at(side * 28, 0) * CFrame.new(0, 3.2, 0), CHROME, Enum.Material.Metal)
	end
	for _, x in { -28, -14, 14, 28 } do
		for _, z in { -20, 20 } do
			part(folder, "Paletto", Vector3.new(0.4, 3.4, 0.4), at(x, z) * CFrame.new(0, 1.7, 0), CHROME, Enum.Material.Metal)
		end
	end
	-- panca piana con bilanciere
	local bench = part(folder, "Panca", Vector3.new(2.2, 1.6, 7), at(-16, -8) * CFrame.new(0, 1.4, 0), TEAL, Enum.Material.Fabric)
	for _, z in { -2.8, 2.8 } do
		part(folder, "Gamba", Vector3.new(1.6, 1.4, 0.4), at(-16, -8 + z) * CFrame.new(0, 0.7, 0), IRON, Enum.Material.Metal)
	end
	for _, x in { -2.4, 2.4 } do
		part(folder, "Supporto", Vector3.new(0.4, 4.6, 0.4), at(-16 + x, -11) * CFrame.new(0, 2.3, 0), IRON, Enum.Material.Metal)
	end
	barbell(folder, at(-16, -11) * CFrame.new(0, 4.3, 0), 8)
	station(folder, bench, "Bench press", "Bench")
	-- sbarra per le trazioni e anelli
	for _, x in { -3.5, 3.5 } do
		part(folder, "Montante", Vector3.new(0.5, 10, 0.5), at(x, 10) * CFrame.new(0, 5, 0), IRON, Enum.Material.Metal)
	end
	local pull = part(folder, "Sbarra", Vector3.new(7.5, 0.4, 0.4), at(0, 10) * CFrame.new(0, 9.6, 0), CHROME, Enum.Material.Metal)
	station(folder, pull, "Pull-ups", "Pull-up bar")
	for _, x in { -1.5, 1.5 } do
		part(folder, "Corda", Vector3.new(0.15, 3, 0.15), at(x, 10) * CFrame.new(0, 8, 0), Color3.fromRGB(200, 180, 140), Enum.Material.Fabric)
		part(folder, "Anello", Vector3.new(0.3, 1.2, 1.2), at(x, 10) * CFrame.new(0, 6.4, 0) * CFrame.Angles(0, math.pi / 2, 0), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	-- rastrelliera di manubri
	local rack = part(folder, "Rastrelliera", Vector3.new(9, 2.4, 2), at(16, -10) * CFrame.new(0, 1.2, 0), IRON, Enum.Material.Metal)
	for k = 0, 4 do
		local x = 16 - 3.6 + k * 1.8
		part(folder, "Manubrio", Vector3.new(1.4, 0.3, 0.3), at(x, -10) * CFrame.new(0, 2.6, 0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
		for _, s in { -0.6, 0.6 } do
			part(folder, "Peso", Vector3.new(0.35, 0.8 + k * 0.1, 0.8 + k * 0.1), at(x + s, -10) * CFrame.new(0, 2.6, 0), IRON, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	end
	station(folder, rack, "Dumbbell curls", "Dumbbells")
	-- squat rack
	for _, x in { -3, 3 } do
		for _, z in { -1.5, 1.5 } do
			part(folder, "Montante", Vector3.new(0.4, 8, 0.4), at(16 + x, 8 + z) * CFrame.new(0, 4, 0), RED, Enum.Material.Metal)
		end
	end
	local squat = part(folder, "Base", Vector3.new(7, 0.4, 4), at(16, 8) * CFrame.new(0, 0.8, 0), IRON, Enum.Material.Metal)
	barbell(folder, at(16, 8) * CFrame.new(0, 5.5, 0), 9)
	station(folder, squat, "Squats", "Squat rack")
	-- palo con la corda da arrampicata (la stamina di chi scala!)
	part(folder, "Palo", Vector3.new(1, 22, 1), at(-16, 10) * CFrame.new(0, 11, 0), WOOD, Enum.Material.Wood)
	part(folder, "Braccio", Vector3.new(4, 0.6, 0.6), at(-15, 10) * CFrame.new(0, 21.5, 0), WOOD, Enum.Material.Wood)
	local rope = part(folder, "Corda", Vector3.new(0.4, 20, 0.4), at(-13.4, 10) * CFrame.new(0, 11.4, 0), Color3.fromRGB(200, 180, 140), Enum.Material.Fabric)
	station(folder, rope, "Rope climb", "Climbing rope")
	-- sacco da boxe
	part(folder, "Gancio", Vector3.new(4, 0.5, 0.5), at(0, -12) * CFrame.new(0, 9, 0), IRON, Enum.Material.Metal)
	part(folder, "Palo", Vector3.new(0.5, 9, 0.5), at(-2, -12) * CFrame.new(0, 4.5, 0), IRON, Enum.Material.Metal)
	local bag = part(folder, "Sacco", Vector3.new(4.5, 2.2, 2.2), at(1, -12) * CFrame.new(0, 5.6, 0) * CFrame.Angles(0, 0, math.pi / 2), RED, Enum.Material.Leather, Enum.PartType.Cylinder)
	station(folder, bag, "Box", "Punching bag")
	-- insegna e palme
	local sign = part(folder, "Insegna", Vector3.new(18, 4, 0.4), at(0, -22) * CFrame.new(0, 9, 0), Color3.fromRGB(30, 30, 36), Enum.Material.SmoothPlastic)
	for _, x in { -8, 8 } do
		part(folder, "PaloInsegna", Vector3.new(0.5, 9, 0.5), at(x, -22) * CFrame.new(0, 4.5, 0), IRON, Enum.Material.Metal)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Color3.fromRGB(255, 200, 80)
	label.Text = "MUSCLE BEACH\n<font size=\"22\" color=\"#9fe8e8\">train here · climb longer</font>"
	label.Parent = gui
	for _ = 1, 9 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(36, 60)
		palm(folder, groundAt(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)), rng)
	end
	folder.Parent = workspace
	return folder
end

-- dove: la Part "Gym" di Mirko, se no un prato piano lontano da campo base, arena e montagna
local function findSpot(): (Vector3, Vector3)
	for _, d in workspace:GetDescendants() do
		if string.lower(d.Name) == "gym" and (d:IsA("BasePart") or d:IsA("Model")) then
			local cf = if d:IsA("BasePart") then d.CFrame else (d :: Model):GetPivot()
			for _, p in (if d:IsA("Model") then d:GetDescendants() else { d }) :: { Instance } do
				if p:IsA("BasePart") then
					p.Transparency = 1
					p.CanCollide = false
					p.CanQuery = false
				end
			end
			local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
			return groundAt(cf.Position), if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
		end
	end
	local hubM = workspace:FindFirstChild("MapMarkers") and (workspace :: any).MapMarkers:FindFirstChild("HubSpawn")
	local hub = if hubM then hubM.Position else Vector3.zero
	local best, bestScore = hub + Vector3.new(250, 0, 0), math.huge
	for k = 0, 35 do
		local a = k / 36 * 2 * math.pi
		for _, r in { 260, 340, 420 } do
			local p = groundAt(hub + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			local hit = workspace:Raycast(p + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), terrainOnly)
			if hit and hit.Material ~= Enum.Material.Water and hit.Normal.Y > 0.95 then
				local score = math.abs(p.Y - hub.Y) + r * 0.05
				if score < bestScore then
					best, bestScore = p, score
				end
			end
		end
	end
	return best, (hub - best).Unit * Vector3.new(1, 0, 1)
end

function Gym.setup()
	task.spawn(function()
		workspace:WaitForChild("MapMarkers", 30)
		local center, facing = findSpot()
		build(center, if facing.Magnitude > 0.1 then facing.Unit else Vector3.zAxis)
		workspace:SetAttribute("GymCenter", center)
		local last: { [Player]: number } = {}
		local function bind(anchor: Instance)
			local prompt = anchor:FindFirstChildOfClass("ProximityPrompt")
			if not prompt then
				return
			end
			prompt.Triggered:Connect(function(player: Player)
				if os.clock() - (last[player] or 0) < 2 then
					return
				end
				last[player] = os.clock()
				local level = (player:GetAttribute("Fitness") or 0) :: number
				if level >= Gym.MAX_LEVEL then
					player:SetAttribute("Notice", "Max fitness! You're a climbing machine")
					player:SetAttribute("NoticeTime", os.clock())
					return
				end
				local xp = ((player:GetAttribute("FitnessXP") or 0) :: number) + 1
				if xp >= Gym.XP_PER_LEVEL then
					xp = 0
					level += 1
					player:SetAttribute("Fitness", level)
					player:SetAttribute("Notice", string.format("Fitness %d! Climbing tires you %d%% less", level, level))
				else
					player:SetAttribute("Notice", string.format("+1 rep (%d/%d to the next Fitness level)", xp, Gym.XP_PER_LEVEL))
				end
				player:SetAttribute("NoticeTime", os.clock())
				player:SetAttribute("FitnessXP", xp)
			end)
		end
		for _, a in CollectionService:GetTagged("GymStation") do
			bind(a)
		end
		Players.PlayerRemoving:Connect(function(p)
			last[p] = nil
		end)
	end)
end

return Gym
