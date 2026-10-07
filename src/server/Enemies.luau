--!strict
-- Nemici: yeti in alta quota (sorvegliano le uova) e golem di ghiaccio sui ghiacciai e nelle
-- grotte di ghiaccio. Valori in shared/EnemyConfig, modelli in ServerStorage.Nemici.
--   * stanno attorno alla loro tana; se un giocatore si avvicina lo inseguono (ma non oltre
--     "leash" dalla tana) e lo colpiscono quando e' a tiro (spinta e scossa per il golem)
--   * si colpiscono cliccando con Piccozza o Piccone vicino a loro (evento "EnemyHit"); il drago
--     al seguito aiuta con un colpo del suo elemento ogni qualche secondo
--   * sconfitti: monete ed esperienza ai draghi di chi li ha colpiti; poi ne ricompare uno
-- Si muovono con un Humanoid (fisica sul server, movimento fluido per tutti i client).
-- Effetti sul client (client/EnemyClient) con l'evento "EnemyFX".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local EnemyConfig = require(ReplicatedStorage.Shared.EnemyConfig)
local ClimbConfig = require(ReplicatedStorage.Shared.ClimbConfig)
local Dragons = require(script.Parent.Dragons)
local Economy = require(script.Parent.Economy)
local Survival = require(script.Parent.Survival)

local Enemies = {}

type Enemy = {
	kind: string,
	def: EnemyConfig.EnemyType,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	home: Vector3,
	target: Player?,
	lastAttack: number,
	nextWander: number,
	tracks: { walk: AnimationTrack?, idle: AnimationTrack?, attack: AnimationTrack?, sit: AnimationTrack? },
	damagedBy: { [Player]: number },
	dead: boolean,
	boss: EnemyConfig.Boss?,
	seated: boolean?,
	homeCF: CFrame?,
}

local enemies: { Enemy } = {}
local folder: Folder
local fxEvent: RemoteEvent

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function ground(x: number, z: number, fromY: number?): RaycastResult?
	return workspace:Raycast(Vector3.new(x, fromY or 6000, z), Vector3.new(0, -7000, 0), terrainOnly)
end

------------------------------------------------------------------------------------------
-- Animazioni: in Studio i salvataggi dell'editor, nel gioco pubblicato gli ID di EnemyConfig

local animCache: { [string]: string | false } = {}
local function animId(kind: string, which: string): string?
	local published = EnemyConfig.ANIMS[kind]
	if published and (published :: any)[which] and (published :: any)[which] ~= "" then
		return (published :: any)[which]
	end
	local key = kind .. "/" .. which
	if animCache[key] ~= nil then
		return animCache[key] or nil
	end
	animCache[key] = false
	if RunService:IsStudio() then
		local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
		local set = saves and saves:FindFirstChild(kind)
		local names = { walk = "nemico-cammina", idle = "nemico-fermo", attack = "nemico-attacco", sit = "nemico-seduto" }
		local kfs = set and set:FindFirstChild(names[which])
		if kfs and kfs:IsA("KeyframeSequence") then
			local ok, id = pcall(function()
				return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
			end)
			if ok then
				animCache[key] = id
			end
		end
	end
	return animCache[key] or nil
end

------------------------------------------------------------------------------------------
-- Modello pronto per muoversi: radice invisibile che fa da corpo fisico, la mesh saldata sopra

