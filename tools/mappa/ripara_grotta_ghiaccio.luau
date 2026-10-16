--!strict
-- Ripara la grotta di ghiaccio del ghiacciaio SENZA rigenerare la mappa (Mirko 16/10, video
-- 124253: attraversando la grotta si usciva dalla mappa). La sala in fondo si apriva sulla
-- cavita' della montagna vuota: lobi senza pavimento e pareti aperte sul nulla.
-- Il generatore ora la chiude da solo (Caves.seal in carveGlacierCave); questo script fa lo
-- stesso sul Terrain gia' generato: ricostruisce il percorso dalle luci della grotta
-- (Workspace.Glacier...LuciGrottaGhiaccio, una ogni 4 punti) e chiude con Caves.seal.
-- Uso: Studio in modalita' Edit, Command Bar o MCP (codice nostro), poi salva il place.
--   local f = require(game.ServerStorage.MapGen:Clone().Caves)  -- (lo fa lo script)
-- Restituisce quanti voxel ha riempito (pareti, pavimento).
local Caves = require((game:GetService("ServerStorage"):WaitForChild("MapGen") :: any):Clone().Caves)

local R, H = 22, 75 -- CAVES.GLACIER_CAVES[1]: RADIUS e HALL (src/mapgen/Config.luau)
local UP = Vector3.yAxis
local terrain = workspace.Terrain
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { terrain }

local lights = workspace:FindFirstChild("LuciGrottaGhiaccio", true)
assert(lights, "LuciGrottaGhiaccio non trovato")
-- punti del percorso (a terra) dalle luci. La luce piu' alta sta al centro della sala (sotto la
-- cupola): quello e' l'ultimo punto; le luci della sala in cerchio attorno al centro non servono
local pts: { Vector3 } = {}
local center: BasePart? = nil
for _, l in lights:GetChildren() do
	if l:IsA("BasePart") and (not center or l.Position.Y > (center :: BasePart).Position.Y) then
		center = l
	end
end
assert(center, "nessuna luce")
local hallDown = workspace:Raycast((center :: BasePart).Position, Vector3.new(0, -200, 0), params)
local hallFloor = if hallDown then hallDown.Position else (center :: BasePart).Position
for _, l in lights:GetChildren() do
	if l:IsA("BasePart") and l ~= center then
		local down = workspace:Raycast(l.Position, Vector3.new(0, -80, 0), params)
		local p = if down then Vector3.new(l.Position.X, down.Position.Y, l.Position.Z) else l.Position
		-- fuori dalla sala: e' la galleria
		if Vector3.new(p.X - hallFloor.X, 0, p.Z - hallFloor.Z).Magnitude > H * 0.9 then
			table.insert(pts, p)
		end
	end
end
assert(#pts >= 3, "troppe poche luci")
-- ordine lungo la grotta: si parte dalla luce piu' bassa (l'ingresso sta in basso, la grotta sale)
-- e si va sempre alla piu' vicina
table.sort(pts, function(a, b)
	return a.Y < b.Y
end)
local chain = { table.remove(pts, 1) :: Vector3 }
while #pts > 0 do
	local here = chain[#chain]
	local best, bi = math.huge, 1
	for i, p in pts do
		local d = (p - here).Magnitude
		if d < best then
			best, bi = d, i
		end
	end
	table.insert(chain, table.remove(pts, bi) :: Vector3)
end
table.insert(chain, hallFloor) -- la galleria finisce al centro della sala
-- sfere (larghe: meglio piu' grande del vero che tappare la galleria)
local balls: { Caves.Ball } = {}
for i = 1, #chain - 1 do
	local a, b = chain[i], chain[i + 1]
	local n = math.max(1, math.ceil((b - a).Magnitude / 5))
	for s = 0, n - 1 do
		local p = a:Lerp(b, s / n)
		table.insert(balls, { c = p + UP * R * 0.75, r = R * 1.35, floor = p.Y - 2 })
		table.insert(balls, { c = p + UP * R * 1.3, r = R * 0.75 })
	end
end
local last = chain[#chain]
table.insert(balls, { c = last + UP * H * 0.5, r = H * 1.05, floor = last.Y - 1 })
-- lobi della sala (5 a caso nel generatore): inviluppo di 10 sfere tutt'attorno
for j = 1, 10 do
	local a = j / 10 * 2 * math.pi
	table.insert(balls, { c = last + Vector3.new(math.cos(a) * H * 0.6, H * 0.42, math.sin(a) * H * 0.6), r = H * 0.7, floor = last.Y - 1 })
end
local mouth = chain[1]
local function surface(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 2500, z), Vector3.new(0, -3000, 0), params)
	return if hit then hit.Position.Y else -math.huge
end
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Ripara grotta di ghiaccio") -- annullabile con Ctrl+Z
local filled, floored = Caves.seal(terrain, balls, 14, surface, function(p)
	return Vector3.new(p.X - mouth.X, 0, p.Z - mouth.Z).Magnitude < R * 2.5
end, function()
	task.wait()
end)
if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return string.format("Grotta di ghiaccio chiusa: %d voxel di ghiaccio sulle pareti, %d di pavimento. Ingresso %s, sala %s", filled, floored, tostring(mouth), tostring(last))
