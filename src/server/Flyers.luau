--!strict
-- Draghi volanti nemici: il drago selvatico degli eventi (WorldEvents) e il Guardiano della
-- vetta (sempre li', ricompare dopo GUARDIAN_RESPAWN secondi). Volano in tondo: il server
-- scrive solo i parametri del volo come attributi (Center, Radius, Height, Speed) e ogni client
-- li muove da se' (client/Combat), cosi' non si replica la posizione a ogni frame.
-- Sputano palle di fuoco ai giocatori vicini; si colpiscono col lancio della piccozza, il colpo
-- d'uncino, la picchiata e l'attacco speciale del drago (server/Enemies).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local DragonModels = require(script.Parent.DragonModels)
local Dragons = require(script.Parent.Dragons)
local Economy = require(script.Parent.Economy)
local Survival = require(script.Parent.Survival)
local Upgrades = require(script.Parent.Upgrades)
local Eggs = require(script.Parent.Eggs)

local Flyers = {}

export type Flyer = {
	def: UpgradeConfig.Flyer,
	model: Model,
	center: Vector3,
	health: number,
	dead: boolean,
	damagedBy: { [Player]: number },
	ends: number?, -- se ha una scadenza vola via (drago selvatico)
	fill: Frame,
	guardian: boolean,
}

local list: { Flyer } = {}
local folder: Folder
local fxEvent: RemoteEvent

local function notice(player: Player, text: string)
	player:SetAttribute("Notice", text)
	player:SetAttribute("NoticeTime", os.clock())
end

function Flyers.position(f: Flyer): Vector3
	return UpgradeConfig.flyerCFrame(f.center, f.def.radius, f.def.height, f.def.speed, workspace:GetServerTimeNow()).Position
end

-- draghi volanti vivi entro "radius" da pos (per i colpi dei giocatori)
function Flyers.near(pos: Vector3, radius: number): { Flyer }
	local out = {}
	for _, f in list do
		if not f.dead and (Flyers.position(f) - pos).Magnitude <= radius + 6 * f.def.scale then
			table.insert(out, f)
		end
	end
	return out
end

function Flyers.fromModel(model: Instance): Flyer?
	for _, f in list do
		if f.model == model or model:IsDescendantOf(f.model) then
			return f
		end
	end
	return nil
end

local function die(f: Flyer)
	f.dead = true
	local at = Flyers.position(f)
	fxEvent:FireAllClients("flyerDeath", f.model)
	local total = 0
	for _, d in f.damagedBy do
		total += d
	end
	for player, d in f.damagedBy do
		if player.Parent then
			local share = d / math.max(total, 1)
			Economy.addCoins(player, math.max(1, math.floor(f.def.coins * share + 0.5)))
			for _, dragon in Dragons.equippedDragons(player) do
				Dragons.addXp(player, dragon.id, math.max(1, math.floor(f.def.xp * share + 0.5)))
			end
			Upgrades.addStat(player, "BossKills")
			Upgrades.addStat(player, "Kills")
			notice(player, string.format("%s defeated! +%d coins", f.def.name, math.floor(f.def.coins * share + 0.5)))
		end
	end
	-- lascia un uovo raro dove cade
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(at, Vector3.new(0, -400, 0), params)
	if hit then
		pcall(Eggs.spawnAt, hit.Position + Vector3.new(0, 1, 0), f.def.element, if f.guardian then "Leggendario" else "Epico")
	end
	task.delay(2.5, function()
		f.model:Destroy()
	end)
	local idx = table.find(list, f)
	if idx then
		table.remove(list, idx)
	end
	if f.guardian then
		task.delay(UpgradeConfig.GUARDIAN_RESPAWN, function()
			Flyers.spawnGuardian()
		end)
	end
end

function Flyers.damage(f: Flyer, player: Player?, amount: number)
	if f.dead then
		return
	end
	if player then
		f.damagedBy[player] = (f.damagedBy[player] or 0) + amount
	end
	f.health -= amount
	f.fill.Size = UDim2.fromScale(math.clamp(f.health / f.def.health, 0, 1), 1)
	fxEvent:FireAllClients("flyerHurt", f.model, amount)
	if f.health <= 0 then
		die(f)
	end
end

local function spawn(def: UpgradeConfig.Flyer, center: Vector3, guardian: boolean, seconds: number?): Flyer?
	local ok, model = pcall(DragonModels.dragon, def.element, "Leggendario", 3, 30)
	if not ok or not model then
		return nil
	end
	local m = model :: Model
	m:ScaleTo(m:GetScale() * def.scale)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	m.Name = def.name
	m:SetAttribute("Flyer", true)
	m:SetAttribute("Center", center)
	m:SetAttribute("Radius", def.radius)
	m:SetAttribute("Height", def.height)
	m:SetAttribute("Speed", def.speed)
	m:PivotTo(UpgradeConfig.flyerCFrame(center, def.radius, def.height, def.speed, workspace:GetServerTimeNow()))
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	-- barra della vita
	local _, size = m:GetBoundingBox()
	local bill = Instance.new("BillboardGui")
	bill.Name = "BarraVita"
	bill.Size = UDim2.fromOffset(220, 40)
	bill.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.6, 0)
	bill.MaxDistance = 400
	bill.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 210, 120)
	label.TextStrokeTransparency = 0.3
	label.Text = def.name
	label.Parent = bill
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0, 22)
	back.Size = UDim2.new(1, 0, 0, 12)
	back.BackgroundColor3 = Color3.fromRGB(25, 20, 24)
	back.BorderSizePixel = 0
	back.Parent = bill
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(235, 90, 40)
	fill.BorderSizePixel = 0
	fill.Parent = back
	bill.Parent = m
	CollectionService:AddTag(m, "Volante")
	m.Parent = folder
	local f: Flyer = {
		def = def,
		model = m,
		center = center,
		health = def.health,
		dead = false,
		damagedBy = {},
		ends = if seconds then os.clock() + seconds else nil,
		fill = fill,
		guardian = guardian,
	}
	table.insert(list, f)
	return f
