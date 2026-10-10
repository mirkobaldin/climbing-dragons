--!strict
-- Salvataggio di chi finisce dentro la roccia. Dentro il Terrain la collisione non c'e': chi ci
-- entra (una parete attraversata arrampicando, un soffitto sottile) precipita attraverso tutta
-- la montagna e muore in fondo. Ogni mezzo secondo si guarda il terreno dove stanno il bacino
-- e la testa di ogni giocatore: se sono pieni di roccia per piu' controlli di fila lo si
-- riporta nel punto libero piu' vicino, e si scrive nel log dove e in che stato era, per capire
-- da dove e' entrato.

local Players = game:GetService("Players")

local Unstuck = {}

local V = 4
local CHECK_EVERY = 0.5
local STRIKES = 2 -- controlli di fila dentro la roccia prima di intervenire (1 s)

local function solidAt(p: Vector3): number
	local base = Vector3.new(math.floor(p.X / V) * V, math.floor(p.Y / V) * V, math.floor(p.Z / V) * V)
	local ch = workspace.Terrain:ReadVoxelChannels(Region3.new(base, base + Vector3.one * V), V, { "SolidOccupancy" })
	return ch.SolidOccupancy[1][1][1]
end

-- Un posto dove stare in piedi: due voxel liberi uno sopra l'altro
local function free(p: Vector3): boolean
	return solidAt(p) < 0.3 and solidAt(p + Vector3.new(0, V, 0)) < 0.3
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function findExit(from: Vector3): Vector3?
	-- Quasi sempre si e' entrati dalla superficie sopra (terreno sottile, bordo di una parete):
	-- si torna li'. Un raggio che parte dentro la roccia non vede niente, quindi lo si fa
	-- partire dall'alto, da un punto in aria, e scendere fino alla prima superficie.
	for _, up in { 60, 120, 200 } do
		local start = from + Vector3.new(0, up, 0)
		if solidAt(start) < 0.3 then
			local hit = workspace:Raycast(start, Vector3.new(0, -up, 0), terrainOnly)
			if hit and hit.Normal.Y > 0.3 and free(hit.Position + Vector3.new(0, 2, 0)) then
				return hit.Position + Vector3.new(0, 1, 0)
			end
		end
	end
	-- altrimenti lo spazio libero piu' vicino, tutt'attorno allargandosi, poi in alto
	for r = V, 64, V do
		for a = 0, 7 do
			local ang = a * math.pi / 4
			for _, dy in { 0, V, 2 * V, -V } do
				local p = from + Vector3.new(math.cos(ang) * r, dy, math.sin(ang) * r)
				if free(p) then
					return p
				end
			end
		end
	end
	for dy = V, 120, V do
		local p = from + Vector3.new(0, dy, 0)
		if free(p) then
			return p
		end
	end
	return nil
end

local strikes: { [Player]: number } = {}

local function check(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		strikes[player] = nil
		return
	end
	local pos = root.Position
	-- dentro la cavita' della montagna vuota (vedi Voxelizer): roccia sopra e tutt'attorno,
	-- niente sotto per un bel pezzo. Si torna sulla superficie proprio sopra.
	local function hits(dir: Vector3): boolean
		return workspace:Raycast(pos, dir, terrainOnly) ~= nil
	end
	if hits(Vector3.new(0, 400, 0)) and not hits(Vector3.new(0, -150, 0))
		and hits(Vector3.new(400, 0, 0)) and hits(Vector3.new(-400, 0, 0))
		and hits(Vector3.new(0, 0, 400)) and hits(Vector3.new(0, 0, -400)) then
		local top = workspace:Raycast(Vector3.new(pos.X, 6000, pos.Z), Vector3.new(0, -7000, 0), terrainOnly)
		if top then
			warn(string.format("[Salvataggio] %s era nella cavita' della montagna a (%.0f, %.0f, %.0f)", player.Name, pos.X, pos.Y, pos.Z))
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(CFrame.new(top.Position + Vector3.new(0, 4, 0)))
			player:SetAttribute("Rescued", ((player:GetAttribute("Rescued") or 0) :: number) + 1)
			player:SetAttribute("Notice", "You fell inside the mountain: we pulled you out")
			player:SetAttribute("NoticeTime", os.clock())
			return
		end
	end
	local inside = solidAt(pos) > 0.9 and solidAt(pos + Vector3.new(0, 2, 0)) > 0.9
	if not inside then
		strikes[player] = nil
		return
	end
	local n = (strikes[player] or 0) + 1
	strikes[player] = n
	if n < STRIKES then
		return
	end
	strikes[player] = nil
	local exit = findExit(pos)
	warn(string.format(
		"[Salvataggio] %s era dentro la roccia a (%.0f, %.0f, %.0f) | stato=%s arrampicava=%s | %s",
		player.Name, pos.X, pos.Y, pos.Z, humanoid:GetState().Name,
		tostring(root:FindFirstChild("ClimbAttachment") ~= nil),
		if exit then string.format("riportato a (%.0f, %.0f, %.0f)", exit.X, exit.Y, exit.Z) else "nessuna uscita: al campo"
	))
	root.AssemblyLinearVelocity = Vector3.zero
	if exit then
		character:PivotTo(CFrame.new(exit + Vector3.new(0, 3, 0)))
	else
		player:LoadCharacter()
	end
	-- il client azzera la misura della caduta: quella dentro la roccia non deve far danno
	player:SetAttribute("Rescued", ((player:GetAttribute("Rescued") or 0) :: number) + 1)
	player:SetAttribute("Notice", "You got stuck inside the rock: we pulled you out")
	player:SetAttribute("NoticeTime", os.clock())
end

function Unstuck.setup()
	Players.PlayerRemoving:Connect(function(player)
		strikes[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(check, player)
				if not ok then
					warn("[Salvataggio] errore: " .. tostring(err))
				end
			end
		end
	end)
end

return Unstuck
