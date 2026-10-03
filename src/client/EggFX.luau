--!strict
-- Effetti delle uova (buco nero, lava, fulmini, gelo...) dal modulo ReplicatedStorage.EffettiUova,
-- ma sul client e solo per le uova vicine. Prima girava sul server per tutte le uova della
-- mappa a ogni frame (con parti di magma create e distrutte di continuo): ogni movimento
-- partiva verso tutti i giocatori ed era una delle cause del lag.
-- Un uovo e' riconosciuto dall'attributo "Element" (le uova del gioco) o dal nome "Uovo_<Tipo>".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggFX = {}

local NEAR = 220 -- entro questa distanza dalla camera gli effetti si accendono
local FAR = 280 -- oltre questa si spengono (un po' di margine: niente accendi/spegni continuo)

type Active = { remove: () -> () }

function EggFX.start()
	local module = ReplicatedStorage:FindFirstChild("EffettiUova")
	if not module or not module:IsA("ModuleScript") then
		return
	end
	local ok, Effetti = pcall(require, module)
	if not ok then
		warn("[Uova] EffettiUova non caricato: " .. tostring(Effetti))
		return
	end
	local active: { [Instance]: Active } = {}

	local function kind(inst: Instance): string?
		local el = inst:GetAttribute("Element")
		if type(el) == "string" then
			return el
		end
		return (Effetti :: any).Tipo(inst)
	end

	local function position(inst: Instance): Vector3?
		if inst:IsA("Model") then
			return inst:GetPivot().Position
		elseif inst:IsA("BasePart") then
			return inst.Position
		end
		return nil
	end

	task.spawn(function()
		while true do
			local camera = workspace.CurrentCamera
			local here = camera and camera.CFrame.Position
			if here then
				-- spegne quelle lontane o sparite
				for inst, a in active do
					local p = inst.Parent and position(inst)
					if not p or (p - here).Magnitude > FAR then
						pcall(a.remove)
						active[inst] = nil
					end
				end
				-- accende quelle vicine (le uova del gioco stanno in Workspace.Eggs)
				local candidates: { Instance } = {}
				local folder = workspace:FindFirstChild("Eggs")
				if folder then
					for _, e in folder:GetChildren() do
						table.insert(candidates, e)
					end
				end
				-- uova portate sulla schiena e uova nei nidi
				for _, plr in Players:GetPlayers() do
					local ch = plr.Character
					local carried = ch and ch:FindFirstChild("CarriedEgg", true)
					if carried then
						table.insert(candidates, carried)
					end
				end
				for _, inst in candidates do
					if not active[inst] and (inst:IsA("Model") or inst:IsA("BasePart")) then
						local k = kind(inst)
						local p = position(inst)
						if k and p and (p - here).Magnitude < NEAR then
							local done, remove = pcall((Effetti :: any).Applica, inst, k)
							if done and remove then
								active[inst] = { remove = remove }
							end
						end
					end
				end
			end
			task.wait(1)
		end
	end)
end

return EggFX
