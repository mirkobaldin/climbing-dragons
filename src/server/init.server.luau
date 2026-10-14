--!strict
-- Avvio dei sistemi di gioco lato server.

local Remotes = require(script.Remotes)
local Tools = require(script.Tools)
local Ropes = require(script.Ropes)
local Hazards = require(script.Hazards)
local Weather = require(script.Weather)
local BaseCamps = require(script.BaseCamps)
local Dragons = require(script.Dragons)
local Training = require(script.Training)
local Enemies = require(script.Enemies)
local ToxicGas = require(script.ToxicGas)
local Teleports = require(script.Teleports)
local Gym = require(script.Gym)
local Drops = require(script.Drops)
local Progression = require(script.Progression)
local Mining = require(script.Mining)
local Eggs = require(script.Eggs)
local Economy = require(script.Economy)
local Tutorial = require(script.Tutorial)
local Missions = require(script.Missions)
local Admin = require(script.Admin)
local Shop = require(script.Shop)
local Survival = require(script.Survival)
local Unstuck = require(script.Unstuck)
local CinematicSpots = require(script.CinematicSpots)
local Ocean = require(script.Ocean)
local Preflight = require(script.Preflight)
local Upgrades = require(script.Upgrades)
local Flyers = require(script.Flyers)
local WorldEvents = require(script.WorldEvents)
local VFXMeshes = require(script.VFXMeshes)
local Riding = require(script.Riding)

local remotes = Remotes.setup()
Unstuck.setup() -- per primo: non deve dipendere da quello che viene dopo
task.defer(function() -- dopo l'avvio: non deve rubare tempo al resto
	local ok, err = pcall(CinematicSpots.setup)
	if not ok then
		warn("[Cinematica] " .. tostring(err))
	end
	ok, err = pcall(Ocean.setup)
	if not ok then
		warn("[Oceano] " .. tostring(err))
	end
end)

