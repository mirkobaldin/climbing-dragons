--!strict
-- Isola dei Draghi: isola volante lontana, sopra l'oceano a ovest, con l'arena ottagonale
-- (scheda e misure: cloud/IsolaDraghi/SCHEDA.md, montaggio: cloud/LEGGIMI.md). Ci si arriva col
-- teletrasporto (server/Teleports, "Dragon Island") alla piattaforma delle rune (SPOT_Arrivo).
--   * se in ServerStorage.CaseCodex.IsolaDraghi c'e' il modello vero (caricato con
--     tools/modelli/carica_modelli.luau, in metri) lo monta in scala SCALE e prende i punti di
--     gioco dai suoi marcatori (Attachment SPOT_* dentro la parte "Luci");
--   * altrimenti costruisce una SAGOMA PROVVISORIA di blocchi con le stesse misure e gli stessi
--     punti, cosi' teletrasporto, duello e palco del domatore si possono gia' fare e provare.
-- Scrive in workspace gli attributi DragonIslandArrival/Center/Tamer/Altar e la cartella
-- workspace.IsolaDraghi.Punti con una parte invisibile per ogni SPOT_* (in studs).
-- Si rifa' da sola (non serve rigenerare la mappa):
--   require(game.ServerStorage.MapGen:Clone().IsolaDraghi).build()

local ServerStorage = game:GetService("ServerStorage")

local IsolaDraghi = {}

IsolaDraghi.SCALE = 5 / 1.7 -- i modelli del cloud sono in metri veri: personaggio 1,7 m = 5 stud
-- centro del pavimento dell'arena (l'origine del modello), sopra l'oceano a ovest del campo:
-- dal campo base (x -1450) si vede all'orizzonte (a -5000 era quasi sul bordo dell'oceano, che
-- finisce a -5888: dall'isola si vedeva dove finiva l'acqua)
IsolaDraghi.ORIGIN = CFrame.new(-4300, 820, -150)

-- elementi delle torri, dal portale in senso antiorario visto dall'alto (come nel modello)
IsolaDraghi.TOWERS = { "Roccia", "Gelo", "Cosmico", "Tempesta", "Eclissi", "Fulmine", "Ossa", "Gas" }

local M = IsolaDraghi.SCALE
local ARENA_IN = 75 -- apotema interno dell'ottagono (m)
local WALL_T = 20 -- spessore delle mura con i gradoni (m)
local WALL_H = 22
local TOWER_R = 8
local TOWER_H = 40

local STONE = Color3.fromRGB(62, 57, 54) -- #3E3936 pietra vulcanica
local BASALT = Color3.fromRGB(38, 34, 31) -- #26221F
local BRONZE = Color3.fromRGB(138, 90, 46)
local GOLD = Color3.fromRGB(179, 142, 62)
local GRASS = Color3.fromRGB(85, 117, 58)
local SAND = Color3.fromRGB(191, 166, 126)

local ELEMENT_COLORS: { [string]: Color3 } = {
	Roccia = Color3.fromRGB(150, 120, 90),
	Gelo = Color3.fromRGB(120, 200, 255),
	Cosmico = Color3.fromRGB(150, 100, 255),
	Tempesta = Color3.fromRGB(90, 170, 220),
	Eclissi = Color3.fromRGB(255, 150, 60),
	Fulmine = Color3.fromRGB(200, 60, 255),
	Ossa = Color3.fromRGB(230, 225, 205),
	Gas = Color3.fromRGB(140, 220, 90),
}

-- direzione orizzontale all'angolo a (gradi): 0 = verso il portale (+Z), poi antiorario da sopra
local function dir(a: number): Vector3
	local r = math.rad(a)
	return Vector3.new(math.sin(r), 0, math.cos(r))
end

