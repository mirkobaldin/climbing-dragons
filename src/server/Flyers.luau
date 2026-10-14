--!strict
-- Draghi volanti nemici: il drago selvatico degli eventi (WorldEvents) e il Guardiano della
-- vetta (ricompare dopo GUARDIAN_RESPAWN secondi). Il server decide le manovre e scrive sul
-- modello solo il pezzo di volo in corso (shared/FlyerPath); ogni client lo muove e lo anima
-- (client/Combat, animazioni Dragon_* del suo rig con KfsPlayer). Manovre:
--   * pattuglia: giri larghi (il Guardiano, se non c'e' nessuno, si posa in vetta e ruggisce)
--   * picchiata: scende sul giocatore e artiglia chi e' sotto, poi risale
--   * soffio: si ferma in aria davanti al giocatore e soffia tre palle dell'elemento
--   * atterraggio: si posa vicino, ruggisce (spinta a chi e' vicino) e morde; a terra prende
--     piu' danni (colpi di piccozza compresi)
--   * raffica: gira attorno al giocatore sputando fuoco
-- La quota e' sempre sopra il terreno (prima passava dentro la montagna). Hitbox grande
-- (sfera "Hitbox" invisibile) per piccozza, rampino e attacchi.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local FlyerPath = require(ReplicatedStorage.Shared.FlyerPath)
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
	home: Vector3,
	health: number,
	dead: boolean,
	damagedBy: { [Player]: number },
	ends: number?, -- se ha una scadenza vola via (drago selvatico)
	fill: Frame,
	guardian: boolean,
	hitRadius: number,
	grounded: boolean, -- posato a terra: prende piu' danni
	lastHitAct: number,
	lastActAt: number, -- ultimo gesto (ruggito, soffio...): "colpito" non lo interrompe
	duel: Duel?, -- rivale del Duello dei draghi (server/Training): resta nell'arena
}

-- Duello dei draghi nell'arena: il rivale gira attorno al centro e ogni tanto attacca il drago
-- dello sfidante (attack lo decide Training); quando muore chiama dead al posto dei premi soliti
export type Duel = { player: Player, center: Vector3, radius: number, height: number, every: number, attack: (any) -> (), dead: (any) -> () }

local list: { Flyer } = {}
local folder: Folder
local fxEvent: RemoteEvent

local CLEAR = 22 -- distanza minima dal terreno in volo
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function notice(player: Player, text: string)
	player:SetAttribute("Notice", text)
	player:SetAttribute("NoticeTime", os.clock())
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- quota del terreno (la montagna arriva a ~4200)
local function groundY(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 5200, z), Vector3.new(0, -6000, 0), terrainOnly)
	return if hit then hit.Position.Y else 0
end

local function above(p: Vector3, clear: number): Vector3
	return Vector3.new(p.X, math.max(p.Y, groundY(p.X, p.Z) + clear), p.Z)
end

function Flyers.cframe(f: Flyer): CFrame
	return FlyerPath.fromModel(f.model, now())
end

function Flyers.position(f: Flyer): Vector3
	return Flyers.cframe(f).Position
end

