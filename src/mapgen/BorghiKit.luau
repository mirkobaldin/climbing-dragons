--!strict
-- Modelli dei borghi fatti in Blender (tools/blender/borghi.py -> tools/blender/out/borghi.fbx).
-- 1) In Studio: File > Import 3D > borghi.fbx (finisce in Workspace)
-- 2) Command Bar: require(game.ServerStorage.MapGen:Clone().BorghiKit).prepare()
--    sposta i modelli in ServerStorage.BorghiKit, colora ogni pezzo dal suffisso del nome
--    ("CasaFenghuang__TILE" -> coppi), rimette la scala in stud, mette il pivot nell'origine del
--    modello (segnaposto "__ORIGIN") col davanti verso l'ingresso ("__FRONT") e aggiunge le
--    collisioni: scatole invisibili prese da BorghiCollide (generato dallo script di Blender), cosi'
--    nelle porte si passa, sulle scale si sale e i pavimenti reggono.
-- 3) Command Bar: require(game.ServerStorage.MapGen:Clone().Borghi).build()  (rifa' i borghi)

local ServerStorage = game:GetService("ServerStorage")

local BorghiCollide = require(script.Parent.BorghiCollide)
local BorghiTextures = require(script.Parent.BorghiTextures)

local BorghiKit = {}

local M = Enum.Material
type Look = { color: Color3, material: Enum.Material, hull: boolean?, precise: boolean?, alpha: number?, plain: boolean? }
-- colore e materiale di ogni pezzo; hull = il pezzo si urta (i tetti: ci si puo' salire sopra)
local LOOK: { [string]: Look } = {
	TILE = { color = Color3.fromRGB(56, 60, 68), material = M.Slate, hull = true },
	SKIRT = { color = Color3.fromRGB(56, 60, 68), material = M.Slate },
	RIDGE = { color = Color3.fromRGB(32, 32, 36), material = M.Slate },
	RIDGEWHITE = { color = Color3.fromRGB(206, 206, 200), material = M.Plaster },
	TIMBER = { color = Color3.fromRGB(104, 66, 40), material = M.WoodPlanks },
	TIMBERDARK = { color = Color3.fromRGB(54, 35, 24), material = M.Wood },
	WOOD = { color = Color3.fromRGB(152, 110, 70), material = M.WoodPlanks },
	PLASTER = { color = Color3.fromRGB(232, 226, 212), material = M.Plaster },
	LACQUER = { color = Color3.fromRGB(166, 32, 26), material = M.SmoothPlastic },
	PAPER = { color = Color3.fromRGB(236, 158, 78), material = M.Neon },
	LANTERN = { color = Color3.fromRGB(226, 48, 36), material = M.Neon },
	STONE = { color = Color3.fromRGB(132, 130, 124), material = M.Cobblestone },
	STONEDARK = { color = Color3.fromRGB(88, 88, 86), material = M.Slate },
	EARTH = { color = Color3.fromRGB(110, 92, 74), material = M.Ground },
	THATCH = { color = Color3.fromRGB(150, 120, 74), material = M.Grass, hull = true },
	TATAMI = { color = Color3.fromRGB(176, 170, 106), material = M.Fabric },
	BAMBOO = { color = Color3.fromRGB(150, 124, 66), material = M.Wood },
	LEAF = { color = Color3.fromRGB(52, 100, 44), material = M.Grass },
	GOLD = { color = Color3.fromRGB(214, 170, 72), material = M.Metal },
	BRONZE = { color = Color3.fromRGB(96, 72, 42), material = M.Metal },
	FABRIC = { color = Color3.fromRGB(36, 52, 92), material = M.Fabric },
	CLOTH = { color = Color3.fromRGB(150, 26, 20), material = M.Fabric },
	CERAMIC = { color = Color3.fromRGB(196, 204, 210), material = M.SmoothPlastic },
	SIGN = { color = Color3.fromRGB(26, 34, 52), material = M.SmoothPlastic },
	METAL = { color = Color3.fromRGB(180, 184, 190), material = M.Metal },
	IRON = { color = Color3.fromRGB(52, 54, 58), material = M.Metal },
	LEATHER = { color = Color3.fromRGB(96, 56, 30), material = M.Fabric },
	GRIP = { color = Color3.fromRGB(20, 20, 20), material = M.Fabric },
	ROPE = { color = Color3.fromRGB(190, 158, 104), material = M.Fabric },
	-- isole volanti: i materiali di Roblox (niente texture: con quelle scaricate facevano schifo)
	ROCK = { color = Color3.fromRGB(105, 102, 96), material = M.Rock, precise = true, plain = true },
	GRASS = { color = Color3.fromRGB(78, 118, 52), material = M.Grass, precise = true, plain = true },
	CRYSTAL = { color = Color3.fromRGB(210, 230, 245), material = M.SmoothPlastic, hull = true }, -- tinta: SurfaceAppearance.Color
	CLOUD = { color = Color3.fromRGB(245, 247, 252), material = M.SmoothPlastic, alpha = 0.08 },
}

-- oggetti che servono anche al client (copiati in ReplicatedStorage.BorghiItems): le nuvole delle clip
BorghiKit.ITEMS = { "NuvolaA", "NuvolaB", "NuvolaC", "NuvolaD" }

function BorghiKit.folder(): Folder?
	local f = ServerStorage:FindFirstChild("BorghiKit")
	return if f and f:IsA("Folder") then f else nil
end

function BorghiKit.get(name: string): Model?
	local f = BorghiKit.folder()
	local m = f and f:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

-- le scatole di collisione del modello (dentro "Collisioni", invisibili)
local function addColliders(model: Model)
	local boxes = (BorghiCollide :: any)[model.Name] :: { { number } }?
	if not boxes then
		return 0
	end
	local old = model:FindFirstChild("Collisioni")
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Model")
	holder.Name = "Collisioni"
	local pivot = model:GetPivot()
	for _, v in boxes :: { { number } } do
		local p = Instance.new("Part")
		p.Name = "Collisione"
		p.Anchored = true
		p.Transparency = 1
		p.CanCollide = true
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(math.max(v[4], 0.05), math.max(v[5], 0.05), math.max(v[6], 0.05))
		p.CFrame = pivot * CFrame.fromMatrix(Vector3.new(v[1], v[2], v[3]), Vector3.new(v[7], v[8], v[9]), Vector3.new(v[10], v[11], v[12]), Vector3.new(v[13], v[14], v[15]))
		p.Parent = holder
	end
	holder.Parent = model
	return #boxes
end

function BorghiKit.prepare(): string
	-- tutti i MeshPart "<Modello>__<MATERIALE>" in Workspace (dove li mette l'importazione)
	-- se lo stesso file e' stato importato due volte si usa solo la prima copia di ogni modello
	-- (prima i pezzi delle due copie finivano nello stesso modello, spostati di 100 stud)
	local groups: { [string]: { MeshPart } } = {}
	local groupRoot: { [string]: Instance } = {}
	local roots: { [Instance]: boolean } = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") then
			local name, mat = string.match(d.Name, "^(.-)__(%u+)$")
			if name and mat and (LOOK[mat] or mat == "FRONT" or mat == "ORIGIN") then
				local top: Instance = d
				while top.Parent and top.Parent ~= workspace do
					top = top.Parent
				end
				roots[top] = true
				-- la copia di un modello e' il suo genitore diretto (il Model col nome del modello)
				local holder = d.Parent :: Instance
				if not groupRoot[name] then
					groupRoot[name] = holder
				end
				if groupRoot[name] == holder then
					groups[name] = groups[name] or {}
					table.insert(groups[name], d)
				end
			end
		end
	end
	local folder = BorghiKit.folder()
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "BorghiKit"
		f.Parent = ServerStorage
		folder = f
	end
	local done = {}
	for name, parts in groups do
		local old = (folder :: Folder):FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = name
		local front: MeshPart?, origin: MeshPart? = nil, nil
		for _, p in parts do
			for _, c in p:GetChildren() do
				if c:IsA("SurfaceAppearance") or c:IsA("Texture") or c:IsA("Decal") then
					c:Destroy()
				end
			end
			p.TextureID = ""
			p.Anchored = true
			p.Parent = model
			local mat = string.match(p.Name, "__(%u+)$") :: string
			if mat == "FRONT" then
				front = p
			elseif mat == "ORIGIN" then
				origin = p
			else
				local look = LOOK[mat]
				p.Color = look.color
				p.Material = look.material
				p.CanCollide = look.hull == true or look.precise == true
				p.CanTouch = false
				p.CastShadow = mat ~= "PAPER" and mat ~= "LANTERN" and mat ~= "CLOUD"
				p.Transparency = look.alpha or 0
				p.Name = mat
				p:SetAttribute("Precise", look.precise == true)
				-- texture (SurfaceAppearance): si puo' mettere solo in Studio, non in gioco
				local tex = if look.plain then nil else BorghiTextures[mat]
				if tex then
					local sa = Instance.new("SurfaceAppearance")
					sa.ColorMap = tex.color
					if tex.normal then
						sa.NormalMap = tex.normal
					end
					if tex.roughness then
						sa.RoughnessMap = tex.roughness
					end
					if tex.metalness then
						sa.MetalnessMap = tex.metalness
					end
					sa.Parent = p
				end
			end
		end
		if not front or not origin then
			model:Destroy()
			continue
		end
		-- scala: i segnaposto sono cubi di 1 stud
		local s = (origin :: MeshPart).Size.X
		model.WorldPivot = CFrame.new((origin :: MeshPart).Position)
		if s > 0.001 and math.abs(s - 1) > 0.02 then
			model:ScaleTo(1 / s)
		end
		local o = (origin :: MeshPart).Position - Vector3.new(0, (origin :: MeshPart).Size.Y / 2, 0)
		local fp = (front :: MeshPart).Position
		local dir = Vector3.new(fp.X - o.X, 0, fp.Z - o.Z)
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, -1)
		;(front :: MeshPart):Destroy()
		;(origin :: MeshPart):Destroy()
		model.WorldPivot = CFrame.lookAt(o, o + dir)
		model:PivotTo(CFrame.new(0, 100, 0)) -- in ServerStorage la posizione non conta
		for _, p in model:GetChildren() do
			if p:IsA("MeshPart") then
				p.CollisionFidelity = if p:GetAttribute("Precise") then Enum.CollisionFidelity.PreciseConvexDecomposition else Enum.CollisionFidelity.Hull
			end
		end
		local n = addColliders(model)
		local _, ps = model:GetBoundingBox()
		model:SetAttribute("Width", ps.X)
		model:SetAttribute("Depth", ps.Z)
		model:SetAttribute("Height", ps.Y)
		model.Parent = folder
		table.insert(done, string.format("%s (%.0fx%.0fx%.0f, %d collisioni)", name, ps.X, ps.Y, ps.Z, n))
	end
	-- via quello che resta dell'importazione (anche le copie doppie)
	for r in roots do
		if r.Parent and not r:IsDescendantOf(folder :: Folder) then
			r:Destroy()
		end
	end
	-- gli oggetti anche in ReplicatedStorage.BorghiItems: il client li usa nelle clip e ServerStorage
	-- non lo vede
	local RS = game:GetService("ReplicatedStorage")
	local items = RS:FindFirstChild("BorghiItems")
	if items then
		items:Destroy()
	end
	local itemFolder = Instance.new("Folder")
	itemFolder.Name = "BorghiItems"
	for _, name in BorghiKit.ITEMS do
		local m = (folder :: Folder):FindFirstChild(name)
		if m then
			local c = m:Clone()
			local col = c:FindFirstChild("Collisioni")
			if col then
				col:Destroy()
			end
			c.Parent = itemFolder
		end
	end
	itemFolder.Parent = RS
	table.sort(done)
	local msg = string.format("[BorghiKit] %d modelli: %s", #done, table.concat(done, ", "))
	print(msg)
	return msg
end

return BorghiKit
