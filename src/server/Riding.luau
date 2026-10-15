--!strict
-- Monta del drago adulto: con la Sella (Gear "Sella", si fa al Banco da lavoro) e un drago
-- adulto al seguito (il primo) si sale in groppa e si vola (client/DragonRide). Qui solo il
-- permesso: l'attributo "Riding" lo vedono tutti i client, che mettono il drago sotto di te
-- (client/PetAnimator).
-- Forma di drago (Isola dei Draghi, Mirko 15/10: "diventi il drago, ti muovi essendo il drago"):
-- all'altare dell'arena dell'isola (prompt "Become your dragon") il personaggio sparisce e
-- comandi il drago adulto al seguito: cammina a terra, Spazio per volare, click per colpire.
-- E' la monta senza sella con l'attributo "DragonForm" (client/DragonRide, client/PetAnimator).
-- H o il pulsante Leave: torni te stesso sull'altare.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Dragons = require(script.Parent.Dragons)

local Riding = {}

-- perche' non puoi salire (nil = puoi)
function Riding.reason(player: Player): string?
	if not player:GetAttribute("DragonForm") and not Gear.has(player, "Sella") then
		return "You need a Dragon Saddle (Crafting, at a workbench)"
	end
	local list = Dragons.equippedDragons(player)
	local d = list[1]
	if not d then
		return "You need a dragon following you (G)"
	end
	if (d.stage or 1) < #DragonConfig.STAGES then
		return if player:GetAttribute("DragonForm") then "Only an adult dragon can fight in the arena: evolve it first" else "Only an adult dragon can carry you: evolve it first"
	end
	if player:GetAttribute("Training") then
		return "Leave the training arena first"
	end
	return nil
end

function Riding.setup()
	local remote = Instance.new("RemoteEvent")
	remote.Name = "DragonRide"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	remote.OnServerEvent:Connect(function(player: Player, on: any)
		-- dal menu draghi (pulsante Ride della scheda): l'id del drago da montare, che passa al
		-- primo posto dei draghi al seguito
		if type(on) == "number" then
			local s = Dragons.state(player)
			local chosen = nil
			for _, d in s.dragons do
				if d.id == on then
					chosen = d
				end
			end
			if not chosen then
				return
			end
			if (chosen.stage or 1) < #DragonConfig.STAGES then
				remote:FireClient(player, "Only an adult dragon can carry you: evolve it first")
				return
			end
			if not Gear.has(player, "Sella") then
				remote:FireClient(player, "You need a Dragon Saddle (Crafting, at a workbench)")
				return
			end
			player:SetAttribute("Riding", false)
			Dragons.setLead(player, on)
			task.wait(0.4) -- il nuovo drago appare accanto a te, poi sali
			on = true
		end
		if on ~= true then
			player:SetAttribute("Riding", false)
			return
		end
		local why = Riding.reason(player)
		if why then
			player:SetAttribute("Riding", false)
			remote:FireClient(player, why)
			return
		end
		player:SetAttribute("Riding", true)
	end)
	-- se cambia il drago al seguito (o entri nell'arena) si scende
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("Riding") and Riding.reason(player) then
					player:SetAttribute("Riding", false)
				end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Riding", false)
			player:SetAttribute("DragonForm", nil)
		end)
	end)
	task.spawn(Riding.setupForm)
end

-- personaggio invisibile per tutti (forma di drago) e poi di nuovo com'era
local function hideCharacter(character: Model, hide: boolean)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if hide then
				if d:GetAttribute("FormaT") == nil then
					d:SetAttribute("FormaT", (d :: any).Transparency)
				end
				(d :: any).Transparency = 1
			elseif d:GetAttribute("FormaT") ~= nil then
				(d :: any).Transparency = d:GetAttribute("FormaT")
				d:SetAttribute("FormaT", nil)
			end
		end
	end
end

local function notice(player: Player, text: string)
	player:SetAttribute("Notice", text)
	player:SetAttribute("NoticeTime", os.clock())
end

-- altare della forma di drago, dentro l'arena dell'Isola dei Draghi (mapgen/IsolaDraghi scrive
-- DragonIslandAltar): ProximityPrompt su un cerchio di rune che brilla
function Riding.setupForm()
	local at = workspace:GetAttribute("DragonIslandAltar")
	for _ = 1, 60 do
		if typeof(at) == "Vector3" then
			break
		end
		task.wait(1)
		at = workspace:GetAttribute("DragonIslandAltar")
	end
	if typeof(at) ~= "Vector3" then
		warn("[Riding] DragonIslandAltar mancante: niente forma di drago (rifai l'Isola dei Draghi)")
		return
	end
	local altar: Vector3 = at
	local pad = Instance.new("Part")
	pad.Name = "AltareFormaDrago"
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.4, 26, 26)
	pad.CFrame = CFrame.new(altar + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	pad.Color = Color3.fromRGB(255, 120, 50)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.55
	pad.Anchored, pad.CanCollide, pad.CanTouch = true, false, false
	local light = Instance.new("PointLight")
	light.Color = pad.Color
	light.Range = 30
	light.Brightness = 2
	light.Parent = pad
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Become your dragon"
	prompt.ObjectText = "Dragon Arena"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	pad.Parent = workspace
	local ridingRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DragonRide") :: RemoteEvent
	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("DragonForm") then
			return
		end
		player:SetAttribute("DragonForm", true) -- prima del controllo: niente sella richiesta
		local why = Riding.reason(player)
		if why then
			player:SetAttribute("DragonForm", nil)
			notice(player, why)
			ridingRemote:FireClient(player, why)
			return
		end
		local character = player.Character
		if character then
			hideCharacter(character, true)
		end
		player:SetAttribute("Riding", true)
		notice(player, "You are your dragon! Space = fly, click = attack, H = leave")
	end)
	-- fine della forma (H, morte, drago cambiato): torni visibile sull'altare
	local function watch(player: Player)
		player:GetAttributeChangedSignal("Riding"):Connect(function()
			if player:GetAttribute("Riding") or not player:GetAttribute("DragonForm") then
				return
			end
			player:SetAttribute("DragonForm", nil)
			local character = player.Character
			if character then
				hideCharacter(character, false)
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					root.AssemblyLinearVelocity = Vector3.zero
					character:PivotTo(CFrame.new(altar + Vector3.new(0, 5, 0)))
				end
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return Riding