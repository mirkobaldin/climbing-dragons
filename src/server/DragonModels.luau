--!strict
-- Modelli di draghi e uova: prende i tuoi modelli (in ServerStorage o nel Workspace, con
-- "dragon"/"drago" o "egg"/"uovo" nel nome), li ripulisce (niente script, niente fisica),
-- li trasforma in Model anche se sono Accessory, li colora per elemento e li ridimensiona.
-- Se non ci sono modelli, costruisce draghetti e uova a blocchi.
--
-- Ogni modello prodotto ha l'attributo "Rig":
--   "bones"  mesh con ossa (es. Sea Dragon): il client anima le ossa (tentacoli, pinne...)
--   "parts"  piu' parti con nome (ali, coda, testa): il client anima le parti
--   "mesh"   una sola mesh senza ossa: il client anima il corpo intero (volo, respiro)

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)

local DragonModels = {}

type Template = { model: Model, element: string? }

local EGG_WORDS = { "egg", "uovo", "uova" }
local DRAGON_WORDS = { "dragon", "drago", "draghi", "wyvern" }
local IGNORE = { DragonSkull = true, DragonRibs = true }
-- Monumenti della mappa, non draghi: con "Dragon" nel nome finivano tra i draghi da far nascere
-- (anche le copie, es. "DragonSkull_copia")
local NOT_A_DRAGON = { "skull", "teschio", "cranio", "ribs", "costato" }

local function hasWord(name: string, words: { string }): boolean
	local lower = string.lower(name)
	for _, w in words do
		if string.find(lower, w, 1, true) then
			return true
		end
	end
	return false
end

-- Dimensione vera delle mesh degli Accessory (SpecialMesh): la chiediamo a Roblox una volta
local meshSizeCache: { [string]: Vector3 } = {}
local function specialMeshSize(part: BasePart, mesh: SpecialMesh): Vector3
	if mesh.MeshType ~= Enum.MeshType.FileMesh or mesh.MeshId == "" then
		return part.Size * mesh.Scale
	end
	local cached = meshSizeCache[mesh.MeshId]
	if not cached then
		local ok, mp = pcall(function()
			return AssetService:CreateMeshPartAsync(mesh.MeshId)
		end)
		cached = if ok and mp then (mp :: MeshPart).MeshSize else part.Size
		if ok and mp then
			(mp :: MeshPart):Destroy()
		end
		meshSizeCache[mesh.MeshId] = cached :: Vector3
	end
	return (cached :: Vector3) * mesh.Scale
end

-- Accessory/Tool/Model -> Model pulito e ancorato, con PrimaryPart e pivot al centro
local function clean(source: Instance): Model
	local model = Instance.new("Model")
	model.Name = source.Name
	for key, value in source:GetAttributes() do
		-- gli attributi RBX_ li scrive Studio (es. RBX_ReimportId dell'import 3D): copiarli
		-- da script e' vietato e l'errore fermava l'avvio di tutto il server
		if string.sub(key, 1, 4) ~= "RBX_" then
			model:SetAttribute(key, value) -- es. "Yaw" per girare il muso
		end
	end
	for _, child in source:GetChildren() do
		child:Clone().Parent = model
	end
	for _, d in model:GetDescendants() do
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("Humanoid")
			or d:IsA("AnimationController")
			or d:IsA("Camera")
			or d:IsA("WeldConstraint")
			or d:IsA("JointInstance")
			or d:IsA("ValueBase")
			or (d:IsA("Folder") and d.Name == "InitialPoses")
		then
			d:Destroy()
		elseif d:IsA("Attachment") and not d:IsA("Bone") and d.Parent and d.Parent:IsA("BasePart") and d:FindFirstChildWhichIsA("ParticleEmitter") == nil then
			d:Destroy() -- attacchi degli accessori (HatAttachment...)
		end
	end
	local biggest: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.CastShadow = true
			if d.Transparency < 1 and (not biggest or d.Size.Magnitude > (biggest :: BasePart).Size.Magnitude) then
				biggest = d
			end
		end
	end
	-- il pivot interno della parte principale va azzerato: alcune mesh importate (es. il drago
	-- Ombra da Blender) ce l'hanno ruotato di 90 gradi e il drago finiva sdraiato su un fianco
	if biggest then
		(biggest :: BasePart).PivotOffset = CFrame.identity
	end
	model.PrimaryPart = biggest
	-- pivot al centro, ma con l'orientamento del modello originale (quello che abbiamo
	-- raddrizzato in Studio), non quello del pezzo piu' grande: un guscio importato sdraiato
	-- faceva sdraiare l'uovo ogni volta che veniva piazzato "dritto"
	local cf = model:GetBoundingBox()
	local rotation = if source:IsA("PVInstance") then (source :: PVInstance):GetPivot().Rotation else CFrame.identity
	model.WorldPivot = CFrame.new(cf.Position) * rotation
	return model
