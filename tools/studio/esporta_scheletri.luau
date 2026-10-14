-- Esporta gli scheletri dei draghi in JSON (per lo studio delle animazioni procedurali nella
-- sessione cloud, che non vede il file di Studio). Da incollare nella Command Bar di Studio.
-- Legge: ServerStorage.Draghi, Workspace.RigDraghi e ogni Model "Drago*" diretto figlio di
-- ServerStorage. Per ogni modello: ossa (nome, genitore, posizione e assi nello spazio del perno
-- del modello), mesh (grandezza), attributi utili (Seat, AnimBaseScale) e cosa riconosce
-- MapGen.AnimDraghi.analizza (zampe, ali, collo, coda), se il modulo c'e'.
-- Risultato: cartella ServerStorage.ScheletriDraghi con il JSON diviso in ModuleScript (Parte001...,
-- 150.000 caratteri l'uno: il Source ha un limite di 200.000).
-- Per salvarlo: tasto destro sulla CARTELLA ScheletriDraghi -> "Save to File..." (file .rbxmx) e
-- mettilo nel repo come docs/scheletri_draghi.rbxmx (poi commit e push). Non modifica nessun modello.

local SS = game:GetService("ServerStorage")
local HS = game:GetService("HttpService")

local function r3(x: number): number
	return math.round(x * 1000) / 1000
end

local function v(p: Vector3): { number }
	return { r3(p.X), r3(p.Y), r3(p.Z) }
end

local analizza = nil
do
	local mapgen = SS:FindFirstChild("MapGen")
	local mod = mapgen and mapgen:FindFirstChild("AnimDraghi")
	if mod then
		local ok, m = pcall(require, mod:Clone())
		if ok and type(m) == "table" then
			analizza = m.analizza
		end
	end
end

local function names(list: { Instance }?): { string }
	local out = {}
	for _, b in list or {} do
		table.insert(out, b.Name)
	end
	return out
end

local function esporta(model: Model, origine: string)
	local pivot = model:GetPivot()
	local ossa = {}
	local mesh = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			local cf = pivot:ToObjectSpace(d.WorldCFrame)
			table.insert(ossa, {
				nome = d.Name,
				genitore = d.Parent and d.Parent.Name or "",
				genitoreOsso = d.Parent ~= nil and d.Parent:IsA("Bone"),
				pos = v(cf.Position),
				dx = v(cf.RightVector),
				su = v(cf.UpVector),
				ruolo = d:GetAttribute("Ruolo"),
			})
		elseif d:IsA("MeshPart") then
			table.insert(mesh, { nome = d.Name, grandezza = v(d.Size), pos = v(pivot:PointToObjectSpace(d.Position)) })
		end
	end
	local info: { [string]: any } = {
		nome = model.Name,
		origine = origine,
		ossa = ossa,
		mesh = mesh,
		ingombro = v(model:GetExtentsSize()),
		attributi = {},
	}
	for k, a in model:GetAttributes() do
		info.attributi[k] = if typeof(a) == "Vector3" then v(a) elseif type(a) == "number" or type(a) == "string" or type(a) == "boolean" then a else tostring(a)
	end
	if analizza and #ossa > 0 then
		local ok, sk = pcall(analizza, model)
		if ok and type(sk) == "table" then
			local zampe = {}
			for _, leg in sk.legs or {} do
				table.insert(zampe, { ossa = names(leg.bones), lato = leg.side, davanti = leg.front })
			end
			local ali = {}
			for _, w in sk.wings or {} do
				local dita = {}
				for _, f in w.fingers or {} do
					table.insert(dita, names(f))
				end
				table.insert(ali, { braccio = names(w.arm), dita = dita, lato = w.side, punta = w.tip and w.tip.Name })
			end
			info.analisi = { collo = names(sk.neck), coda = names(sk.tail), zampe = zampe, ali = ali, altezza = sk.height }
		else
			info.analisi = { errore = tostring(sk) }
		end
	end
	return info
end

local risultati = {}
local visti = {}
local function giro(root: Instance?, origine: string)
	if not root then
		return
	end
	for _, m in root:GetChildren() do
		if m:IsA("Model") and not visti[m] then
			visti[m] = true
			table.insert(risultati, esporta(m, origine))
		end
	end
end
giro(SS:FindFirstChild("Draghi"), "ServerStorage.Draghi")
giro(workspace:FindFirstChild("RigDraghi"), "Workspace.RigDraghi")
for _, m in SS:GetChildren() do
	if m:IsA("Model") and string.sub(m.Name, 1, 5) == "Drago" and not visti[m] then
		visti[m] = true
		table.insert(risultati, esporta(m, "ServerStorage"))
	end
end

local json = HS:JSONEncode({ data = os.date("!%Y-%m-%dT%H:%M:%SZ"), modelli = risultati })
-- il Source di uno script tiene al massimo 200.000 caratteri: il JSON va diviso in pezzi
-- (Parte001, Parte002, ...) dentro la cartella; si ricompongono uniti in ordine di nome.
local old = SS:FindFirstChild("ScheletriDraghi")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "ScheletriDraghi"
local PEZZO = 150000
local n = 0
for i = 1, #json, PEZZO do
	n += 1
	local part = Instance.new("ModuleScript")
	part.Name = string.format("Parte%03d", n)
	part.Source = string.sub(json, i, i + PEZZO - 1)
	part.Parent = folder
end
folder.Parent = SS
local nOssa = 0
for _, r in risultati do
	nOssa += #r.ossa
end
print(string.format("[Scheletri] %d modelli, %d ossa, %d caratteri in %d pezzi -> ServerStorage.ScheletriDraghi (tasto destro sulla cartella -> Save to File...)",
	#risultati, nOssa, #json, n))
