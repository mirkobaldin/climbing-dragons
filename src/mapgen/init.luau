--!strict
-- Generatore della mappa (isola + montagna + fiumi + grotte + villaggio + ostacoli + bosco + drago).
--
-- Uso, dalla Command Bar di Roblox Studio con Rojo connesso:
--     require(game.ServerStorage.MapGen).Generate()
-- Con un seed diverso (isola diversa):
--     require(game.ServerStorage.MapGen).Generate({ SEED = 1234 })
--
-- Poi SALVA il place (File > Save): il terreno vive nel file del gioco, Rojo sincronizza
-- solo il codice. Ci vogliono alcuni minuti: l'avanzamento appare nella finestra Output.

local Caves = require(script.Caves)
local Config = require(script.Config)
local Environment = require(script.Environment)
local Forest = require(script.Forest)
local Glacier = require(script.Glacier)
local Heightmap = require(script.Heightmap)
local Lakeside = require(script.Lakeside)
local Landmarks = require(script.Landmarks)
local Markers = require(script.Markers)
local Obstacles = require(script.Obstacles)
local Ores = require(script.Ores)
local Scatter = require(script.Scatter)
local Toxic = require(script.Toxic)
local Tutorial = require(script.Tutorial)
local Village = require(script.Village)
local Voxelizer = require(script.Voxelizer)

local MapGen = {}

function MapGen.Generate(overrides: { [string]: any }?): Heightmap.Map
	local cfg = table.clone(Config)
	for key, value in overrides or {} do
		cfg[key] = value
	end

	local t0 = os.clock()
	local lastPrint = 0
	local function progress(stage: string, fraction: number)
		if os.clock() - lastPrint > 2 or fraction >= 1 then
			lastPrint = os.clock()
			print(string.format("[MapGen] %s %d%%  (%.0fs)", stage, math.floor(fraction * 100), os.clock() - t0))
		end
	end
	-- Cede il controllo a Studio ogni tanto, cosi' non si blocca
	local lastYield = os.clock()
	local function yield()
		if os.clock() - lastYield > 0.2 then
			task.wait()
			lastYield = os.clock()
		end
	end

	print(string.format("[MapGen] Avvio, seed %d", cfg.SEED))
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	workspace.Terrain:Clear()
	-- vecchie cascate finte delle versioni precedenti
	local oldFalls = workspace:FindFirstChild("Waterfalls")
	if oldFalls then
		oldFalls:Destroy()
	end

	local map = Heightmap.build(cfg, yield, progress)
	Voxelizer.write(map, yield, progress)
	Caves.carve(map, yield, progress)

	-- Le parti decorative sono indipendenti: se una fallisce lo diciamo e andiamo avanti
	local failed = {}
	local function stage(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then
			table.insert(failed, name)
			warn(string.format("[MapGen] ERRORE in %s: %s", name, tostring(err)))
		end
	end
	stage("Markers (spawn)", function() Markers.place(map) end)
	stage("Environment", function() Environment.apply() end)
	stage("Landmarks (drago)", function() Landmarks.build(map) end)
	stage("Tutorial", function() Tutorial.build(map) end)
	stage("Village", function() Village.build(map) end)
	stage("Obstacles", function() Obstacles.place(map) end)
	stage("Glacier", function() Glacier.build(map) end) -- dopo gli strapiombi: ci appende le stalattiti
	stage("Valle dei gas", function() Toxic.build(map) end)
	stage("Lakeside", function() Lakeside.build(map) end)
	stage("Ores", function() Ores.place(map) end)
	stage("Prati", function() Scatter.place(map) end)
	stage("Forest", function() Forest.plant(map, yield, progress) end)

	if #failed > 0 then
		warn("[MapGen] Parti non riuscite: " .. table.concat(failed, ", ") .. " (manda l'errore qui sopra)")
	end
	print(string.format("[MapGen] Fatto in %.0f secondi. Ricordati di salvare il place!", os.clock() - t0))
	return map
end

return MapGen
