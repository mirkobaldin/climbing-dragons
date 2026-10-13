--!strict
-- Economia e case:
--   * Monete (classifica in alto a destra), salvate da Progression
--   * Vendite e acquisti all'emporio: vedi Shop
--   * Terreni (tag "Plot") in tre zone: campo tende ai piedi della montagna (Tenda), villaggio
--     delle costole del drago (Baita), villette sui costoni (Chalet). Ogni giocatore ha il
--     terreno della zona del suo livello; col cartello compri la Tenda (sblocca il nido) e
--     quando la migliori la casa trasloca nella zona successiva
--   * Draghi posati in casa (quelli che non ti seguono): guadagnano monete al minuto, anche
--     mentre sei offline (in parte)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local Names = require(ReplicatedStorage.Shared.Names)
local EconomyConfig = require(ReplicatedStorage.Shared.EconomyConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local DragonModels = require(script.Parent.DragonModels)
local Dragons = require(script.Parent.Dragons)

local Economy = {}

type State = { coins: number, house: number, lastSeen: number, plot: Model?, pending: number }

local states: { [Player]: State } = {}
local plotOwner: { [Model]: Player } = {}

local function notice(player: Player, text: string)
	player:SetAttribute("Notice", text)
	player:SetAttribute("NoticeTime", os.clock())
end

local function state(player: Player): State
	local s = states[player]
	if not s then
		s = { coins = EconomyConfig.START_COINS, house = 0, lastSeen = os.time(), plot = nil, pending = 0 }
		states[player] = s
	end
	return s
end

local function coinValue(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild("Coins")
	if not v and stats then
		local nv = Instance.new("IntValue")
		nv.Name = "Coins"
		nv.Parent = stats
		v = nv
	end
	return v :: IntValue?
end

local function publish(player: Player)
	local s = state(player)
	local v = coinValue(player)
	if v then
		v.Value = math.floor(s.coins)
	end
	player:SetAttribute("Coins", math.floor(s.coins))
	player:SetAttribute("HouseLevel", s.house)
	local house = EconomyConfig.HOUSES[s.house]
	player:SetAttribute("NestSlots", if house then house.nest else 0)
	player:SetAttribute("RoostSlots", if house then house.roost else 0)
end

function Economy.addCoins(player: Player, amount: number)
	local s = state(player)
	if amount > 0 then
		amount = math.floor(amount * UpgradeConfig.coinMult(player) + 0.5) -- bonus delle rinascite
	end
	s.coins = math.max(0, s.coins + amount)
	publish(player)
end

function Economy.coins(player: Player): number
	return state(player).coins
end

------------------------------------------------------------------------------------------
-- Draghi posati in casa (guadagno AFK)

local function roosting(player: Player): { any }
	local ds = Dragons.state(player)
	local list = {}
	for _, d in ds.dragons do
		if not table.find(ds.equipped, d.id) then
			table.insert(list, d)
		end
	end
	table.sort(list, function(a, b)
		return (EconomyConfig.ROOST_RATE[a.rarity] or 1) * a.stage > (EconomyConfig.ROOST_RATE[b.rarity] or 1) * b.stage
	end)
	local slots = (player:GetAttribute("RoostSlots") or 0) :: number
	local out = {}
	for k = 1, math.min(slots, #list) do
		table.insert(out, list[k])
	end
	return out
end

local function ratePerMinute(player: Player): number
	local rate = 0
	for _, d in roosting(player) do
		rate += (EconomyConfig.ROOST_RATE[d.rarity] or 1) * d.stage
	end
	return rate
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

-- quota del terreno sotto p (o p stesso se non c'e')
local function groundY(p: Vector3): number
	local hit = workspace:Raycast(p + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), groundParams)
	return if hit then hit.Position.Y else p.Y
end

-- ingombro della casa (il modello piu' grande del terreno, non nido o falo') nello spazio del terreno
local function houseBox(plot: Model): (Vector3, Vector3)
	local house = plot:FindFirstChild("House")
	local pivot = plot:GetPivot()
	local best: Model? = nil
	local bestSize = 0
	for _, c in (if house then house:GetChildren() else {}) :: { Instance } do
		if c:IsA("Model") and c.Name ~= "Nido" and c.Name ~= "Campfire" then
			local _, s = c:GetBoundingBox()
			if s.Magnitude > bestSize then
				best, bestSize = c, s.Magnitude
			end
		end
	end
	if not best then
		return Vector3.zero, Vector3.new(16, 10, 16)
	end
	local cf, size = (best :: Model):GetBoundingBox()
	return pivot:PointToObjectSpace(cf.Position), size
end

-- I draghi posati riposano a terra attorno alla casa (prima erano sospesi a mezz'aria sopra il
-- tetto): in cerchio, girati verso la casa, appoggiati al terreno; il client li anima (tag Riposo)
local function refreshRoost(player: Player)
	local s = state(player)
	local plot = s.plot
	if not plot then
		return
	end
	local old = plot:FindFirstChild("Roost")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Roost"
	local anchor = plot:GetPivot()
	local center, size = houseBox(plot)
	local ring = math.max(size.X, size.Z) * 0.5 + 10
	for k, d in roosting(player) do
		local model = DragonModels.dragon(d.element, d.rarity, d.stage)
		local a = (k - 1) / 6 * math.pi * 2 + 0.6
		local at = anchor * (center + Vector3.new(math.cos(a) * ring, 0, math.sin(a) * ring))
		local _, ms = model:GetBoundingBox()
		local base = Vector3.new(at.X, groundY(at) + ms.Y / 2, at.Z)
		local houseAt = anchor * center
		model:PivotTo(CFrame.lookAt(base, Vector3.new(houseAt.X, base.Y, houseAt.Z)))
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		CollectionService:AddTag(model, "Riposo")
		model.Parent = folder
	end
	folder.Parent = plot
	player:SetAttribute("RoostRate", ratePerMinute(player))
end

------------------------------------------------------------------------------------------
-- Terreni e case

local function plotSign(plot: Model): TextLabel?
	local sign = plot:FindFirstChild("PlotSign", true)
	local gui = sign and sign:FindFirstChildOfClass("SurfaceGui")
	return gui and gui:FindFirstChild("Owner") :: TextLabel?
end

-- Punto d'arrivo del teletrasporto: fuori dalla casa, sul terreno o sulla pedana del terreno.
-- Prima si arrivava al centro, cioe' dentro la tenda (non si usciva) o sotto la pedana dello
-- Chalet. Si provano punti attorno al centro: a terra, alla quota del terreno, senza tetto sopra.
local PLOT_HALF = { 22, 30, 34 }
local function plotSpawn(plot: Model): Vector3
	local center = plot:GetPivot()
	local half = PLOT_HALF[(plot:GetAttribute("Level") or 1) :: number] or 24
	local skip = { plot:FindFirstChild("House") }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	local downParams = RaycastParams.new()
	downParams.FilterType = Enum.RaycastFilterType.Exclude
	downParams.FilterDescendantsInstances = skip :: { Instance }
	local house = plot:FindFirstChild("House")
	local upParams = RaycastParams.new()
	upParams.FilterType = Enum.RaycastFilterType.Include
	upParams.FilterDescendantsInstances = if house then { house } else {}
	for _, r in { half * 0.8, half * 0.95, half + 4, half * 0.6 } do
		for k = 0, 11 do
			-- prima davanti alla porta (-Z), poi tutto attorno
			local a = math.pi + (if k % 2 == 0 then 1 else -1) * math.ceil(k / 2) * (math.pi / 6)
			local p = center * Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
			local hit = workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), downParams)
			if hit and hit.Normal.Y > 0.7 and math.abs(hit.Position.Y - center.Y) < 8 then
				local roof = house and workspace:Raycast(hit.Position + Vector3.new(0, 1, 0), Vector3.new(0, 30, 0), upParams)
				if not roof then
					return hit.Position + Vector3.new(0, 3, 0)
				end
			end
		end
	end
	return center.Position + Vector3.new(0, 4, 0)