end

-- Grandezza visibile del modello (considera le SpecialMesh degli Accessory)
local function extent(model: Model): number
	local special = false
	local biggest = 0
	for _, d in model:GetDescendants() do
		if d:IsA("SpecialMesh") and d.Parent and d.Parent:IsA("BasePart") then
			special = true
			local s = specialMeshSize(d.Parent :: BasePart, d)
			biggest = math.max(biggest, s.X, s.Y, s.Z)
		end
	end
	if special then
		return math.max(biggest, 0.1)
	end
	local _, size = model:GetBoundingBox()
	return math.max(size.X, size.Y, size.Z, 0.1)
end

-- Ridimensiona in modo che il lato piu' lungo sia "size" studs
local function resize(model: Model, size: number)
	local factor = size / extent(model)
	local hasSpecial = model:FindFirstChildWhichIsA("SpecialMesh", true) ~= nil
	if not hasSpecial then
		model:ScaleTo(model:GetScale() * factor)
		return
	end
	-- Accessory: le SpecialMesh non seguono ScaleTo, le scaliamo a mano
	local pivot = model:GetPivot()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(d.CFrame)
			d.Size *= factor
			d.CFrame = pivot * (rel - rel.Position + rel.Position * factor)
		elseif d:IsA("SpecialMesh") then
			d.Scale *= factor
			d.Offset *= factor
		elseif d:IsA("ParticleEmitter") then
			local keys = {}
			for _, k in d.Size.Keypoints do
				table.insert(keys, NumberSequenceKeypoint.new(k.Time, k.Value * factor, k.Envelope * factor))
			end
			d.Size = NumberSequence.new(keys)
		end
	end
end