-- draghi volanti vivi entro "radius" (piu' la loro hitbox) da pos
function Flyers.near(pos: Vector3, radius: number): { Flyer }
	local out = {}
	for _, f in list do
		if not f.dead and (Flyers.position(f) - pos).Magnitude <= radius + f.hitRadius then
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

function Flyers.hitRadius(f: Flyer): number
	return f.hitRadius
end

------------------------------------------------------------------------------------------
-- Pezzi di volo

local function act(f: Flyer, name: string)
	f.lastActAt = os.clock()
	f.model:SetAttribute("Act", name)
	f.model:SetAttribute("ActT", now())
end

local function setSeg(f: Flyer, kind: string, dur: number, anim: string, attrs: { [string]: any })
	local m = f.model
	for k, v in attrs do
		m:SetAttribute(k, v)
	end
	m:SetAttribute("SegDur", dur)
	m:SetAttribute("Anim", anim)
	m:SetAttribute("SegT0", now())
	m:SetAttribute("SegKind", kind)
end

-- curva dalla posizione attuale a "to" passando vicino a "via"; si alza finche' non tocca il
-- terreno (tranne alla fine se atterra)
local function curve(f: Flyer, via: Vector3, to: Vector3, dur: number, anim: string, landing: boolean?)
	local from = Flyers.position(f)
	local p1 = via
	for _ = 1, 4 do
		local low = 0
		for k = 1, 9 do
			local u = k / 10
			if landing and u > 0.75 then
				break
			end
			local v = 1 - u
			local p = from * (v * v) + p1 * (2 * v * u) + to * (u * u)
			local need = groundY(p.X, p.Z) + CLEAR - p.Y
			low = math.max(low, need)
		end
		if low <= 0 then
			break
		end
		p1 += Vector3.new(0, low * 2.2, 0)
	end
	setSeg(f, "curve", dur, anim, { P0 = from, P1 = p1, P2 = to })
end

local function hold(f: Flyer, at: Vector3, look: Vector3?, bob: number, anim: string)
	setSeg(f, "hold", 0, anim, { P0 = at, Look = look or (at + Vector3.new(0, 0, -10)), Bob = bob })
end

-- giro attorno a center, con la quota sopra il punto piu' alto del cerchio
local function orbit(f: Flyer, center: Vector3, radius: number, minAlt: number, speed: number)
	local top = -math.huge
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		top = math.max(top, groundY(center.X + math.cos(a) * radius, center.Z + math.sin(a) * radius))
	end
	local alt = math.max(top + CLEAR + 10, center.Y + minAlt)
	-- si parte dall'angolo piu' vicino a dove e' adesso (niente salti)
	local p = Flyers.position(f)
	local a0 = math.atan2(p.Z - center.Z, p.X - center.X)
	setSeg(f, "orbit", 0, "Fly", { Center = center, Radius = radius, Alt = alt, Speed = speed, A0 = a0 })
end

------------------------------------------------------------------------------------------
-- Colpi del drago

local function hurtAround(f: Flyer, at: Vector3, radius: number, damage: number, push: number, cause: string)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and (root.Position - at).Magnitude < radius then
			if damage > 0 then
				Survival.damage(humanoid, damage, cause)
			end
			local away = root.Position - at
			away = Vector3.new(away.X, 0, away.Z)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
			fxEvent:FireClient(player, "knock", away * push + Vector3.new(0, push * 0.6, 0))
		end
	end
end

-- palla dell'elemento da "from" verso "to": arriva dopo travel secondi
local function fireball(f: Flyer, from: Vector3, to: Vector3, travel: number)
	fxEvent:FireAllClients("fireball", from, to, f.def.element, travel)
	task.delay(travel, function()
		if not f.dead then
			hurtAround(f, to, 11, f.def.damage, 40, "Burned by the " .. f.def.name)
		end
	end)
end

local function mouthPos(f: Flyer): Vector3
	local cf = Flyers.cframe(f)
	return cf.Position + cf.LookVector * f.hitRadius * 0.8
end

local function target(f: Flyer): (Player?, BasePart?)
	local from = Flyers.position(f)
	local best, bestRoot, bestD = nil, nil, if f.guardian then 260 else 320
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not player:GetAttribute("Filming") then
			local d = (root.Position - from).Magnitude
			if d < bestD then
				best, bestRoot, bestD = player, root, d
			end
		end
	end
	return best, bestRoot
end

------------------------------------------------------------------------------------------
-- Manovre (ognuna aspetta la propria durata)

local function wait(f: Flyer, seconds: number): boolean
	local t = os.clock() + seconds
	while os.clock() < t do
		task.wait(0.1)
		if f.dead then
			return false
		end
	end
	return true
end

local function swoop(f: Flyer, root: BasePart)
	local p = Flyers.position(f)
	local tp = root.Position
	local dir = Vector3.new(tp.X - p.X, 0, tp.Z - p.Z)
	dir = if dir.Magnitude > 1 then dir.Unit else Vector3.xAxis
	local low = above(tp + Vector3.new(0, 6, 0), 10)
	local exit = above(tp + dir * 120 + Vector3.new(0, 70, 0), CLEAR + 20)
	act(f, "Roar")
	if not wait(f, 0.8) then
		return
	end
	-- giu' fin sopra il giocatore (picchiata), poi via in alto
	curve(f, Vector3.new(tp.X, low.Y + 40, tp.Z) - dir * 40, low, 2.0, "Dive", true)
	if not wait(f, 1.8) then
		return
	end
	act(f, "Bite")
	hurtAround(f, Flyers.position(f), f.hitRadius + 10, f.def.damage * 1.2, 70, "Clawed by the " .. f.def.name)
	curve(f, low + dir * 50 + Vector3.new(0, 20, 0), exit, 2.2, "Fly")
	wait(f, 2.2)
end

local function breath(f: Flyer, root: BasePart)
	local p = Flyers.position(f)
	local tp = root.Position
	local dir = Vector3.new(p.X - tp.X, 0, p.Z - tp.Z)
	dir = if dir.Magnitude > 1 then dir.Unit else Vector3.zAxis
	local spot = above(tp + dir * (45 + f.hitRadius) + Vector3.new(0, 30, 0), CLEAR + 8)
	curve(f, (p + spot) / 2 + Vector3.new(0, 25, 0), spot, 2.2, "Fly")
	if not wait(f, 2.2) then
		return
	end
	hold(f, spot, tp, 3, "Hover")
	act(f, "Breath")
	if not wait(f, 0.8) then
		return
	end
	for k = 1, 3 do
		local _, r = target(f)
		local aim = if r then r.Position else tp
		fireball(f, mouthPos(f), aim + Vector3.new((k - 2) * 6, 0, 0), 0.8)
		if not wait(f, 0.45) then
			return
		end
	end
	wait(f, 1.2)
end

local function land(f: Flyer, root: BasePart)
	local p = Flyers.position(f)
	local tp = root.Position
	local dir = Vector3.new(p.X - tp.X, 0, p.Z - tp.Z)
	dir = if dir.Magnitude > 1 then dir.Unit else Vector3.zAxis
	local spot = tp + dir * (28 + f.hitRadius)
	local hit = workspace:Raycast(spot + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), terrainOnly)
	if not hit or hit.Normal.Y < 0.75 or hit.Material == Enum.Material.Water then
		return breath(f, root) -- pendio troppo ripido: soffia dall'aria
	end
	local ground = hit.Position + Vector3.new(0, f.hitRadius * 0.55, 0)
	curve(f, (p + ground) / 2 + Vector3.new(0, 40, 0), ground, 2.6, "Glide", true)
	if not wait(f, 2.6) then
		return
	end
	f.grounded = true
	f.model:SetAttribute("Grounded", true)
	hold(f, ground, tp, 0, "Idle")
	act(f, "Land")
	if not wait(f, 0.9) then
		return
	end
	act(f, "Roar")
	if wait(f, 0.9) then
		-- il ruggito spinge via chi e' vicino
		hurtAround(f, ground, 34 + f.hitRadius, 8, 60, "Roared at by the " .. f.def.name)
		for _ = 1, 4 do
			if not wait(f, 1.3) then
				break
			end
			local _, r = target(f)
			if r then
				-- si gira verso il giocatore e morde se e' a tiro
				hold(f, ground, r.Position, 0, "Idle")
				if (r.Position - ground).Magnitude < f.hitRadius + 16 then
					act(f, "Bite")
					task.delay(0.45, function()
						if not f.dead then
							hurtAround(f, mouthPos(f), 14, f.def.damage, 55, "Bitten by the " .. f.def.name)
						end
					end)
				end
			end
		end
	end
	f.grounded = false
	f.model:SetAttribute("Grounded", false)
	if f.dead then
		return
	end
	-- decollo
	act(f, "Takeoff")
	if not wait(f, 0.6) then
		return
	end
	curve(f, ground + Vector3.new(0, 50, 0), above(ground + Vector3.new(60, 90, 0), CLEAR + 30), 2.2, "Fly")
	wait(f, 2.2)