end

-- Forgia dello Chalet: il banco da lavoro di Mirko (ServerStorage.Modelli.Banco_Crafting) accanto
-- al punto d'arrivo; apre il crafting come il banco del campo base (tag Workbench). Prima era un
-- banco fatto di blocchi (incudine e braciere)
local function buildForge(plot: Model, at: Vector3, deckY: number?)
	local old = plot:FindFirstChild("Forgia")
	if old then
		old:Destroy()
	end
	local forge = Instance.new("Model")
	forge.Name = "Forgia"
	local center = plot:GetPivot()
	local side = center.RightVector
	local base = at + side * 9
	base = Vector3.new(base.X, deckY or groundY(base), base.Z)
	local look = CFrame.lookAt(base, base - side)
	local store = ServerStorage:FindFirstChild("Modelli")
	local t = store and store:FindFirstChild("Banco_Crafting", true)
	if t and t:IsA("Model") then
		local m = t:Clone()
		for _, d in m:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local _, s0 = m:GetBoundingBox()
		m:ScaleTo(m:GetScale() * 7 / math.max(s0.Y, 0.05)) -- alto come quello del campo base
		m:PivotTo(look.Rotation + m:GetPivot().Position)
		local box, sz = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + (base - (box.Position - Vector3.new(0, sz.Y / 2, 0))))
		m.Parent = forge
	end
	-- piano invisibile col prompt (come al campo base)
	local top = Instance.new("Part")
	top.Name = "Bench"
	top.Anchored, top.CanCollide, top.Transparency = true, false, 1
	top.Size = Vector3.new(10, 0.3, 4)
	top.CFrame = look * CFrame.new(0, 3.95, 0)
	top.Parent = forge
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Craft"
	prompt.ObjectText = "Workbench"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = top
	CollectionService:AddTag(top, "Workbench")
	forge.Parent = plot