local function build(kind: string, def: EnemyConfig.EnemyType, at: Vector3): Enemy?
	local templates = ServerStorage:FindFirstChild("Nemici")
	local template = templates and templates:FindFirstChild(kind)
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("AnimationController") or d:IsA("ObjectValue") then
			d:Destroy()
		end
	end
	local _, size0 = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * def.height / size0.Y)
	local cf, size = model:GetBoundingBox()
	local hip = size.Y * 0.3
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(size.X * 0.45, size.Y * 0.5, size.Z * 0.45)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 + hip + root.Size.Y / 2, cf.Position.Z)
	root.Parent = model
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			if d ~= root then
				d.CanCollide = false
				d.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- cosi' conta HipHeight
	humanoid.HipHeight = hip
	humanoid.WalkSpeed = def.speed
	humanoid.MaxHealth = def.health
	humanoid.Health = def.health
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	model.Name = kind
	model:SetAttribute("Enemy", kind)
	model:PivotTo(CFrame.new(at + Vector3.new(0, size.Y / 2 + 1, 0)) * CFrame.Angles(0, math.random() * 6.28, 0))

	-- barra della vita sopra la testa
	local bill = Instance.new("BillboardGui")
	bill.Name = "BarraVita"
	bill.Size = UDim2.fromOffset(150, 34)
	bill.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.62, 0)
	bill.MaxDistance = 120
	bill.Adornee = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 16)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(235, 245, 255)
	label.TextStrokeTransparency = 0.3
	label.Text = def.name
	label.Parent = bill
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0, 19)
	back.Size = UDim2.new(1, 0, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(25, 20, 24)
	back.BorderSizePixel = 0
	back.Parent = bill
	local fill = Instance.new("Frame")
	fill.Name = "Vita"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 70, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back
	bill.Parent = model
	humanoid.HealthChanged:Connect(function(h)
		fill.Size = UDim2.fromScale(math.clamp(h / def.health, 0, 1), 1)
	end)

	model.Parent = folder
	root:SetNetworkOwner(nil) -- l'intelligenza e' sul server

	local function load(which: string, looped: boolean): AnimationTrack?
		local id = animId(kind, which)
		if not id then
			return nil
		end
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if not ok then
			return nil
		end
		track.Looped = looped
		track.Priority = if which == "attack" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Movement
		return track
	end
	local enemy: Enemy = {
		kind = kind,
		def = def,
		model = model,
		humanoid = humanoid,
		root = root,
		home = at,
		target = nil,
		lastAttack = 0,
		nextWander = os.clock() + math.random() * 4,
		tracks = { walk = load("walk", true), idle = load("idle", true), attack = load("attack", false), sit = load("sit", true) },
		damagedBy = {},
		dead = false,
	}
	if enemy.tracks.idle then
		(enemy.tracks.idle :: AnimationTrack):Play(0.2)
	end
	if enemy.tracks.walk then
		(enemy.tracks.walk :: AnimationTrack):Play(0.2, 0.01)
	end
	return enemy
end

------------------------------------------------------------------------------------------
-- Dove vivono

local function mountainSpots(def: EnemyConfig.EnemyType, count: number, accept: (RaycastResult) -> boolean): { Vector3 }
	local mapGen = ServerStorage:FindFirstChild("MapGen")
	local cfgModule = mapGen and mapGen:FindFirstChild("Config")
	local M = if cfgModule then (require :: any)(cfgModule).MOUNTAIN else { X = 1300, Z = 0, RADIUS = 2300 }
	local spots = {}
	local tries = 0
	while #spots < count and tries < 3000 do
		tries += 1
		if tries % 60 == 0 then
			task.wait() -- senza pause lo script andava in timeout e bloccava tutto il server
		end
		local a = math.random() * 2 * math.pi
		local r = M.RADIUS * (0.1 + math.random() * 0.75)
		local hit = ground(M.X + math.cos(a) * r, M.Z + math.sin(a) * r)
		if hit and hit.Normal.Y > 0.78 and accept(hit) then
			local far = true
			for _, s in spots do
				if (s - hit.Position).Magnitude < 150 then
					far = false
				end
			end
			if far then
				table.insert(spots, hit.Position)
			end
		end
	end
	return spots
end

local function spawnFor(kind: string): Vector3?
	local def = EnemyConfig.TYPES[kind]
	local list
	if kind == "Yeti" then
		-- neve in quota, dove si trovano le uova del sole, del gelo e delle stelle
		list = mountainSpots(def, 1, function(hit)
			return hit.Position.Y > ClimbConfig.SNOW_LINE and hit.Position.Y < 3600 and (hit.Material == Enum.Material.Snow or hit.Material == Enum.Material.Rock or hit.Material == Enum.Material.Slate)
		end)
	else
		-- ghiacciai, e meta' delle volte una grotta di ghiaccio
		local markers = workspace:FindFirstChild("MapMarkers")
		local caves = markers and markers:FindFirstChild("IceCaves")
		if caves and #caves:GetChildren() > 0 and math.random() < 0.5 then
			local c = caves:GetChildren()[math.random(1, #caves:GetChildren())]
			if c:IsA("BasePart") then
				return c.Position
			end
		end
		list = mountainSpots(def, 1, function(hit)
			return hit.Material == Enum.Material.Glacier
		end)
	end
	return list[1]
end

------------------------------------------------------------------------------------------
-- Combattimento

local function giveRewards(enemy: Enemy)
	local total = 0
	for _, dmg in enemy.damagedBy do
		total += dmg
	end
	for player, dmg in enemy.damagedBy do
		if player.Parent then
			local share = dmg / math.max(total, 1)
			Economy.addCoins(player, math.max(1, math.floor(enemy.def.coins * share + 0.5)))
			for _, d in Dragons.equippedDragons(player) do
				Dragons.addXp(player, d.id, math.max(1, math.floor(enemy.def.xp * share + 0.5)))
			end
			fxEvent:FireClient(player, "reward", enemy.root.Position, math.floor(enemy.def.coins * share + 0.5), math.floor(enemy.def.xp * share + 0.5))
		end
	end
end

local function damageEnemy(enemy: Enemy, player: Player?, amount: number)
	if enemy.dead then
		return
	end
	if player then
		enemy.damagedBy[player] = (enemy.damagedBy[player] or 0) + amount
		enemy.target = player -- chi ti colpisce diventa il bersaglio
	end
	enemy.humanoid:TakeDamage(amount)
	fxEvent:FireAllClients("hurt", enemy.model, amount)
end

local spawnBoss: (EnemyConfig.Boss) -> ()

local function die(enemy: Enemy)
	enemy.dead = true
	for _, t in enemy.tracks do
		if t then
			(t :: AnimationTrack):Stop(0.2)
		end
	end
	fxEvent:FireAllClients("death", enemy.model)
	giveRewards(enemy)
	task.delay(1.6, function()
		enemy.model:Destroy()
	end)
	local idx = table.find(enemies, enemy)
	if idx then
		table.remove(enemies, idx)
	end
	task.delay(enemy.def.respawn, function()
		if enemy.boss then
			spawnBoss(enemy.boss)
			return
		end
		local at = spawnFor(enemy.kind)
		if at then
			local e = build(enemy.kind, enemy.def, at)
			if e then
				table.insert(enemies, e)
				e.humanoid.Died:Connect(function()
					die(e)
				end)
			end
		end
	end)
end

local function attack(enemy: Enemy, player: Player)
	enemy.lastAttack = os.clock()
	local track = enemy.tracks.attack
	if track then
		(track :: AnimationTrack):Play(0.1)
	end
	fxEvent:FireAllClients("windup", enemy.model)
	task.delay(enemy.def.hitAt, function()
		if enemy.dead then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		fxEvent:FireAllClients("slam", enemy.model)
		if root and humanoid and humanoid.Health > 0 and (root.Position - enemy.root.Position).Magnitude <= enemy.def.reach * 1.35 + enemy.root.Size.X then
			Survival.damage(humanoid, enemy.def.damage, "Colpito da " .. enemy.def.name)
			local away = root.Position - enemy.root.Position
			away = Vector3.new(away.X, 0, away.Z)
			away = if away.Magnitude > 0.1 then away.Unit else enemy.root.CFrame.LookVector
			fxEvent:FireClient(player, "knock", away * enemy.def.knockback + Vector3.new(0, enemy.def.knockback * 0.45, 0))
		end
	end)
end

local function nearestPlayer(enemy: Enemy): (Player?, number)
	local best, bestDist = nil, enemy.def.aggro
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not player:GetAttribute("Filming") then
			local d = (root.Position - enemy.root.Position).Magnitude
			if d < bestDist and math.abs(root.Position.Y - enemy.root.Position.Y) < 40 then
				best, bestDist = player, d
			end
		end
	end
	return best, bestDist
end

------------------------------------------------------------------------------------------
-- Capi

-- Trono di ghiaccio su misura: il sedile all'altezza dell'anca (la posa seduta tiene ferme le
-- anche), il poggiapiedi sotto le caviglie, schienale alto con le punte
local function buildThrone(enemy: Enemy, den: CFrame)
	local H = enemy.def.height
	local hip = enemy.model:FindFirstChild("mixamorig:LeftUpLeg", true)
	local knee = enemy.model:FindFirstChild("mixamorig:LeftLeg", true)
	local ankle = enemy.model:FindFirstChild("mixamorig:LeftFoot", true)
	local hipY = if hip and hip:IsA("Bone") then hip.WorldPosition.Y else den.Y + H * 0.48
	local shin = if knee and ankle and knee:IsA("Bone") and ankle:IsA("Bone") then (knee.WorldPosition - ankle.WorldPosition).Magnitude else H * 0.25
	local ground = den.Y
	local seatTop = hipY - H * 0.05
	local feet = hipY - shin - H * 0.05
	local model = Instance.new("Model")
	model.Name = "TronoDiGhiaccio"
	local ICE = Color3.fromRGB(150, 210, 245)
	local function block(name: string, size: Vector3, cf: CFrame, collide: boolean, neon: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = collide
		p.Size = size
		p.CFrame = cf
		p.Material = if neon then Enum.Material.Neon else Enum.Material.Glass
		p.Color = if neon then Color3.fromRGB(110, 200, 255) else ICE
		p.Transparency = if neon then 0.1 else 0.15
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local function at(x: number, y: number, z: number): CFrame
		-- x = di lato, y = quota assoluta, z = avanti (verso l'uscita)
		local p = den * Vector3.new(x, 0, -z)
		return CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) + den.LookVector)
	end
	-- il trono di cristalli di Mirko (ServerStorage.Modelli "throne"): fa da sfondo e da pedana
	-- di neve; il sedile e i braccioli restano quelli qui sotto (il Re ci si siede sopra)
	local store = ServerStorage:FindFirstChild("Modelli")
	local tpl: Instance? = nil
	for _, m in (if store then store:GetChildren() else {}) :: { Instance } do
		if m:IsA("Model") and string.lower((string.gsub(m.Name, "%s", ""))) == "throne" then
			tpl = m
		end
	 end
	if tpl then
		local deco = (tpl :: Model):Clone()
		for _, d in deco:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false -- collisione a scatola: chiuderebbe il Re dentro
			end
		end
		local _, s0 = deco:GetBoundingBox()
		deco:ScaleTo(deco:GetScale() * H * 1.7 / s0.Y)
		-- dietro al Re, come sfondo (davanti lo copriva)
		deco:PivotTo(at(0, ground, -1.25 * H) * deco:GetPivot().Rotation)
		local box, s = deco:GetBoundingBox()
		deco:PivotTo(deco:GetPivot() + Vector3.new(0, ground - (box.Position.Y - s.Y / 2) - 0.3, 0))
		deco.Name = "TronoCristalli"
		deco.Parent = model
	else
		-- pedana a gradini
		block("Pedana", Vector3.new(H * 1.9, 1, H * 1.6), at(0, ground + 0.4, -0.05 * H), true)
	end
	block("Poggiapiedi", Vector3.new(H * 0.9, feet - ground, H * 0.35), at(0, (ground + feet) / 2, 0.32 * H), false)
	block("Sedile", Vector3.new(H * 0.95, seatTop - ground, H * 0.5), at(0, (ground + seatTop) / 2, -0.08 * H), false)
	block("Schienale", Vector3.new(H * 1.05, H * 1.25, H * 0.16), at(0, seatTop + H * 0.6, -0.36 * H), true)
	block("Bordo", Vector3.new(H * 1.12, H * 0.06, H * 0.2), at(0, seatTop + H * 0.06, -0.36 * H), false, true)
	for _, side in { -1, 1 } do
		block("Bracciolo", Vector3.new(H * 0.16, H * 0.3, H * 0.55), at(side * H * 0.52, seatTop + H * 0.1, -0.08 * H), true)
		if not tpl then
			block("Pilastro", Vector3.new(H * 0.22, H * 1.55, H * 0.22), at(side * H * 0.56, ground + H * 0.78 + (seatTop - ground) * 0.2, -0.36 * H), true)
		end
	end
	-- punte di ghiaccio sullo schienale (piu' alte al centro)
	for k = -3, if tpl then -4 else 3 do
		local h = H * (0.55 - math.abs(k) * 0.1)
		local spike = block("Punta", Vector3.new(H * 0.12, h, H * 0.12), at(k * H * 0.15, seatTop + H * 1.2 + h / 2, -0.36 * H) * CFrame.Angles(0, math.rad(45), math.rad(k * 6)), false)
		spike.Transparency = 0.25
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(120, 200, 255)
	glow.Range = H * 2.5
	glow.Brightness = 2
	glow.Parent = model:FindFirstChild("Schienale")
	model.Parent = folder
end

local function sit(enemy: Enemy)
	if enemy.seated or not enemy.homeCF then
		return
	end
	enemy.seated = true
	enemy.humanoid:MoveTo(enemy.root.Position)
	enemy.root.Anchored = true
	enemy.root.CFrame = enemy.homeCF :: CFrame
	if enemy.tracks.sit then
		(enemy.tracks.sit :: AnimationTrack):Play(0.6)
	end
end

local function stand(enemy: Enemy)
	if not enemy.seated then
		return
	end
	enemy.seated = false
	if enemy.tracks.sit then
		(enemy.tracks.sit :: AnimationTrack):Stop(0.4)
	end
	enemy.root.Anchored = false
end

-- Il capo nella sua tana (si riusa anche quando ricompare; dichiarato prima di die)
spawnBoss = function(def: EnemyConfig.Boss)
	local den = workspace:GetAttribute(def.den)
	if typeof(den) ~= "CFrame" then
		return
	end
	local e = build(def.kind, def, den.Position)
	if not e then
		return
	end
	e.boss = def
	e.nextWander = math.huge
	e.model:SetAttribute("Boss", true)
	if def.throne then
		-- in piedi sul punto della tana, girato verso l'uscita: da qui si misura il trono
		e.root.CFrame = CFrame.lookAt(e.root.Position, e.root.Position + den.LookVector)
		e.homeCF = e.root.CFrame
		e.home = e.root.Position
		buildThrone(e, den)
		sit(e)
	end
	table.insert(enemies, e)
	e.humanoid.Died:Connect(function()
		stand(e)
		die(e)
	end)
end

local function think(enemy: Enemy)
	if enemy.dead then
		return
	end
	if enemy.boss and enemy.boss.throne then
		-- sul trono finche' nessuno si avvicina; quando torna a casa si risiede
		local near = nearestPlayer(enemy)
		local fromHome0 = (enemy.root.Position - enemy.home).Magnitude
		if not near and not enemy.target and fromHome0 < 5 then
			sit(enemy)
			return
		end
		stand(enemy)
	end
	local fromHome = (enemy.root.Position - enemy.home).Magnitude
	-- bersaglio: chi lo ha colpito, se e' ancora vicino; altrimenti il piu' vicino a vista
	local target = enemy.target
	local targetRoot: BasePart? = nil
	if target then
		local character = target.Character
		targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if (target :: Player):GetAttribute("Filming") or not targetRoot or not humanoid or humanoid.Health <= 0 or ((targetRoot :: BasePart).Position - enemy.root.Position).Magnitude > enemy.def.aggro * 1.6 then
			target, targetRoot = nil, nil
		end
	end
	if not target then
		local p = nearestPlayer(enemy)
		target = p
		local character = p and p.Character
		targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	enemy.target = target
	if target and targetRoot and fromHome < enemy.def.leash then
		local tr = targetRoot :: BasePart
		local d = (tr.Position - enemy.root.Position).Magnitude
		if d <= enemy.def.reach + enemy.root.Size.X * 0.5 then
			enemy.humanoid:MoveTo(enemy.root.Position) -- fermo a colpire
			local look = Vector3.new(tr.Position.X, enemy.root.Position.Y, tr.Position.Z)
			enemy.root.CFrame = CFrame.lookAt(enemy.root.Position, look)
			if os.clock() - enemy.lastAttack > enemy.def.cooldown then
				attack(enemy, target :: Player)
			end
		else
			enemy.humanoid:MoveTo(tr.Position)
		end
	elseif fromHome > 14 then
		enemy.target = nil
		enemy.humanoid:MoveTo(enemy.home) -- torna alla tana (e si cura un po')
		enemy.humanoid.Health = math.min(enemy.def.health, enemy.humanoid.Health + enemy.def.health * 0.02)
	elseif os.clock() > enemy.nextWander then
		enemy.nextWander = os.clock() + 4 + math.random() * 5
		local a = math.random() * 2 * math.pi
		local r = 6 + math.random() * 18
		enemy.humanoid:MoveTo(enemy.home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
	end
	-- camminata o fermo secondo la velocita'
	local speed = Vector3.new(enemy.root.AssemblyLinearVelocity.X, 0, enemy.root.AssemblyLinearVelocity.Z).Magnitude
	local walking = speed > 1.5
	if enemy.tracks.walk then
		local w = enemy.tracks.walk :: AnimationTrack
		w:AdjustWeight(if walking then 1 else 0.01, 0.25)
		w:AdjustSpeed(math.clamp(speed / (enemy.def.speed * 0.8), 0.5, 1.6))
	end
	if enemy.tracks.idle then
		(enemy.tracks.idle :: AnimationTrack):AdjustWeight(if walking then 0.01 else 1, 0.25)
	end
end

------------------------------------------------------------------------------------------

function Enemies.setup()
	folder = Instance.new("Folder")
	folder.Name = "Nemici"
	folder.Parent = workspace
	fxEvent = Instance.new("RemoteEvent")
	fxEvent.Name = "EnemyFX"
	fxEvent.Parent = ReplicatedStorage:WaitForChild("Remotes")
	local hitEvent = Instance.new("RemoteEvent")
	hitEvent.Name = "EnemyHit"
	hitEvent.Parent = ReplicatedStorage.Remotes

	-- colpi dei giocatori: il server controlla attrezzo, distanza e ritmo
	local lastHit: { [Player]: number } = {}
	hitEvent.OnServerEvent:Connect(function(player, model)
		if typeof(model) ~= "Instance" or not model:IsDescendantOf(folder) then
			return
		end
		local now = os.clock()
		if now - (lastHit[player] or 0) < EnemyConfig.PLAYER_COOLDOWN then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local tool = character and character:FindFirstChildWhichIsA("Tool")
		local dmg = tool and EnemyConfig.PLAYER_DAMAGE[tool.Name]
		if not root or not dmg then
			return
		end
		for _, enemy in enemies do
			if enemy.model == model then
				local reach = EnemyConfig.PLAYER_REACH + enemy.root.Size.X * 0.5
				if (enemy.root.Position - (root :: BasePart).Position).Magnitude <= reach then
					lastHit[player] = now
					damageEnemy(enemy, player, dmg)
				end
				break
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
		for _, enemy in enemies do
			enemy.damagedBy[player] = nil
			if enemy.target == player then
				enemy.target = nil
			end
		end
	end)

	-- il drago al seguito aiuta: un colpo del suo elemento al nemico che ti sta addosso
	local trainingFx = ReplicatedStorage.Remotes:WaitForChild("TrainingFX", 10) :: RemoteEvent?
	task.spawn(function()
		while true do
			task.wait(EnemyConfig.DRAGON_EVERY)
			for _, enemy in enemies do
				local player = enemy.target
				if player and not enemy.dead then
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and ((root :: BasePart).Position - enemy.root.Position).Magnitude < 40 then
						for _, d in Dragons.equippedDragons(player) do
							if trainingFx then
								trainingFx:FireAllClients("hit", player.UserId, enemy.root.Position, d.element, 0)
							end
							damageEnemy(enemy, player, EnemyConfig.DRAGON_DAMAGE + 0.15 * (d.level or 1))
						end
					end
				end
			end
		end
	end)

	-- comparsa (aspetta la mappa e i marcatori)
	task.spawn(function()
		workspace:WaitForChild("MapMarkers", 30)
		for kind, def in EnemyConfig.TYPES do
			for _ = 1, def.count do
				local at = spawnFor(kind)
				if at then
					local e = build(kind, def, at)
					if e then
						table.insert(enemies, e)
						e.humanoid.Died:Connect(function()
							die(e)
						end)
					end
				end
			end
		end
		for _, def in EnemyConfig.BOSSES do
			spawnBoss(def)
		end
		print(string.format("[Nemici] %d in giro", #enemies))
		while true do
			task.wait(0.2)
			for _, enemy in table.clone(enemies) do
				local ok, err = pcall(think, enemy)
				if not ok then
					warn("[Nemici] " .. tostring(err))
				end
			end
		end
	end)
end

return Enemies
