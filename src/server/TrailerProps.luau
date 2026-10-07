--!strict
-- Scena per il trailer e le clip di TikTok (comandi admin "trailer", "clip1", "clip2", "clip3"):
-- il server mette in Workspace.TrailerProps i draghi di scena (sempre inviati al client, anche
-- con lo streaming) e scrive negli attributi della cartella i punti della mappa che il client
-- inquadra. Poi la scena la gira il client (client/Trailer).

local DragonModels = require(script.Parent.DragonModels)

local TrailerProps = {}

local function persistent(model: Model, name: string, parent: Instance)
	model.Name = name
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:PivotTo(CFrame.new(0, -500, 0)) -- nascosti finche' il client non li usa
	model.Parent = parent
end

local takes = 0

-- prepara la scena e restituisce il numero della ripresa (il client aspetta proprio quella)
function TrailerProps.prepare(): string
	local old = workspace:FindFirstChild("TrailerProps")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "TrailerProps"
	-- punti della mappa
	local markers = workspace:FindFirstChild("MapMarkers")
	local summit = markers and markers:FindFirstChild("Summit")
	if summit and summit:IsA("BasePart") then
		folder:SetAttribute("Summit", summit.Position)
	end
	for _, name in { "TrainingCenter", "GasCenter" } do
		folder:SetAttribute(name, workspace:GetAttribute(name))
	end
	-- grotta di ghiaccio: le luci lungo la galleria fanno da binario per la camera
	local glacier = workspace:FindFirstChild("Glacier")
	local ice = glacier and glacier:FindFirstChild("Ghiaccio")
	local lights = ice and ice:FindFirstChild("LuciGrottaGhiaccio")
	if lights then
		local list = lights:GetChildren()
		for k = 1, math.min(#list, 12) do
			local p = list[k]
			if p:IsA("BasePart") then
				folder:SetAttribute("Cave" .. k, p.Position)
			end
		end
		folder:SetAttribute("CaveCount", math.min(#list, 12))
	end
	-- draghi di scena
	persistent(DragonModels.dragon("Eclissi", "Leggendario", 1, 1), "EclissiCucciolo", folder)
	persistent(DragonModels.dragon("Eclissi", "Leggendario", 3, 1), "EclissiAdulto", folder)
	persistent(DragonModels.dragon("Gas", "Epico", 2, 30), "Gas", folder)
	persistent(DragonModels.dragon("Gelo", "Raro", 1, 10), "Gelo", folder)
	-- lo stormo del trailer: tutti gli altri draghi
	-- gli 8 draghi coi modelli (Eclissi adulto guida, gli altri 7 dietro)
	for _, e in { "Roccia", "Gelo", "Cosmico", "Tempesta", "Fulmine", "Ossa", "Gas" } do
		local m = DragonModels.dragon(e, "Epico", 2, 30)
		m:ScaleTo(m:GetScale() * 2.2) -- nello stormo si vedono da lontano
		persistent(m, "Stormo" .. e, folder)
	end
	-- la Grande Grotta (punti scritti dal generatore della mappa)
	folder:SetAttribute("GrandCenter", workspace:GetAttribute("GrandCaveCenter"))
	folder:SetAttribute("GrandOut", workspace:GetAttribute("GrandCaveOut"))
	folder:SetAttribute("GrandFace", workspace:GetAttribute("GrandCaveFace"))
	takes += 1
	local take = tostring(takes)
	folder:SetAttribute("Take", take)
	folder.Parent = workspace
	return take
end

return TrailerProps