end

------------------------------------------------------------------------------------------
-- Case nuove di Codex (ServerStorage.CaseCodex: Tent, StoneCabin, ModernChalet, MegaChalet,
-- caricate da tools/modelli): in metri, si ingrandiscono di HOUSE_SCALE e si girano (il loro
-- ingresso guarda +Z, quello dei terreni -Z). Sotto c'e' una pedana di legno grande abbastanza
-- per casa, nido, banco e punto d'arrivo (prima nido e banco finivano fuori, sul terreno).
local CODEX_HOUSE = { Tenda = "Tent", Baita = "StoneCabin", Chalet = "ModernChalet", MegaChalet = "MegaChalet" }
local HOUSE_SCALE = 3.2
local WARM = Color3.fromRGB(255, 196, 130)

-- luci della casa: quelle dei marcatori (in metri) piu' una d'ambiente al centro di ogni piano
local function houseLights(m: Model, scale: number)
	for _, l in m:GetDescendants() do
		if l:IsA("PointLight") then
			l.Range = math.min(40, ((l:GetAttribute("RangeM") or 7) :: number) * scale * 0.9)
			l.Brightness = 1.3
		end
	end
	local holder = m:FindFirstChild("Luci")
	local mesh = m:FindFirstChild("Mesh")
	if not holder or not holder:IsA("BasePart") or not mesh then
		return
	end
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in mesh:GetChildren() do
		if p:IsA("BasePart") then
			lo = lo:Min(p.Position - p.Size / 2)
			hi = hi:Max(p.Position + p.Size / 2)
		end
	end
	if lo.X == math.huge then
		return
	end
	local floors = math.clamp(math.floor((hi.Y - lo.Y) / 16), 1, 3)
	for k = 1, floors do
		local att = Instance.new("Attachment")
		att.Name = "LuceAmbiente" .. k
		att.WorldPosition = Vector3.new((lo.X + hi.X) / 2, lo.Y + (k - 0.45) * (hi.Y - lo.Y) / (floors + 0.6), (lo.Z + hi.Z) / 2)
		att.Parent = holder
		local pl = Instance.new("PointLight")
		pl.Color = WARM
		pl.Range = math.min(48, math.max(hi.X - lo.X, hi.Z - lo.Z) * 0.55)
		pl.Brightness = 0.9
		pl.Shadows = false
		pl.Parent = att
	end