end

local function barrage(f: Flyer, root: BasePart)
	orbit(f, root.Position, 70 + f.hitRadius, 35, 0.45)
	for _ = 1, 5 do
		if not wait(f, 1.2) then
			return
		end
		local _, r = target(f)
		if r then
			fireball(f, mouthPos(f), r.Position, 0.9)
		end
	end
end

-- il Guardiano senza nessuno attorno: si posa sul suo spiazzo e ogni tanto ruggisce
local function perch(f: Flyer)
	local spot = f.home + Vector3.new(0, f.hitRadius * 0.55, 0)
	local p = Flyers.position(f)
	if (p - spot).Magnitude > 20 then
		curve(f, (p + spot) / 2 + Vector3.new(0, 50, 0), spot, 3, "Glide", true)
		if not wait(f, 3) then
			return
		end
	end
	hold(f, spot, spot + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10)), 0, "Idle")
	-- da solo sulla vetta: ogni tanto ruggisce, si guarda attorno o si scrolla la neve di dosso
	local r = math.random()
	act(f, if r < 0.3 then "Roar" elseif r < 0.7 then "Look" else "Shake")
	wait(f, 4)
end

-- rivale del duello: giri nell'arena, ogni "every" secondi si ferma e attacca
local function duelBrain(f: Flyer)
	local d = f.duel :: Duel
	while not f.dead do
		orbit(f, d.center, d.radius, d.height, if math.random() < 0.5 then 0.55 else -0.55)
		if not wait(f, d.every * (0.7 + math.random() * 0.6)) then
			return
		end
		act(f, if math.random() < 0.3 then "Roar" else "Breath")
		if not wait(f, 0.5) then
			return
		end
		local ok, err = pcall(d.attack, f)
		if not ok then
			warn("[Duello] " .. tostring(err))
		end
		if not wait(f, 0.8) then
			return
		end
	end