end

function Flyers.spawnWild(center: Vector3): Flyer?
	local elements = { "Brace", "Gelo", "Tempesta", "Ombra", "Cosmico", "Sole" }
	local def = table.clone(UpgradeConfig.WILD_DRAGON)
	def.element = elements[math.random(1, #elements)]
	return spawn(def, center, false, UpgradeConfig.EVENTS.RAID_SECONDS)
end

function Flyers.spawnGuardian()
	local markers = workspace:FindFirstChild("MapMarkers")
	local summit = markers and markers:FindFirstChild("Summit", true)
	if summit and summit:IsA("BasePart") then
		spawn(UpgradeConfig.GUARDIAN, summit.Position, true, nil)
	end
end

-- palla di fuoco verso un giocatore: arriva dopo 1.1 s nel punto dove era
local function attack(f: Flyer)
	local from = Flyers.position(f)
	local best, bestD = nil, 170
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and not player:GetAttribute("Filming") then
			local d = (root.Position - from).Magnitude
			if d < bestD then
				best, bestD = root, d
			end
		end
	end
	if not best then
		return
	end
	local target = (best :: BasePart).Position
	local travel = 1.1
	fxEvent:FireAllClients("fireball", from, target, f.def.element, travel)
	task.delay(travel, function()
		if f.dead then
			return
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and (root.Position - target).Magnitude < 10 then
				Survival.damage(humanoid, f.def.damage, "Burned by the " .. f.def.name)
				local away = root.Position - target
				away = Vector3.new(away.X, 0, away.Z)
				away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
				fxEvent:FireClient(player, "knock", away * 45 + Vector3.new(0, 30, 0))
			end
		end
	end)
end

function Flyers.setup()
	folder = Instance.new("Folder")
	folder.Name = "Volanti"
	folder.Parent = workspace
	fxEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EnemyFX") :: RemoteEvent
	task.defer(function()
		workspace:WaitForChild("MapMarkers", 30)
		Flyers.spawnGuardian()
	end)
	task.spawn(function()
		while true do
			task.wait(3.2)
			for _, f in table.clone(list) do
				if f.dead then
					continue
				end
				if f.ends and os.clock() > (f.ends :: number) then
					-- il drago selvatico se ne va
					f.dead = true
					local idx = table.find(list, f)
					if idx then
						table.remove(list, idx)
					end
					for player in f.damagedBy do
						notice(player, "The " .. f.def.name .. " flew away...")
					end
					fxEvent:FireAllClients("flyerLeave", f.model)
					task.delay(3, function()
						f.model:Destroy()
					end)
				else
					pcall(attack, f)
				end
			end
		end
	end)
end

return Flyers
