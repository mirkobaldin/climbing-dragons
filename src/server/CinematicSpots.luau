--!strict
-- Punti per la cinematica (comando admin "cinematica"): la vetta e la linea centrale del
-- ghiacciaio principale, trovate sul terreno vero all'avvio del server e pubblicate come
-- attributi del Workspace. Il client non le saprebbe trovare da solo: con lo streaming vede solo
-- il terreno attorno al personaggio.
--   CineSummit       Vector3   il punto piu' alto della montagna
--   CineGlacier1..N  Vector3   centro del ghiacciaio, dall'alto verso la fronte
--   CineGlacierCount number

local ServerStorage = game:GetService("ServerStorage")

local CinematicSpots = {}

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function ground(x: number, z: number): RaycastResult?
	return workspace:Raycast(Vector3.new(x, 6000, z), Vector3.new(0, -7000, 0), terrainOnly)
end

-- Prova la salita della cinematica da un naso (stessa regola del client, Cinematic.planClimb):
-- quanti passi di parete ci sono, se passa sotto un tetto e se sopra il bordo c'e' un ripiano
-- dove mettere l'uovo. Un naso che non supera la prova non si usa.
local CLIMB_STEP = 7.5 / 30
local BODY = 1.8
local function surfaceUp(n: Vector3, prev: Vector3): Vector3
	local up = prev - n * prev:Dot(n)
	if up.Magnitude < 0.25 then
		up = Vector3.yAxis - n * n.Y
	end
	if up.Magnitude < 0.25 then
		up = Vector3.zAxis - n * n.Z
	end
	return up.Unit
end
local function tryClimb(spot: Vector3, n0: Vector3, under: number): (number, boolean, boolean)
	local first: RaycastResult? = nil
	for dy = under + 40, 10, -6 do
		local hit = workspace:Raycast(Vector3.new(spot.X, spot.Y - dy, spot.Z) + n0 * 200, -n0 * 400, terrainOnly)
		if hit and math.abs(hit.Normal.Y) < 0.5 then
			first = hit
			break
		end
	end
	if not first then
		return 0, false, false
	end
	local n = first.Normal
	local up = surfaceUp(n, Vector3.yAxis)
	local pos = first.Position + n * BODY
	local steps, roof = 0, false
	for _ = 1, 50 * 30 do
		steps += 1
		if steps % 150 == 0 then
			task.wait() -- niente timeout all'avvio (bloccava anche F2)
		end
		local hit = workspace:Raycast(pos + up * CLIMB_STEP + n * 3, -n * 9, terrainOnly)
		if not hit then
			break
		end
		n = n:Lerp(hit.Normal, 0.18).Unit
		if n.Y > 0.55 then
			break -- ripiano: qui la salita finisce
		end
		up = surfaceUp(n, up)
		pos = hit.Position + n * BODY
		if n.Y < -0.3 then
			roof = true
		end
	end
	-- ripiano sopra il bordo
	local outward = Vector3.new(up.X, 0, up.Z)
	outward = if outward.Magnitude > 1e-3 then outward.Unit else Vector3.xAxis
	local ledge = false
	for _, back in { 3, 6, 10 } do
		local hit = workspace:Raycast(pos - outward * back + Vector3.new(0, 40, 0), Vector3.new(0, -60, 0), terrainOnly)
		if hit and hit.Normal.Y > 0.55 and hit.Position.Y > pos.Y then
			ledge = true
			break
		end
	end
	return steps, roof, ledge
end