-- i punti di gioco in metri, nello spazio del modello (come Markers.json del cloud)
local function spotsInMeters(): { [string]: Vector3 }
	local s: { [string]: Vector3 } = {
		SPOT_Arrivo = Vector3.new(0, 0.9, 160), -- piattaforma delle rune, 65 m davanti al portale
		SPOT_Domatore = Vector3.new(0, 12, ARENA_IN - 3), -- balcone sopra l'arco, lato interno
		SPOT_Altare = Vector3.new(-20, 0, ARENA_IN - 20), -- dentro, vicino al portale
	}
	for k = 1, 8 do
		local a = (k - 1) * 45
		s["SPOT_Posatoio" .. k] = dir(a) * (ARENA_IN + WALL_T / 2) + Vector3.new(0, WALL_H + 4, 0)
		local el = IsolaDraghi.TOWERS[k]
		s["SPOT_Statua_" .. el] = dir(a + 22.5) * ((ARENA_IN + WALL_T / 2) / math.cos(math.rad(22.5))) + Vector3.new(0, TOWER_H, 0)
	end
	for k = 1, 4 do
		s["SPOT_Cascata" .. k] = dir(60 + k * 72) * 190
	end
	return s
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- cilindro verticale (le parti Cylinder di Roblox hanno l'asse lungo X)
local function disk(parent: Instance, name: string, radius: number, height: number, at: Vector3, color: Color3, material: Enum.Material): Part
	return part(parent, name, Vector3.new(height, radius * 2, radius * 2), CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
end

-- Sagoma provvisoria in studs, nello spazio di ORIGIN (pavimento dell'arena = y 0)
local function buildPlaceholder(folder: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "Sagoma"
	local function w(v: Vector3): Vector3 -- metri del modello -> mondo
		return origin:PointToWorldSpace(v * M)
	end
	-- isola: piano di prato e roccia a cono rovesciato (strati sempre piu' stretti)
	disk(model, "Isola_Prato", 200 * M, 6 * M, w(Vector3.new(0, -3, 20)), GRASS, Enum.Material.Grass)
	local layers = { { 196, 30 }, { 170, 35 }, { 135, 35 }, { 95, 35 }, { 50, 30 } }
	local y = -6
	for k, l in layers do
		y -= l[2] / 2
		disk(model, "Isola_Roccia_" .. k, l[1] * M, l[2] * M, w(Vector3.new(0, y, 20)), if k % 2 == 0 then BASALT else STONE, Enum.Material.Basalt)
		y -= l[2] / 2
	end
	-- pavimento dell'arena: sabbia con il cerchio di rune
	disk(model, "Arena_Pavimento", (ARENA_IN + 2) * M, 1 * M, w(Vector3.new(0, -0.5, 0)), SAND, Enum.Material.Sand)
	disk(model, "Arena_Rune", 35 * M, 0.2 * M, w(Vector3.new(0, 0.05, 0)), GOLD, Enum.Material.Neon).Transparency = 0.6
	disk(model, "Arena_RuneDentro", 34 * M, 0.25 * M, w(Vector3.new(0, 0.06, 0)), SAND, Enum.Material.Sand)
	-- mura: 8 lati (il lato 1, verso +Z, ha il portale largo 20 m e alto 30 m)
	local side = 2 * (ARENA_IN + WALL_T) * math.tan(math.rad(22.5))
	for k = 1, 8 do
		local a = (k - 1) * 45
		local center = dir(a) * (ARENA_IN + WALL_T / 2)
		local cf = origin * CFrame.lookAt(center * M, Vector3.zero) -- guarda verso il centro
		if k == 1 then
			local half = (side - 20) / 2
			for _, s in { -1, 1 } do
				part(model, "Arena_Mura_01", Vector3.new(half, WALL_H, WALL_T) * M, cf * CFrame.new(s * (10 + half / 2) * M, WALL_H / 2 * M, 0), STONE, Enum.Material.Slate)
			end
			-- architrave sopra il portale e il palco del domatore dietro
			part(model, "Arena_Portale", Vector3.new(24, 4, WALL_T + 2) * M, cf * CFrame.new(0, 32 * M, 0), BASALT, Enum.Material.Basalt)
			for _, s in { -1, 1 } do
				part(model, "Arena_Portale", Vector3.new(4, 34, WALL_T + 2) * M, cf * CFrame.new(s * 12 * M, 17 * M, 0), BASALT, Enum.Material.Basalt)
				part(model, "Arena_Portale_Oro", Vector3.new(4.4, 1.2, WALL_T + 2.4) * M, cf * CFrame.new(s * 12 * M, 33 * M, 0), GOLD, Enum.Material.Metal)
			end
		else
			part(model, string.format("Arena_Mura_%02d", k), Vector3.new(side, WALL_H, WALL_T) * M, cf * CFrame.new(0, WALL_H / 2 * M, 0), STONE, Enum.Material.Slate)
		end
		-- fascia di bronzo in cima, sul bordo esterno (lungo quanto il lato; dentro sporgeva agli angoli)
		part(model, "Arena_Fascia", Vector3.new(side, 1, 1) * M, cf * CFrame.new(0, (WALL_H + 0.5) * M, (WALL_T / 2 - 0.5) * M), BRONZE, Enum.Material.Metal)
	end
	-- palco del domatore: balcone sopra l'arco, lato interno
	local tamerCf = origin * CFrame.lookAt(Vector3.new(0, 12, ARENA_IN - 3) * M, Vector3.new(0, 12, 0) * M)
	part(model, "Arena_Palco", Vector3.new(14, 1, 7) * M, tamerCf * CFrame.new(0, -0.5 * M, 0), BASALT, Enum.Material.Basalt)
	part(model, "Arena_Palco_Parapetto", Vector3.new(14, 1.1, 0.4) * M, tamerCf * CFrame.new(0, 0.55 * M, -3.3 * M), BRONZE, Enum.Material.Metal)
	-- torri agli angoli, una per elemento, con stendardo e braciere
	local towerAt = (ARENA_IN + WALL_T / 2) / math.cos(math.rad(22.5))
	for k, el in IsolaDraghi.TOWERS do
		local p = dir((k - 1) * 45 + 22.5) * towerAt
		disk(model, "Arena_Torre_" .. el, TOWER_R * M, TOWER_H * M, w(p + Vector3.new(0, TOWER_H / 2, 0)), STONE, Enum.Material.Slate)
		disk(model, "Arena_Braciere_" .. el, (TOWER_R - 2) * M, 2 * M, w(p + Vector3.new(0, TOWER_H + 1, 0)), BRONZE, Enum.Material.Metal)
		local ember = disk(model, "Arena_Brace_" .. el, (TOWER_R - 3) * M, 1 * M, w(p + Vector3.new(0, TOWER_H + 2, 0)), ELEMENT_COLORS[el] or GOLD, Enum.Material.Neon)
		local fire = Instance.new("Fire")
		fire.Size = 25
		fire.Heat = 20
		fire.Color = ELEMENT_COLORS[el] or Color3.fromRGB(255, 140, 50)
		fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
		fire.Parent = ember
		local light = Instance.new("PointLight")
		light.Color = ELEMENT_COLORS[el] or Color3.fromRGB(255, 160, 80)
		light.Range = 60
		light.Brightness = 3
		light.Parent = ember
		local out = dir((k - 1) * 45 + 22.5)
		part(model, "Arena_Stendardo_" .. el, Vector3.new(6, 16, 0.3) * M, CFrame.lookAt(w(p + out * (TOWER_R + 0.3) + Vector3.new(0, TOWER_H - 12, 0)), w(p + out * (TOWER_R + 5) + Vector3.new(0, TOWER_H - 12, 0))), ELEMENT_COLORS[el] or GOLD, Enum.Material.Fabric)
	end
	-- altare del duello
	part(model, "Arena_Altare", Vector3.new(5, 2, 3) * M, origin * CFrame.new(Vector3.new(-20, 1, ARENA_IN - 20) * M), BASALT, Enum.Material.Basalt)
	part(model, "Arena_Altare_Rune", Vector3.new(5.2, 0.3, 3.2) * M, origin * CFrame.new(Vector3.new(-20, 2.1, ARENA_IN - 20) * M), Color3.fromRGB(220, 40, 40), Enum.Material.Neon)
	-- arrivo: piattaforma tonda con 3 gradini e cerchio di rune, sentiero fino al portale
	for k = 0, 2 do
		disk(model, "Arrivo", (8 + (2 - k) * 0.35) * M, 0.3 * M, w(Vector3.new(0, 0.15 + k * 0.3, 160)), BASALT, Enum.Material.Basalt)
	end
	-- cerchio di rune: anello d'oro (disco di Neon coperto al centro dal basalto)
	disk(model, "Arrivo_Rune", 6 * M, 0.1 * M, w(Vector3.new(0, 0.95, 160)), GOLD, Enum.Material.Neon).Transparency = 0.4
	disk(model, "Arrivo_Centro", 5.4 * M, 0.12 * M, w(Vector3.new(0, 0.96, 160)), BASALT, Enum.Material.Basalt)
	local pathFrom, pathTo = Vector3.new(0, 0.1, 152), Vector3.new(0, 0.1, ARENA_IN + WALL_T)
	part(model, "Isola_Sentiero", Vector3.new(4, 0.2, (pathFrom - pathTo).Magnitude) * M, origin * CFrame.new((pathFrom + pathTo) / 2 * M), Color3.fromRGB(120, 110, 100), Enum.Material.Cobblestone)
	-- da lontano resta visibile come una mesh leggera
	pcall(function()
		(model :: any).LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	model.Parent = folder
end

-- Il modello vero del cloud (ServerStorage.CaseCodex.IsolaDraghi, in metri, origine = pavimento
-- dell'arena): copia senza script, in scala, con collisioni e luci gia' pronte dal caricamento
local function buildReal(folder: Instance, origin: CFrame, template: Model): { [string]: Vector3 }
	local m = template:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m:PivotTo(CFrame.identity)
	m:ScaleTo(M)
	-- le luci sono in metri (attributo RangeM, vedi carica_modelli.luau); i bracieri delle torri
	-- (FX_Fire_<Elemento>) hanno fuoco e luce del colore dell'elemento, grandi da vedersi da lontano
	for _, l in m:GetDescendants() do
		if l:IsA("PointLight") and l:GetAttribute("RangeM") then
			l.Range = math.min(60, (l:GetAttribute("RangeM") :: number) * M)
		elseif l:IsA("Fire") then
			local el = string.match(l.Parent and l.Parent.Name or "", "^FX_Fire_(.+)$")
			local color = el and ELEMENT_COLORS[el]
			l.Size = if color then 22 else math.min(30, l.Size * M)
			l.Heat = if color then 18 else l.Heat
			if color then
				l.Color = color
				l.SecondaryColor = color:Lerp(Color3.new(1, 1, 1), 0.4)
				local glow = Instance.new("PointLight")
				glow.Color = color
				glow.Range = 45
				glow.Brightness = 3
				glow.Shadows = false
				glow.Parent = l.Parent
			end
		end
	end
	-- (le colline del prato non hanno scatole di collisione: ci pensa il Terrain, vedi pratoTerreno)
	local oldCol = m:FindFirstChild("PratoCollisione")
	if oldCol then
		oldCol:Destroy()
	end
	m:PivotTo(origin)
	pcall(function()
		(m :: any).LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	m.Name = "Modello"
	m.Parent = folder
	-- i marcatori SPOT_* del modello (in metri, spazio del modello) al posto di quelli stimati
	local spots: { [string]: Vector3 } = {}
	local holder = m:FindFirstChild("Luci")
	local store = template.Parent
	local perch = store and store:FindFirstChild("PosatoioDrago")
	for _, a in (if holder then holder:GetChildren() else {}) :: { Instance } do
		if a:IsA("Attachment") and string.sub(a.Name, 1, 5) == "SPOT_" then
			spots[a.Name] = origin:PointToObjectSpace(a.WorldPosition) / M
			-- sulle isolette: il posatoio del cloud (tronco con la base di pietra)
			if perch and perch:IsA("Model") and string.find(a.Name, "^SPOT_PosatoioIsola") then
				local p = perch:Clone()
				for _, d in p:GetDescendants() do
					if d:IsA("LuaSourceContainer") then
						d:Destroy()
					end
				end
				p:PivotTo(CFrame.identity)
				p:ScaleTo(M)
				p:PivotTo(CFrame.new(a.WorldPosition) * origin.Rotation)
				p.Name = "Posatoio_" .. string.sub(a.Name, 6)
				p.Parent = m
			end
		end
	end
	return spots
end

-- Le colline del prato non hanno collisioni (scheda del cloud). La collisione precisa della mesh
-- riempiva le conche con scafi convessi e copriva perfino la piattaforma d'arrivo (il giocatore
-- nasceva dentro e cadeva nell'oceano): sotto il prato si stende invece uno strato di Terrain che
-- segue le altezze della mesh. Le altezze stanno nel modello (StringValue "PratoAltezze", griglia
-- in metri ricavata dal JSON di Isola_Prato: tools/modelli, vedi AGENTS.md) e il terreno si rifa'
-- a ogni build (Generate() cancella il Terrain).
local function pratoTerreno(template: Model, origin: CFrame): number
	local sv = template:FindFirstChild("PratoAltezze")
	if not (sv and sv:IsA("StringValue")) then
		return 0
	end
	local ok, g = pcall(function()
		return game:GetService("HttpService"):JSONDecode(sv.Value)
	end)
	if not ok or type(g) ~= "table" then
		return 0
	end
	local cell = g.step * M
	local thick = 14
	local terrain = workspace.Terrain
	local n = 0
	local k = 0
	for value in string.gmatch(g.h .. ",", "([^,]*),") do
		if value ~= "" then
			local i, j = k // g.nz, k % g.nz
			local x, z = g.minX + i * g.step, g.minZ + j * g.step
			local top = (tonumber(value) :: number) / 10 * M - 0.8 -- appena sotto l'erba della mesh
			local p = origin:PointToWorldSpace(Vector3.new(x * M, top - thick / 2, z * M))
			terrain:FillBlock(CFrame.new(p), Vector3.new(cell + 1, thick, cell + 1), Enum.Material.LeafyGrass)
			n += 1
			if n % 2000 == 0 then
				task.wait()
			end
		end
		k += 1
	end
	return n
end

function IsolaDraghi.build(): Folder
	local old = workspace:FindFirstChild("IsolaDraghi")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "IsolaDraghi"
	local origin = IsolaDraghi.ORIGIN
	local spots = spotsInMeters()
	local store = ServerStorage:FindFirstChild("CaseCodex")
	local template = store and store:FindFirstChild("IsolaDraghi")
	if template and template:IsA("Model") and template:FindFirstChild("Mesh") then
		for name, p in buildReal(folder, origin, template) do
			spots[name] = p
		end
		folder:SetAttribute("Provvisoria", false)
		folder:SetAttribute("CelleTerreno", pratoTerreno(template, origin))
	else
		buildPlaceholder(folder, origin)
		folder:SetAttribute("Provvisoria", true)
	end
	-- punti di gioco: parti invisibili (per il server e per le prove in Studio)
	local points = Instance.new("Folder")
	points.Name = "Punti"
	for name, p in spots do
		local mk = Instance.new("Part")
		mk.Name = name
		mk.Anchored, mk.CanCollide, mk.CanQuery, mk.CanTouch = true, false, false, false
		mk.Transparency = 1
		mk.Size = Vector3.one * 2
		mk.CFrame = origin * CFrame.new(p * M)
		mk.Parent = points
	end
	points.Parent = folder
	folder.Parent = workspace
	local function at(name: string): Vector3?
		local p = spots[name]
		return if p then origin:PointToWorldSpace(p * M) else nil
	end
	workspace:SetAttribute("DragonIslandCenter", origin.Position)
	workspace:SetAttribute("DragonIslandArrival", at("SPOT_Arrivo"))
	workspace:SetAttribute("DragonIslandTamer", at("SPOT_Domatore"))
	workspace:SetAttribute("DragonIslandAltar", at("SPOT_Altare"))
	print(string.format("[IsolaDraghi] %s, %d punti", if folder:GetAttribute("Provvisoria") then "sagoma provvisoria" else "modello del cloud", #points:GetChildren()))
	return folder
end

return IsolaDraghi