-- Colora un modello generico con il colore dell'elemento
local function tint(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("SpecialMesh") then
			d.VertexColor = Vector3.new(color.R, color.G, color.B) * 1.25
		elseif d:IsA("SurfaceAppearance") then
			pcall(function()
				(d :: any).Color = color
			end)
		elseif d:IsA("BasePart") and not d:FindFirstChildOfClass("SurfaceAppearance") and not d:FindFirstChildOfClass("SpecialMesh") then
			if d:IsA("MeshPart") and d.TextureID ~= "" then
				continue
			end
			d.Color = color
		end
	end
end

local function addGlow(model: Model, color: Color3, rarity: any)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = root
	if rarity.sparkle then
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(rarity.color)
		e.Size = NumberSequence.new(0.35, 0)
		e.Lifetime = NumberRange.new(0.6, 1.2)
		e.Rate = 8
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e.Parent = root
	end
	if rarity.id == "Leggendario" then
		local h = Instance.new("Highlight")
		h.FillTransparency = 1
		h.OutlineColor = rarity.color
		h.OutlineTransparency = 0.2
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
	end
end

------------------------------------------------------------------------------------------
-- Modelli a blocchi (se non ci sono i tuoi)

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, anim: string?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if anim then
		p:SetAttribute("Anim", anim)
	end
	p.Parent = model
	return p
end

-- Draghetto a blocchi lungo ~4 studs, muso verso -Z. Le parti hanno l'attributo "Anim"
-- (wing/tail/head) cosi' il client sa cosa muovere.
local function builtDragon(element: DragonConfig.Element): Model
	local m = Instance.new("Model")
	local c, a = element.color, element.accent
	local body = part(m, "Body", Vector3.new(1.4, 1.3, 2.2), CFrame.new(), c)
	body.Shape = Enum.PartType.Block
	part(m, "Belly", Vector3.new(1.1, 0.6, 1.8), CFrame.new(0, -0.45, 0), a)
	local head = part(m, "Head", Vector3.new(1, 0.9, 1.1), CFrame.new(0, 0.7, -1.5), c, "head")
	part(m, "Snout", Vector3.new(0.7, 0.5, 0.7), CFrame.new(0, 0.55, -2.2), c, "head")
	for _, s in { -1, 1 } do
		part(m, "Eye", Vector3.new(0.18, 0.22, 0.1), CFrame.new(s * 0.3, 0.9, -2.03), Color3.new(0.05, 0.05, 0.05), "head")
		local horn = Instance.new("WedgePart")
		horn.Name = "Horn"
		horn.Size = Vector3.new(0.15, 0.6, 0.4)
		horn.CFrame = CFrame.new(s * 0.3, 1.35, -1.25) * CFrame.Angles(0, math.pi, 0)
		horn.Color = a
		horn.Anchored = true
		horn.CanCollide = false
		horn.CanQuery = false
		horn:SetAttribute("Anim", "head")
		horn.Parent = m
		-- ali: due cunei sottili ciascuna, con l'articolazione vicino alla schiena
		for k = 0, 1 do
			local w = Instance.new("WedgePart")
			w.Name = "Wing"
			w.Size = Vector3.new(0.08, 0.9 - k * 0.3, 1.5 - k * 0.4)
			w.CFrame = CFrame.new(s * (0.9 + k * 0.9), 0.75, 0.1 + k * 0.2) * CFrame.Angles(0, 0, s * math.rad(80))
			w.Color = if k == 0 then c else a
			w.Material = Enum.Material.SmoothPlastic
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w:SetAttribute("Anim", "wing")
			w:SetAttribute("Side", s)
			w:SetAttribute("Hinge", Vector3.new(s * 0.6, 0.7, 0.1))
			w.Parent = m
		end
		part(m, "Leg", Vector3.new(0.35, 0.6, 0.35), CFrame.new(s * 0.45, -0.8, -0.6), c)
		part(m, "Leg", Vector3.new(0.35, 0.6, 0.35), CFrame.new(s * 0.45, -0.8, 0.6), c)
	end
	for k = 1, 4 do
		local t = part(m, "Tail" .. k, Vector3.new(0.7 - k * 0.12, 0.6 - k * 0.1, 0.8), CFrame.new(0, 0.1 - k * 0.08, 1.1 + k * 0.7), if k % 2 == 0 then a else c, "tail")
		t:SetAttribute("Index", k)
	end
	m.PrimaryPart = body
	m.WorldPivot = body.CFrame
	head.Name = "Head"
	return m
end

local function builtEgg(element: DragonConfig.Element): Model
	local m = Instance.new("Model")
	local shell = part(m, "Shell", Vector3.new(2, 2.5, 2), CFrame.new(), element.color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shell
	shell.Material = Enum.Material.SmoothPlastic
	shell.Reflectance = 0.1
	local rng = Random.new()
	for _ = 1, 7 do
		local a, b = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(-0.8, 0.8)
		local pos = Vector3.new(math.cos(a) * math.sqrt(1 - b * b), b * 1.25, math.sin(a) * math.sqrt(1 - b * b))
		local spot = part(m, "Spot", Vector3.new(0.35, 0.35, 0.35), CFrame.new(pos * Vector3.new(0.98, 1, 0.98)), element.accent)
		spot.Shape = Enum.PartType.Ball
	end
	m.PrimaryPart = shell
	m.WorldPivot = shell.CFrame
	return m
end

------------------------------------------------------------------------------------------

local templates: { eggs: { Template }, dragons: { Template } }? = nil

local function scanTemplates(): { eggs: { Template }, dragons: { Template } }
	local found = { eggs = {}, dragons = {} }
	local function consider(inst: Instance)
		if IGNORE[inst.Name] or hasWord(inst.Name, NOT_A_DRAGON) or not (inst:IsA("Model") or inst:IsA("Accessory") or inst:IsA("Tool")) then
			return
		end
		if not inst:FindFirstChildWhichIsA("BasePart", true) then
			return
		end
		local isEgg = hasWord(inst.Name, EGG_WORDS)
		local isDragon = not isEgg and hasWord(inst.Name, DRAGON_WORDS)
		if isEgg or isDragon then
			local t = { model = clean(inst), element = DragonConfig.elementForName(inst.Name) }
			table.insert(if isEgg then found.eggs else found.dragons, t)
		end
	end
	local function scanFolder(folder: Instance)
		for _, child in folder:GetChildren() do
			if child:IsA("Folder") and (child.Name == "Cestino" or child.Name == "ModelliSorgente") then
				continue -- roba scartata o sorgenti da Blender: non sono modelli del gioco
			elseif child:IsA("Folder") then
				scanFolder(child)
			else
				consider(child)
			end
		end
	end
	scanFolder(ServerStorage)
	-- anche i modelli lasciati nel Workspace (solo quelli in cima, non la mappa)
	for _, child in workspace:GetChildren() do
		consider(child)
	end
	print(string.format("[Draghi] Modelli trovati: %d draghi, %d uova", #found.dragons, #found.eggs))
	return found
end

local function getTemplates(): { eggs: { Template }, dragons: { Template } }
	if not templates then
		templates = scanTemplates()
	end
	return templates :: any
end

-- Sceglie il modello per un elemento: prima quelli con il nome giusto, poi quelli generici
-- (a turno, ricolorati); element-specifici di altri elementi solo se non c'e' altro
local function choose(list: { Template }, element: string, index: number): (Template?, boolean)
	for _, t in list do
		if t.element == element then
			return t, false
		end
	end
	local generic = {}
	for _, t in list do
		if not t.element then
			table.insert(generic, t)
		end
	end
	if #generic > 0 then
		return generic[(index - 1) % #generic + 1], true
	end
	if #list > 0 then
		return list[(index - 1) % #list + 1], true
	end
	return nil, true
end

local function elementIndex(id: string): number
	for k, e in DragonConfig.ELEMENTS do
		if e.id == id then
			return k
		end
	end
	return 1
end

local function rigKind(model: Model): string
	if model:FindFirstChildWhichIsA("Bone", true) then
		return "bones"
	end
	local named = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local n = string.lower(d.Name)
			if d:GetAttribute("Anim") or string.find(n, "wing") or string.find(n, "tail") or string.find(n, "ala") or string.find(n, "coda") then
				named += 1
			end
		end
	end
	return if named > 0 then "parts" else "mesh"
end

-- Uovo pronto da mettere nel mondo (pivot al centro)
function DragonModels.egg(elementId: string, rarityId: string): Model
	local element = DragonConfig.element(elementId) or DragonConfig.ELEMENTS[1]
	local rarity = DragonConfig.rarity(rarityId)
	local list = getTemplates().eggs
	-- le rarita' alte usano (se c'e') un modello diverso da quelle comuni
	local index = elementIndex(element.id) + (if rarity.sparkle then 1 else 0)
	local t, generic = choose(list, element.id, index)
	local model: Model
	if t then
		model = t.model:Clone()
		if generic then
			tint(model, element.color)
		end
	else
		model = builtEgg(element)
	end
	resize(model, DragonConfig.EGG_SIZE * (if rarity.id == "Leggendario" then 1.25 else 1))
	addGlow(model, element.glow, rarity)
	model.Name = "Uovo " .. element.id
	model:SetAttribute("Element", element.id)
	model:SetAttribute("Rarity", rarity.id)
	return model
end

-- Drago (cucciolo, giovane o adulto) pronto da far seguire al giocatore
function DragonModels.dragon(elementId: string, rarityId: string, stage: number): Model
	local element = DragonConfig.element(elementId) or DragonConfig.ELEMENTS[1]
	local rarity = DragonConfig.rarity(rarityId)
	local st = DragonConfig.STAGES[math.clamp(stage, 1, #DragonConfig.STAGES)]
	local t, generic = choose(getTemplates().dragons, element.id, elementIndex(element.id))
	local model: Model
	if t then
		model = t.model:Clone()
		if generic then
			tint(model, element.color)
		end
	else
		model = builtDragon(element)
	end
	resize(model, st.size * (if rarity.id == "Leggendario" then 1.2 elseif rarity.id == "Epico" then 1.1 else 1))
	addGlow(model, element.glow, rarity)
	if element.id == "Brace" and model.PrimaryPart then
		local light = Instance.new("PointLight")
		light.Name = "BraceLight"
		light.Color = element.glow
		light.Range = 26
		light.Brightness = 2
		light.Shadows = true
		light.Parent = model.PrimaryPart
	end
	model.Name = element.name
	model:SetAttribute("Rig", rigKind(model))
	model:SetAttribute("Element", element.id)
	model:SetAttribute("Rarity", rarity.id)
	model:SetAttribute("Stage", stage)
	return model
end

-- Modello "grande" di un drago con le ossa (per il futuro boss della vetta), se esiste
function DragonModels.bossTemplate(): Model?
	for _, t in getTemplates().dragons do
		if t.model:FindFirstChildWhichIsA("Bone", true) then
			return t.model
		end
	end
	return nil
end

function DragonModels.preload()
	getTemplates()
end

-- Anteprime per l'interfaccia (ViewportFrame): un drago e un uovo per elemento in
-- ReplicatedStorage.Previews, cosi' il client puo' mostrarli nel menu senza immagini caricate
function DragonModels.makePreviews()
	local old = ReplicatedStorage:FindFirstChild("Previews")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Previews"
	for _, kind in { "Dragons", "Eggs" } do
		local sub = Instance.new("Folder")
		sub.Name = kind
		sub.Parent = folder
		for _, e in DragonConfig.ELEMENTS do
			local ok, model = pcall(function()
				return if kind == "Dragons" then DragonModels.dragon(e.id, "Comune", 1) else DragonModels.egg(e.id, "Comune")
			end)
			if ok and model then
				model.Name = e.id
				for _, d in model:GetDescendants() do
					if d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Highlight") then
						d:Destroy()
					end
				end
				model.Parent = sub
			end
		end
	end
	folder.Parent = ReplicatedStorage
end

return DragonModels