-- Lo strapiombo della cinematica: il "naso" di roccia piu' sporgente nella parte alta della
-- montagna. Tutto attorno, a ogni quota, un raggio orizzontale dall'esterno misura quanto e'
-- lontana la parete dal centro; dove una fascia sporge molto piu' della parete sotto di lei,
-- li' c'e' un tetto. Sovrascrive CineSpot/CineNormal/CineDepth/CineUnder del generatore.
function CinematicSpots.findNose(M: any, top: number)
	local center = Vector3.new(M.X, 0, M.Z)
	-- scelto a mano: una Part "PuntoCinematica" in Workspace, messa sulla punta del tetto
	local manual = workspace:FindFirstChild("PuntoCinematica")
	if manual and manual:IsA("BasePart") then
		local p = manual.Position
		local out = Vector3.new(p.X - center.X, 0, p.Z - center.Z)
		out = if out.Magnitude > 1 then out.Unit else Vector3.xAxis
		local below = workspace:Raycast(p + out * 4 - Vector3.new(0, 6, 0), Vector3.new(0, -300, 0), terrainOnly)
		workspace:SetAttribute("CineSpot", p)
		workspace:SetAttribute("CineNormal", out)
		workspace:SetAttribute("CineDepth", 60)
		workspace:SetAttribute("CineUnder", if below then math.clamp(p.Y - below.Position.Y, 40, 140) else 80)
		manual.Transparency = 1
		manual.CanCollide = false
		return
	end
	local outer = M.RADIUS * 1.4
	local STEP_Y = 20
	local y0, y1 = top * 0.55, top * 0.9
	local candidates: { any } = {}
	for deg = 0, 357, 3 do
		local a = math.rad(deg)
		if deg % 15 == 0 then
			task.wait()
		end
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local radii: { number } = {}
		local normals: { Vector3 } = {}
		local heights: { number } = {}
		for y = y0 - 200, y1, STEP_Y do
			local from = center + dir * outer + Vector3.new(0, y, 0)
			local hit = workspace:Raycast(from, -dir * outer, terrainOnly)
			table.insert(heights, y)
			table.insert(radii, if hit then (Vector3.new(hit.Position.X, 0, hit.Position.Z) - center).Magnitude else 0)
			table.insert(normals, if hit then hit.Normal else dir)
		end
		for k = 11, #radii do
			if heights[k] >= y0 and radii[k] > 0 then
				-- la parete sotto il naso (da 30 a 200 studs piu' in basso): quanto e' rientrata
				local below, at = math.huge, 0
				for j = k - 10, k - 2 do
					if radii[j] > 0 and radii[j] < below then
						below, at = radii[j], j
					end
				end
				local depth = radii[k] - below
				-- serve davvero un tetto: subito sopra il naso la roccia rientra (non e' un pendio)
				if depth > 25 and depth < 160 and at > 0 then
					table.insert(candidates, {
						score = depth * (heights[k] / top) ^ 3,
						dir = dir,
						lip = center + dir * (radii[k] - 3) + Vector3.new(0, heights[k] - STEP_Y * 0.5, 0),
						depth = depth,
						under = heights[k] - heights[at],
						normal = Vector3.new(normals[at].X, 0, normals[at].Z),
					})
				end
			end
		end
	end
	-- dal migliore in giu': il primo che supera la prova di salita (almeno 6 s di parete, un tetto,
	-- un ripiano sopra il bordo). Se nessuno la supera, il piu' lungo tra quelli con il tetto.
	table.sort(candidates, function(a, b)
		return a.score > b.score
	end)
	local best: any = nil
	local fallback: any = nil
	for i = 1, math.min(40, #candidates) do
		local c = candidates[i]
		local n = if c.normal.Magnitude > 0.3 then c.normal.Unit else c.dir
		local steps, roof, ledge = tryClimb(c.lip, n, math.clamp(c.under, 40, 140))
		if steps >= 180 and roof and ledge then
			best = c
			break
		end
		if roof and (not fallback or steps > fallback.steps) then
			fallback = c
			fallback.steps = steps
		end
	end
	best = best or fallback
	if not best then
		return
	end
	local n = if best.normal.Magnitude > 0.3 then best.normal.Unit else best.dir
	workspace:SetAttribute("CineSpot", best.lip)
	workspace:SetAttribute("CineNormal", n)
	workspace:SetAttribute("CineDepth", best.depth)
	workspace:SetAttribute("CineUnder", math.clamp(best.under, 40, 140))
end

function CinematicSpots.setup()
	local mapGen = ServerStorage:FindFirstChild("MapGen")
	local configModule = mapGen and mapGen:FindFirstChild("Config")
	if not configModule or not configModule:IsA("ModuleScript") then
		return
	end
	local cfg = (require :: any)(configModule)
	local M = cfg.MOUNTAIN

	-- vetta: griglia grossa, poi fine attorno al punto migliore
	local best: Vector3? = nil
	local function scan(cx: number, cz: number, half: number, step: number)
		for x = cx - half, cx + half, step do
			for z = cz - half, cz + half, step do
				local hit = ground(x, z)
				if hit and (not best or hit.Position.Y > (best :: Vector3).Y) then
					best = hit.Position
				end
			end
		end
	end
	scan(M.X, M.Z, M.RADIUS * 0.2, 40)
	if not best then
		return -- mappa non generata
	end
	local top = best :: Vector3
	scan(top.X, top.Z, 40, 8)
	workspace:SetAttribute("CineSummit", best)
	-- centro e raggio della montagna: la cinematica ci gira attorno
	workspace:SetAttribute("CineCenter", Vector3.new(M.X, 0, M.Z))
	workspace:SetAttribute("CineRadius", M.RADIUS)
	CinematicSpots.findNose(M, (best :: Vector3).Y)

	-- ghiacciaio: si scende lungo il suo asse e a ogni passo si cerca di traverso dove c'e'
	-- davvero ghiaccio, prendendone il centro (le lingue curvano)
	local def = cfg.GLACIERS and cfg.GLACIERS[1]
	if not def then
		return
	end
	local dir = Vector3.new(math.cos(def.ANGLE), 0, math.sin(def.ANGLE))
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local r0, r1 = def.R_TOP * M.RADIUS, def.R_BOTTOM * M.RADIUS
	local center = Vector3.new(M.X, 0, M.Z)
	local offsets: { number } = {}
	local steps = 18
	local lastOffset = 0
	for k = 0, steps do
		local along = center + dir * (r0 + (r1 - r0) * k / steps)
		local sum, n = 0, 0
		for t = -def.WIDTH * 1.2, def.WIDTH * 1.2, 12 do
			local p = along + side * (t + lastOffset)
			local hit = ground(p.X, p.Z)
			if hit and (hit.Material == Enum.Material.Glacier or hit.Material == Enum.Material.Snow) then
				sum += t + lastOffset
				n += 1
			end
		end
		local offset = if n > 3 then sum / n else lastOffset
		lastOffset = offset
		offsets[k + 1] = offset
	end
	-- la camera ci vola sopra: niente scatti di lato, si ammorbidisce la linea
	for _ = 1, 3 do
		local copy = table.clone(offsets)
		for i = 1, #offsets do
			local a, b = copy[math.max(1, i - 1)], copy[math.min(#copy, i + 1)]
			offsets[i] = (a + 2 * copy[i] + b) / 4
		end
	end
	local points: { Vector3 } = {}
	local lastIce = 0
	for k = 0, steps do
		local p = center + dir * (r0 + (r1 - r0) * k / steps) + side * offsets[k + 1]
		local hit = ground(p.X, p.Z)
		if hit then
			table.insert(points, hit.Position)
			if hit.Material == Enum.Material.Glacier or hit.Material == Enum.Material.Snow then
				lastIce = #points
			end
		end
	end
	-- il volo finisce sulla fronte: niente prati dopo la fine del ghiaccio
	local count = math.min(#points, lastIce + 1)
	for k = 1, count do
		workspace:SetAttribute("CineGlacier" .. k, points[k])
	end
	workspace:SetAttribute("CineGlacierCount", count)
end

return CinematicSpots
