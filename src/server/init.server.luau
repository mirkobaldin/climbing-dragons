--!strict
-- Avvio dei sistemi di gioco lato server.

local Remotes = require(script.Remotes)
local Tools = require(script.Tools)
local Ropes = require(script.Ropes)
local Hazards = require(script.Hazards)
local Weather = require(script.Weather)
local BaseCamps = require(script.BaseCamps)
local Dragons = require(script.Dragons)
local Progression = require(script.Progression)
local Mining = require(script.Mining)
local Eggs = require(script.Eggs)
local Economy = require(script.Economy)
local Tutorial = require(script.Tutorial)
local Admin = require(script.Admin)
local Shop = require(script.Shop)
local Survival = require(script.Survival)
local Unstuck = require(script.Unstuck)
local CinematicSpots = require(script.CinematicSpots)
local Ocean = require(script.Ocean)

local remotes = Remotes.setup()
Unstuck.setup() -- per primo: non deve dipendere da quello che viene dopo
task.spawn(function()
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
	if RunService:IsStudio() and saves then
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
			local ONCE = { Climb_Jump = true } -- si suonano una volta sola, niente loop
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
		for _, rigSaves in saves:GetChildren() do
			local isDummy = rigSaves.Name == "ManichinoArrampicata"
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
	-- il manichino per l'Animation Editor non deve comparire in partita
	local dummy = workspace:FindFirstChild("ManichinoArrampicata")
	if dummy then
		dummy:Destroy()
	end
end
-- il client dice quando e' attaccato alla parete: si mostra la seconda piccozza
remotes.ClimbState.OnServerEvent:Connect(function(player, climbing)
	-- le due piccozze si vedono sempre: il messaggio resta per chi vuole reagire ad attacco/stacco
	local _ = climbing
	Tools.setOffhandVisible(player.Character, true)
end)
Tools.setup()
Ropes.setup(remotes)
Hazards.setup(remotes)
Weather.setup()
Dragons.setup()
Economy.setup()
Survival.setup()
Progression.setup(remotes)
BaseCamps.setup()
Mining.setup()
Eggs.setup(remotes)
task.spawn(Tutorial.setup) -- aspetta la cartella Tutorial senza bloccare il resto
Admin.setup()
Shop.setup(remotes)