-- Animazioni modificate da te nell'Animation Editor (ServerStorage.RBX_ANIMSAVES): in Studio
-- si passano al client, che le usa al posto di quelle generate da ClimbPoses. Cosi' salvi
-- nell'editor, premi Play e le vedi, senza pubblicarle ogni volta.
do
	local RunService = game:GetService("RunService")
	local saves = game:GetService("ServerStorage"):FindFirstChild("RBX_ANIMSAVES")
	if saves then -- anche nel gioco pubblicato: i draghi le suonano con KfsPlayer
		local out = Instance.new("Folder")
		out.Name = "ClimbAnimSaves"
		-- "climb-idle", "Climb_Idle", "climb idle"... vanno tutti bene; le tue (sul Rig) vincono su
		-- quelle generate del ManichinoArrampicata
		local wanted = {
				climbidle = "Climb_Idle",
				climbup = "Climb_Up",
				climbroof = "Climb_Roof",
				climbsideright = "Climb_SideR",
				climbsideleft = "Climb_SideL",
				climbjump = "Climb_Jump",
				axehold = "Axe_Hold",
				-- drago Ombra (rig Drago_Ombra_Rig)
				dragovolo = "Dragon_Fly",
				dragocammina = "Dragon_Walk",
				dragofermo = "Dragon_Idle",
				dragonfly = "Dragon_Fly",
				dragonwalk = "Dragon_Walk",
				dragonidle = "Dragon_Idle",
			}
			local ONCE = { Climb_Jump = true, Dragon_Roar = true, Dragon_Breath = true, Dragon_Bite = true, Dragon_Hit = true, Dragon_Sniff = true, Dragon_Shake = true, Dragon_Look = true, Dragon_Takeoff = true, Dragon_Land = true } -- si suonano una volta sola, niente loop
		local function keyframesOf(k: KeyframeSequence): { Keyframe }
			local list = k:GetKeyframes() :: { any }
			table.sort(list, function(a, b)
				return a.Time < b.Time
			end)
			return list
		end
		local function prepare(k: KeyframeSequence, name: string): KeyframeSequence
			local copy = k:Clone()
			copy.Name = name
			copy.Loop = not ONCE[name]
			if ONCE[name] then
				return copy
			end
			local list = keyframesOf(copy)
			local first, last = list[1], list[#list]
			if first then
				-- una posa sola (lunga 0 s): la si tiene ferma per un secondo
				-- piu' pose: il gioco la ripete in loop; se l'ultima posa non e' uguale alla prima si
				-- torna dolcemente alla prima (0.25 s dopo l'ultima) invece di scattare
				local function differs(): boolean
					local a = {}
					for _, p in first:GetDescendants() do
						if p:IsA("Pose") then
							a[p.Name] = p.CFrame
						end
					end
					for _, p in last:GetDescendants() do
						if p:IsA("Pose") then
							local ca = a[p.Name] or CFrame.identity
							local _, angle = (ca:Inverse() * p.CFrame):ToAxisAngle()
							if math.deg(angle) > 2 then
								return true
							end
						end
					end
					return false
				end
				if #list == 1 or (name ~= "Climb_Idle" and differs()) then
					local close = first:Clone()
					close.Time = if #list == 1 then 1 else last.Time + 0.25
					close.Parent = copy
				end
			end
			return copy
		end
		local found: { [string]: KeyframeSequence } = {}
		-- animazioni dei draghi: una cartella per modello (ReplicatedStorage.DragonAnimSaves.<nome>),
		-- cosi' ogni drago usa le sue. "Drago_Ombra_Rig" vale per il modello "Drago_Ombra".
		local dragonOut = Instance.new("Folder")
		dragonOut.Name = "DragonAnimSaves"
		local DRAGON = {
			dragovolo = "Dragon_Fly", dragocammina = "Dragon_Walk", dragofermo = "Dragon_Idle", dragopicchiata = "Dragon_Dive",
			dragolibrato = "Dragon_Hover", dragoplanata = "Dragon_Glide", dragoruggito = "Dragon_Roar", dragosoffio = "Dragon_Breath",
			dragomorso = "Dragon_Bite", dragocolpito = "Dragon_Hit",
			dragoseduto = "Dragon_Sit", dragodorme = "Dragon_Sleep", dragocorsa = "Dragon_Run", dragoannusa = "Dragon_Sniff",
			dragoscrolla = "Dragon_Shake", dragoguarda = "Dragon_Look", dragodecollo = "Dragon_Takeoff", dragoatterra = "Dragon_Land",
			dragoviratasx = "Dragon_BankL", dragoviratadx = "Dragon_BankR", dragosalita = "Dragon_Climb", dragodiscesa = "Dragon_Descend",
			dragonfly = "Dragon_Fly", dragonwalk = "Dragon_Walk", dragonidle = "Dragon_Idle",
		}
		-- cartelle con lo stesso nome (es. vecchi salvataggi automatici) si uniscono; quelle del
		-- rig ("..._Rig") hanno la precedenza
		local picked: { [string]: { [string]: { kfs: KeyframeSequence, rig: boolean } } } = {}
		for _, rigSaves in saves:GetChildren() do
			if string.sub(rigSaves.Name, 1, 6) == "Drago_" then
				local key = string.gsub(rigSaves.Name, "_Rig$", "")
				local fromRig = string.sub(rigSaves.Name, -4) == "_Rig" or workspace:FindFirstChild(rigSaves.Name, true) ~= nil
				picked[key] = picked[key] or {}
				for _, k in rigSaves:GetChildren() do
					local name = k:IsA("KeyframeSequence") and DRAGON[(k.Name:lower():gsub("[%s%-_]", ""))]
					if name and (not picked[key][name] or (fromRig and not picked[key][name].rig)) then
						picked[key][name] = { kfs = k :: KeyframeSequence, rig = fromRig }
					end
				end
			end
		end
		for key, anims in picked do
			if next(anims) then
				local set = Instance.new("Folder")
				set.Name = key
				for name, info in anims do
					prepare(info.kfs, name).Parent = set
				end
				set.Parent = dragonOut
			end
		end
		dragonOut.Parent = game:GetService("ReplicatedStorage")
		-- animazioni dei nemici (cammina, fermo, attacco, seduto) anche per il client: le usano
		-- le clip (KfsPlayer) e, in futuro, i nemici sul telefono
		local enemyOut = Instance.new("Folder")
		enemyOut.Name = "EnemyAnimSaves"
		for _, set in saves:GetChildren() do
			if set.Name == "Yeti" or set.Name == "GolemGhiaccio" then
				set:Clone().Parent = enemyOut
			end
		end
		enemyOut.Parent = game:GetService("ReplicatedStorage")
		for _, rigSaves in saves:GetChildren() do
			local isDummy = rigSaves.Name == "ManichinoArrampicata"
			if string.sub(rigSaves.Name, 1, 6) == "Drago_" and rigSaves.Name ~= "Drago_Ombra_Rig" then
				continue -- le animazioni degli altri draghi non sono quelle "globali" dell'Ombra
			end
			for _, k in rigSaves:GetChildren() do
				if k:IsA("KeyframeSequence") then
					local name = wanted[(k.Name:lower():gsub("[%s%-_]", ""))]
					if name and (not found[name] or not isDummy) then
						found[name] = k
					end
				end
			end
		end
		for name, k in found do
			prepare(k, name).Parent = out
		end
		out.Parent = game:GetService("ReplicatedStorage")
	end
	-- il manichino e i rig per l'Animation Editor non devono comparire in partita
	for _, name in { "ManichinoArrampicata", "ParetePerAnimare" } do
		local dummy = workspace:FindFirstChild(name)
		if dummy then
			dummy:Destroy()
		end
	end
	for _, child in workspace:GetChildren() do
		local isRigFolder = child:IsA("Folder") and (child.Name == "RigDraghi" or child.Name == "RigNemici")
		local isRig = child:IsA("Model") and child:FindFirstChild("AnimSaves") ~= nil
		if isRigFolder or isRig then
			child:Destroy()
		end
	end
end
-- il client dice quando e' attaccato alla parete: si mostra la seconda piccozza
remotes.ClimbState.OnServerEvent:Connect(function(player, climbing)
	-- le due piccozze si vedono sempre: il messaggio resta per chi vuole reagire ad attacco/stacco
	local _ = climbing
	Tools.setOffhandVisible(player.Character, true)
end)
task.wait() -- il lavoro di prima (animazioni) non deve sommarsi al resto: niente timeout
Admin.setup() -- presto: F2 deve funzionare anche se un sistema dopo si rompe
Tools.setup()
Ropes.setup(remotes)
Hazards.setup(remotes)
Weather.setup()
Dragons.setup()
Training.setup()
task.defer(Enemies.setup) -- cerca i punti sulla montagna: non deve fermare gli altri sistemi
ToxicGas.setup()
Teleports.setup()
Gym.setup()
Drops.setup()
Economy.setup()
Survival.setup()
Upgrades.setup() -- potenziamenti, taglie, scudo, vetta e discesa (prima di Progression: carica i salvataggi)
Progression.setup(remotes)
BaseCamps.setup()
Mining.setup()
Eggs.setup(remotes)
task.spawn(Tutorial.setup) -- aspetta la cartella Tutorial senza bloccare il resto
Missions.setup() -- dopo il tutorial: uovo, nido, arena, palestra, grotte, vetta
-- (Admin.setup e' all'inizio)
Shop.setup(remotes)
task.spawn(Flyers.setup) -- drago selvatico e guardiano della vetta (aspettano EnemyFX)
task.spawn(WorldEvents.setup) -- meteore, drago selvatico, grande valanga
task.spawn(VFXMeshes.setup) -- mesh VFX mancanti nel place: si ricreano dagli ID
Riding.setup() -- monta del drago adulto (Sella)
Preflight.setup()