end

local function brain(f: Flyer)
	if f.duel then
		return duelBrain(f)
	end
	while not f.dead do
		if f.ends and os.clock() > (f.ends :: number) then
			-- il drago selvatico se ne va
			for player in f.damagedBy do
				notice(player, "The " .. f.def.name .. " flew away...")
			end
			local p = Flyers.position(f)
			curve(f, p + Vector3.new(0, 120, 0), p + Vector3.new(400, 400, 0), 5, "Fly")
			f.dead = true
			local idx = table.find(list, f)
			if idx then
				table.remove(list, idx)
			end
			task.delay(5, function()
				f.model:Destroy()
			end)
			return
		end
		local player, root = target(f)
		if not player or not root then
			if f.guardian then
				perch(f)
			else
				orbit(f, f.home, f.def.radius, f.def.height, f.def.speed)
				wait(f, 4)
			end
		else
			local r = math.random()
			local ok, err = pcall(function()
				if r < 0.3 then
					swoop(f, root)
				elseif r < 0.58 then
					breath(f, root)
				elseif r < 0.82 then
					land(f, root)
				else
					barrage(f, root)
				end
			end)
			if not ok then
				warn("[Volanti] " .. tostring(err))
				wait(f, 2)
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Vita e morte

local function die(f: Flyer)
	f.dead = true
	local at = Flyers.position(f)
	fxEvent:FireAllClients("flyerDeath", f.model)
	if f.duel then
		local idx = table.find(list, f)
		if idx then
			table.remove(list, idx)
		end
		task.delay(3, function()
			f.model:Destroy()
		end)
		f.duel.dead(f)
		return
	end
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
			-- pietre dell'evoluzione: 2 dal Guardiano, 1 dal drago selvatico (a chi ha fatto almeno il 15%)
			local stones = if share >= 0.15 then (if f.guardian then 2 else 1) else 0
			if stones > 0 then
				Dragons.addStones(player, stones)
			end
			notice(player, string.format("%s defeated! +%d coins%s", f.def.name, math.floor(f.def.coins * share + 0.5), if stones > 0 then string.format(" · +%d evolution stone%s", stones, if stones > 1 then "s" else "") else ""))
		end
	end
	-- lascia un uovo raro dove cade
	local hit = workspace:Raycast(at + Vector3.new(0, 20, 0), Vector3.new(0, -600, 0), terrainOnly)
	if hit then
		pcall(Eggs.spawnAt, hit.Position + Vector3.new(0, 1, 0), f.def.element, if f.guardian then "Leggendario" else "Epico")
	end
	task.delay(3, function()
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
	if f.grounded then
		amount *= 1.5 -- a terra e' scoperto
	end
	if player then
		f.damagedBy[player] = (f.damagedBy[player] or 0) + amount
	end
	f.health -= amount
	f.fill.Size = UDim2.fromScale(math.clamp(f.health / f.def.health, 0, 1), 1)
	fxEvent:FireAllClients("flyerHurt", f.model, amount)
	if os.clock() - f.lastHitAct > 4 and os.clock() - f.lastActAt > 2.5 then
		f.lastHitAct = os.clock()
		act(f, "Hit")
	end
	if f.health <= 0 then
		die(f)
	end
end

local function spawn(def: UpgradeConfig.Flyer, home: Vector3, guardian: boolean, seconds: number?, duel: Duel?): Flyer?
	local ok, model = pcall(DragonModels.dragon, def.element, "Leggendario", 3, 30)
	if not ok or not model then
		return nil
	end
	local m = model :: Model
	-- l'adulto del giocatore e' passato da 22 a 33 studs: i volanti restano grandi come prima
	m:ScaleTo(m:GetScale() * def.scale * 22 / DragonConfig.STAGES[3].size)
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
	local cf, size = m:GetBoundingBox()
	local hitRadius = math.max(size.X, size.Y, size.Z) * 0.42
	-- hitbox: sfera invisibile grande quanto il drago (si prende col mouse, il rampino, la piccozza)
	local hb = Instance.new("Part")
	hb.Name = "Hitbox"
	hb.Shape = Enum.PartType.Ball
	hb.Size = Vector3.one * hitRadius * 2
	hb.CFrame = cf
	hb.Transparency = 1
	hb.Anchored = true
	hb.CanCollide = false
	hb.CanTouch = false
	hb.CanQuery = true
	hb.Parent = m
	m:SetAttribute("Flyer", true)
	m:SetAttribute("Element", def.element) -- client/MeshFX: colori e forme dei morsi e dei soffi
	m:SetAttribute("Guardian", guardian)
	m:SetAttribute("AnimRange", 900) -- KfsPlayer: si anima anche da lontano (e' enorme)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	-- barra della vita
	local bill = Instance.new("BillboardGui")
	bill.Name = "BarraVita"
	bill.Size = UDim2.fromOffset(240, 42)
	bill.StudsOffsetWorldSpace = Vector3.new(0, hitRadius * 1.1, 0)
	bill.MaxDistance = 500
	bill.Adornee = hb
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
	local f: Flyer = {
		def = def,
		model = m,
		home = home,
		health = def.health,
		dead = false,
		damagedBy = {},
		ends = if seconds then os.clock() + seconds else nil,
		fill = fill,
		guardian = guardian,
		hitRadius = hitRadius,
		grounded = false,
		lastHitAct = 0,
		lastActAt = 0,
		duel = duel,
	}
	-- primo pezzo: il Guardiano posato, il selvatico in arrivo dall'alto
	local start = if duel then home + Vector3.new(duel.radius, duel.height + 10, 0)
		elseif guardian then home + Vector3.new(0, hitRadius * 0.55, 0)
		else above(home + Vector3.new(-250, 160, 0), CLEAR + 60)
	setSeg(f, "hold", 0, if guardian then "Idle" else "Fly", { P0 = start, Look = home, Bob = 0 })
	m:PivotTo(FlyerPath.fromModel(m, now()))
	m.Parent = folder
	table.insert(list, f)
	task.spawn(brain, f)
	return f
end

-- elementi che hanno il modello adulto (con le animazioni)
local WILD = { "Gelo", "Cosmico", "Tempesta", "Fulmine", "Ossa", "Gas", "Roccia" }

function Flyers.spawnWild(center: Vector3): Flyer?
	local def = table.clone(UpgradeConfig.WILD_DRAGON)
	def.element = WILD[math.random(1, #WILD)]
	return spawn(def, center, false, UpgradeConfig.EVENTS.RAID_SECONDS)
end

-- rivale del Duello dei draghi (server/Training)
function Flyers.spawnDuel(def: UpgradeConfig.Flyer, duel: Duel): Flyer?
	local f = spawn(def, duel.center, false, nil, duel)
	if f then
		f.model:SetAttribute("DuelOwner", duel.player.UserId)
	end
	return f
end

-- da dove sputa (per le palle del duello)
function Flyers.mouth(f: Flyer): Vector3
	return mouthPos(f)
end

function Flyers.remove(f: Flyer)
	if f.dead then
		return
	end
	f.dead = true
	fxEvent:FireAllClients("flyerLeave", f.model)
	local idx = table.find(list, f)
	if idx then
		table.remove(list, idx)
	end
	task.delay(2, function()
		f.model:Destroy()
	end)
end

function Flyers.spawnGuardian()
	local markers = workspace:FindFirstChild("MapMarkers")
	local summit = markers and markers:FindFirstChild("Summit", true)
	if summit and summit:IsA("BasePart") then
		local p = summit.Position
		spawn(UpgradeConfig.GUARDIAN, Vector3.new(p.X, groundY(p.X, p.Z), p.Z), true, nil)
	end
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
end

return Flyers
