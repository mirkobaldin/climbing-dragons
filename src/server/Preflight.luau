--!strict
-- Controllo "pronto per l'uscita": cosa manca prima di pubblicare il gioco. In Studio si stampa
-- nell'Output a ogni Play ("[Uscita] ..."), e il comando admin "uscita" lo mostra nella barra.
-- Controlla solo cose che il gioco vede da solo: ID di gamepass e prodotti, animazioni
-- pubblicate, accesso ai DataStore, script dimenticati in Workspace o dentro i modelli,
-- pezzi da editor visibili in mappa, libreria degli effetti.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ClimbConfig = require(ReplicatedStorage.Shared.ClimbConfig)
local DragonConfig = require(ReplicatedStorage.Shared.DragonConfig)
local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)

local Preflight = {}

-- parti che servono solo nell'editor (animazioni, segnaposto): in partita si vedrebbero
local EDITOR_ONLY = { "ParetePerAnimare", "ManichinoArrampicata" }

local function zeros(t: { [string]: number }): { string }
	local out = {}
	for k, v in t do
		if v == 0 then
			table.insert(out, k)
		end
	end
	table.sort(out)
	return out
end

-- restituisce le righe del rapporto e quante cose mancano
function Preflight.report(): ({ string }, number)
	local lines: { string } = {}
	local missing = 0
	local function bad(text: string)
		missing += 1
		table.insert(lines, "  [ ] " .. text)
	end
	local function good(text: string)
		table.insert(lines, "  [x] " .. text)
	end

	if game.PlaceId == 0 then
		bad("il place non e' pubblicato (File > Publish to Roblox)")
	else
		good("place pubblicato (" .. game.PlaceId .. ")")
	end

	-- salvataggi: in Studio funzionano solo con l'accesso alle API acceso
	local ok, err = pcall(function()
		DataStoreService:GetDataStore("Preflight"):GetAsync("prova")
	end)
	if ok then
		good("DataStore raggiungibile (i progressi si salvano)")
	else
		bad("DataStore non raggiungibile: Game Settings > Security > Enable Studio Access to API Services (" .. tostring(err) .. ")")
	end

	local passes = zeros(DragonConfig.GAMEPASSES :: any)
	if #passes > 0 then
		bad("gamepass senza ID (restano nascosti nel negozio): " .. table.concat(passes, ", ") .. " -> DragonConfig.GAMEPASSES, vedi docs/MONETIZZAZIONE.md")
	else
		good("tutti i gamepass hanno l'ID")
	end
	local products = zeros(ShopConfig.DEV_PRODUCTS :: any)
	if #products > 0 then
		bad("prodotti senza ID: " .. table.concat(products, ", ") .. " -> ShopConfig.DEV_PRODUCTS")
	else
		good("tutti i prodotti hanno l'ID")
	end

	local anims = {}
	for _, k in { "CLIMB_IDLE_ANIM", "CLIMB_UP_ANIM" } do
		if ((ClimbConfig :: any)[k] or "") == "" then
			table.insert(anims, k)
		end
	end
	if #anims > 0 then
		bad("animazioni dell'arrampicata non pubblicate: " .. table.concat(anims, ", ") .. " (in Studio si usano i salvataggi, nel gioco servono gli ID in ClimbConfig)")
	else
		good("animazioni dell'arrampicata pubblicate")
	end

	-- script fuori posto: in Workspace o dentro i modelli dello ServerStorage (alcuni modelli
	-- della Toolbox avevano malware)
	local stray = {}
	for _, d in workspace:GetDescendants() do
		local owner = d:FindFirstAncestorOfClass("Model")
		local inCharacter = owner ~= nil and owner:FindFirstChildOfClass("Humanoid") ~= nil -- Animate, Health
		if d:IsA("BaseScript") and not d:FindFirstAncestorWhichIsA("Tool") and not inCharacter then
			table.insert(stray, d:GetFullName())
		end
	end
	for _, folder in { "Modelli", "Draghi", "Uova", "Nemici", "IceKit", "MineraliKit" } do
		local f = ServerStorage:FindFirstChild(folder)
		for _, d in (if f then f:GetDescendants() else {}) :: { Instance } do
			if d:IsA("BaseScript") and d.Enabled then
				table.insert(stray, d:GetFullName())
			end
		end
	end
	if #stray > 0 then
		bad(#stray .. " script dimenticati (spostali in ServerStorage.Cestino): " .. table.concat(stray, ", ", 1, math.min(#stray, 6)))
	else
		good("nessuno script dimenticato in Workspace o nei modelli")
	end

	local leftovers = {}
	for _, n in EDITOR_ONLY do
		local p = workspace:FindFirstChild(n)
		if p then
			table.insert(leftovers, n)
		end
	end
	for _, c in workspace:GetChildren() do
		local lower = string.lower(c.Name)
		if string.find(lower, "vfx", 1, true) or string.find(lower, "pack", 1, true) then
			table.insert(leftovers, c.Name)
		end
	end
	if #leftovers > 0 then
		bad("pezzi da editor visibili in mappa: " .. table.concat(leftovers, ", ") .. " (spostali in ServerStorage)")
	else
		good("niente pezzi da editor in mappa")
	end

	if ReplicatedStorage:FindFirstChild("VFXLib") then
		good("libreria effetti VFXLib presente")
	else
		bad("manca ReplicatedStorage.VFXLib: i draghi usano solo gli effetti di base")
	end

	if not workspace.StreamingEnabled then
		bad("StreamingEnabled spento: caricamento molto piu' lento")
	end

	table.insert(lines, 1, string.format("PRONTO PER L'USCITA? %d cose da fare", missing))
	return lines, missing
end

function Preflight.setup()
	if not RunService:IsStudio() then
		return
	end
	-- dopo l'avvio: il rapporto non deve rallentare gli altri sistemi
	task.delay(10, function()
		local ok, lines = pcall(Preflight.report)
		if ok then
			print("[Uscita] " .. table.concat(lines :: { string }, "\n"))
		else
			warn("[Uscita] controllo non riuscito: " .. tostring(lines))
		end
	end)
end

return Preflight