end

-- pedana sotto la casa: rettangolo nello spazio del terreno (x0..x1, z0..z1) con i pali fino al
-- terreno; restituisce i punti per nido, banco e arrivo (nello spazio del terreno)
local function buildDeck(plot: Model, c: Vector3, s: Vector3, nestW: number): (Vector3, Vector3, Vector3)
	local old = plot:FindFirstChild("Pedana")
	if old then
		old:Destroy()
	end
	local pivot = plot:GetPivot()
	local x0, x1 = c.X - s.X / 2 - nestW - 10, c.X + s.X / 2 + 16
	local z0, z1 = c.Z - s.Z / 2 - 18, c.Z + s.Z / 2 + 4
	local deck = Instance.new("Model")
	deck.Name = "Pedana"
	local WOOD = Color3.fromRGB(118, 82, 52)
	local function part(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		if shape then
			p.Shape = shape
		end
		p.Anchored = true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = deck
		return p
	end
	local w, d = x1 - x0, z1 - z0
	local center = pivot * CFrame.new((x0 + x1) / 2, -0.55, (z0 + z1) / 2)
	-- sui costoni la mappa ha gia' un piano sotto il terreno: si allarga quello (prima la pedana
	-- nuova ne spuntava fuori da un lato)
	local under = workspace:GetPartBoundsInRadius(pivot.Position - Vector3.new(0, 0.8, 0), 2)
	for _, b in under do
		if b.Parent and b.Parent.Name == "Costone" and b.Size.X > 40 then
			local need = math.max(w, d) + 6
			if b.Size.X < need then
				b.Size = Vector3.new(need, b.Size.Y, need)
				b.CFrame = CFrame.new(center.Position.X, b.Position.Y, center.Position.Z) * b.CFrame.Rotation
			end
			deck.Parent = plot
			local nestAt0 = Vector3.new(c.X - s.X / 2 - nestW / 2 - 5, 0, c.Z + s.Z / 4)
			return nestAt0, Vector3.new(c.X + s.X / 2 + 8, 0, c.Z - s.Z / 4), Vector3.new(c.X, 3, c.Z - s.Z / 2 - 9)
		end
	end
	part(Vector3.new(w, 1, d), center, WOOD, Enum.Material.WoodPlanks).Name = "Piano"
	-- bordo e pali dove il terreno sta sotto la pedana
	local down = RaycastParams.new()
	down.FilterType = Enum.RaycastFilterType.Include
	down.FilterDescendantsInstances = { workspace.Terrain }
	local nx, nz = math.max(2, math.ceil(w / 18)), math.max(2, math.ceil(d / 18))
	for i = 0, nx do
		for j = 0, nz do
			if i == 0 or j == 0 or i == nx or j == nz then
				local p = pivot * Vector3.new(x0 + w * i / nx, -1, z0 + d * j / nz)
				local hit = workspace:Raycast(p, Vector3.new(0, -80, 0), down)
				local len = if hit then hit.Distance + 1 else 0
				if len > 1.5 then
					part(Vector3.new(len, 1.4, 1.4), CFrame.new(p - Vector3.new(0, len / 2 - 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(86, 60, 40), Enum.Material.Wood, Enum.PartType.Cylinder).Name = "Palo"
				end
			end
		end
	end
	deck.Parent = plot
	local nestAt = Vector3.new(c.X - s.X / 2 - nestW / 2 - 5, 0, c.Z + s.Z / 4)
	local forgeAt = Vector3.new(c.X + s.X / 2 + 8, 0, c.Z - s.Z / 4)
	local spawnAt = Vector3.new(c.X, 3, c.Z - s.Z / 2 - 9)
	return nestAt, forgeAt, spawnAt
end

local function buildHouse(player: Player)
	local s = state(player)
	local plot = s.plot
	if not plot then
		return
	end
	local old = plot:FindFirstChild("House")
	if old then
		old:Destroy()
	end
	for _, name in { "Pedana", "Forgia" } do
		local o = plot:FindFirstChild(name)
		if o then
			o:Destroy()
		end
	end
	plot:SetAttribute("DeckSpawn", nil)
	plot:SetAttribute("ForgeAt", nil)
	local house = EconomyConfig.HOUSES[s.house]
	local sign = plotSign(plot)
	if sign then
		local nextHouse = EconomyConfig.HOUSES[s.house + 1]
		sign.Text = player.DisplayName .. (if nextHouse then string.format("\n%s: %d coins", Names.t(nextHouse.name), nextHouse.cost) else "")
	end
	player:SetAttribute("NestPosition", nil)
	if not house then
		return
	end
	local templates = ServerStorage:FindFirstChild("PlotBuildings")
	-- il Mega Chalet non ha un modello vecchio: il nido lo prende da quello dello Chalet
	local template = templates and (templates:FindFirstChild(house.name) or templates:FindFirstChild("Chalet"))
	if not template then
		warn("[Economy] Manca ServerStorage.PlotBuildings." .. house.name .. ": rigenera la mappa")
		return
	end
	local codex = ServerStorage:FindFirstChild("CaseCodex")
	local newHouse = codex and codex:FindFirstChild(CODEX_HOUSE[house.name] or "")
	local model: Model
	if newHouse and newHouse:IsA("Model") then
		-- casa nuova (modello di Codex) + il nido del modello vecchio
		model = Instance.new("Model")
		model.Name = "House"
		local m = newHouse:Clone()
		m:ScaleTo(HOUSE_SCALE)
		m:PivotTo(plot:GetPivot() * CFrame.Angles(0, math.pi, 0))
		m.Parent = model
		houseLights(m, HOUSE_SCALE)
		local oldNest = template:FindFirstChild("Nido")
		if oldNest then
			local n = oldNest:Clone()
			n:PivotTo(plot:GetPivot() * template:GetPivot():ToObjectSpace(oldNest:GetPivot()))
			n.Parent = model
		end
		model.WorldPivot = plot:GetPivot()
	else
		model = template:Clone() :: Model
		model.Name = "House"
		model:PivotTo(plot:GetPivot())
	end
	-- il nido sta di lato alla casa, appoggiato a terra (nei modelli stava dentro i muri)
	local nest = model:FindFirstChild("Nido")
	if nest and nest:IsA("Model") then
		local pivot = plot:GetPivot()
		local bodyCenter, bodySize = Vector3.zero, Vector3.new(16, 10, 16)
		local bestSize = 0
		for _, c in model:GetChildren() do
			if c:IsA("Model") and c ~= nest and c.Name ~= "Campfire" then
				-- ingombro nello spazio del terreno (GetBoundingBox e' girato come il modello: con
				-- la casa nuova girata di 180 gradi le misure venivano storte)
				local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
				for _, p in c:GetDescendants() do
					if p:IsA("BasePart") and p.Transparency < 1 then
						local h = p.Size / 2
						for _, k in { Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, -1, -1) } do
							local q = pivot:PointToObjectSpace(p.CFrame:PointToWorldSpace(h * k))
							lo, hi = lo:Min(q), hi:Max(q)
						end
					end
				end
				local sz = hi - lo
				if lo.X < math.huge and sz.Magnitude > bestSize then
					bestSize = sz.Magnitude
					bodyCenter, bodySize = (lo + hi) / 2, sz
				end
			end
		end
		local _, nestSize = nest:GetBoundingBox()
		-- il terreno che sale sopra il pavimento entrava in casa: via dal pavimento in su, nel
		-- recinto della casa (solo per le case nuove, che hanno il loro pavimento)
		if newHouse then
			local clear = pivot * CFrame.new(bodyCenter.X, bodySize.Y / 2 + 0.2, bodyCenter.Z)
			workspace.Terrain:FillBlock(clear, Vector3.new(bodySize.X + 6, bodySize.Y + 0.4, bodySize.Z + 6), Enum.Material.Air)
		end
		-- la pedana sotto casa, nido e banco: il nido ci sta sopra
		local nestLocal, forgeLocal, spawnLocal = buildDeck(plot, bodyCenter, bodySize, nestSize.X)
		local at = pivot * nestLocal
		local nestCf, nestBox = nest:GetBoundingBox()
		local lift = nest:GetPivot().Position.Y - (nestCf.Position.Y - nestBox.Y / 2)
		nest:PivotTo(CFrame.new(at.X, pivot.Position.Y + lift, at.Z) * pivot.Rotation)
		plot:SetAttribute("ForgeAt", pivot * forgeLocal)
		plot:SetAttribute("DeckSpawn", pivot * spawnLocal)
	end
	for _, d in model:GetDescendants() do
		if CollectionService:HasTag(d, "Incubator") and d:IsA("BasePart") then
			d:SetAttribute("Owner", player.UserId)
			player:SetAttribute("NestPosition", d.Position)
			local prompt = d:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.ObjectText = player.DisplayName .. "'s Nest"
			end
		end
	end
	model.Parent = plot
	-- dove arriva il teletrasporto "My camp" (e il tutorial): davanti alla porta, sulla pedana
	local deckSpawn = plot:GetAttribute("DeckSpawn")
	local spawnAt = if typeof(deckSpawn) == "Vector3" then deckSpawn else plotSpawn(plot)
	player:SetAttribute("PlotSpawn", spawnAt)
	local forge = plot:FindFirstChild("Forgia")
	if s.house >= 3 then
		-- il banco sulla pedana, accanto alla casa (prima finiva fuori sul terreno)
		local forgeAt = plot:GetAttribute("ForgeAt")
		if typeof(forgeAt) == "Vector3" then
			buildForge(plot, forgeAt - plot:GetPivot().RightVector * 13, plot:GetPivot().Position.Y) -- (buildForge aggiunge 9 verso destra)
		else
			buildForge(plot, spawnAt)
		end
	elseif forge then
		forge:Destroy()
	end
end

local function assignPlot(player: Player)
	local s = state(player)
	-- prima un terreno della zona del suo livello (senza casa: il campo tende), se sono tutti
	-- presi uno qualunque
	local want = math.max(1, s.house)
	local free: Model? = nil
	for _, plot in CollectionService:GetTagged("Plot") do
		if plot:IsA("Model") and not plotOwner[plot] then
			if plot:GetAttribute("Level") == want then
				free = plot
				break
			end
			free = free or plot
		end
	end
	do
		local plot = free
		if plot then
			plotOwner[plot] = player
			s.plot = plot
			player:SetAttribute("PlotPosition", plot:GetPivot().Position)
			buildHouse(player)
			refreshRoost(player)
			return
		end
	end
	warn("[Economy] Nessun terreno libero per " .. player.Name)
end
local releasePlot: (Player) -> ()

releasePlot = function(player: Player)
	local s = states[player]
	local plot = s and s.plot
	if plot then
		plotOwner[plot] = nil
		for _, name in { "House", "Roost", "Pedana", "Forgia" } do
			local c = plot:FindFirstChild(name)
			if c then
				c:Destroy()
			end
		end
		local sign = plotSign(plot)
		if sign then
			sign.Text = "Free plot"
		end
	end
end

local function upgradeHouse(player: Player)
	local s = state(player)
	local nextHouse = EconomyConfig.HOUSES[s.house + 1]
	if not nextHouse then
		notice(player, "You already have the best house!")
		return
	end
	if s.coins < nextHouse.cost then
		notice(player, string.format("The %s costs %d coins: you have %d. Sell ores and eggs at the store!", Names.t(nextHouse.name), nextHouse.cost, math.floor(s.coins)))
		return
	end
	s.coins -= nextHouse.cost
	s.house += 1
	publish(player)
	-- la casa nuova sta nella zona del suo livello: si trasloca
	local plot = s.plot
	if s.house > 1 and plot and plot:GetAttribute("Level") ~= s.house then
		releasePlot(player)
		s.plot = nil
		assignPlot(player)
		local zone = s.plot and s.plot:GetAttribute("Zone")
		if zone == "Villaggio" then
			notice(player, "Your Cabin is in the village around the dragon ribs!")
		elseif zone == "Costone" then
			notice(player, "Your Chalet hangs on a cliff of the mountain: enjoy the view!")
		elseif zone == "Cielo" then
			notice(player, "Your Sky Chalet floats above the valley! Use Home (T) or fly there on your dragon")
		end
	else
		buildHouse(player)
	end
	refreshRoost(player)
	Dragons.refresh(player)
	notice(player, string.format("You got a %s! %s", Names.t(nextHouse.name), if s.house == 1 then "The nest is unlocked: you can hatch eggs in it" else "More room for eggs and dragons"))
end

------------------------------------------------------------------------------------------
-- Salvataggio (usato da Progression)

function Economy.serialize(player: Player): any
	local s = states[player]
	return s and { coins = math.floor(s.coins), house = s.house, lastSeen = os.time() }
end

function Economy.load(player: Player, data: any)
	local s = state(player)
	if type(data) == "table" then
		s.coins = data.coins or EconomyConfig.START_COINS
		s.house = data.house or 0
		s.lastSeen = data.lastSeen or os.time()
	end
	publish(player)
	assignPlot(player)
	-- guadagno dei draghi mentre eri via
	if type(data) == "table" and data.lastSeen then
		local minutes = math.min(os.time() - data.lastSeen, EconomyConfig.OFFLINE_HOURS * 3600) / 60
		local earned = math.floor(ratePerMinute(player) * minutes * EconomyConfig.OFFLINE_FACTOR)
		if earned > 0 then
			Economy.addCoins(player, earned)
			notice(player, string.format("While you were away your dragons earned %d coins!", earned))
		end
	end
end

------------------------------------------------------------------------------------------

function Economy.setup()
	-- Cartelli dei terreni: compra/migliora la casa (solo il proprietario)
	local function bindPlot(plot: Instance)
		local post = plot:FindFirstChild("PlotPost", true)
		if not post then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Buy / upgrade house"
		prompt.ObjectText = "Plot"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = post
		prompt.Triggered:Connect(function(player)
			if plotOwner[plot :: Model] ~= player then
				notice(player, "This plot belongs to another player: yours has your name on the sign")
				return
			end
			upgradeHouse(player)
		end)
	end
	for _, plot in CollectionService:GetTagged("Plot") do
		bindPlot(plot)
	end

	-- vendere un drago dal menu Draghi
	Dragons.onSell = function(player: Player, d: any)
		local value = (EconomyConfig.DRAGON_PRICES[d.rarity] or 20) * d.stage * (if d.shiny then UpgradeConfig.SHINY_VALUE else 1)
		Economy.addCoins(player, value)
		return value
	end
	-- quando cambiano i draghi, aggiorna quelli posati in casa
	local pendingRoost: { [Player]: boolean } = {}
	Dragons.onChanged = function(player: Player)
		if pendingRoost[player] then
			return
		end
		pendingRoost[player] = true
		task.delay(1, function()
			pendingRoost[player] = nil
			if player.Parent then
				refreshRoost(player)
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		releasePlot(player)
		states[player] = nil
	end)

	-- guadagno dei draghi posati: ogni 10 secondi (1/6 del valore al minuto)
	task.spawn(function()
		while true do
			task.wait(10)
			for player, s in states do
				local rate = ratePerMinute(player)
				if rate > 0 then
					s.pending += rate / 6
					if s.pending >= 1 then
						local whole = math.floor(s.pending)
						s.pending -= whole
						Economy.addCoins(player, whole)
					end
				end
			end
		end
	end)
end

Economy.upgradeHouse = upgradeHouse

return Economy
