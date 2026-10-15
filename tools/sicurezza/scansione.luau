--!nonstrict
-- Scansione dei backdoor (solo in Studio: il codice degli script si legge solo da plugin/MCP, non
-- dal gioco). La lancia Claude con execute_luau in modalita' Edit, oppure un plugin di Mirko.
-- NON e' codice da incollare nella Command Bar trovato in giro: e' nel repo (AGENTS.md, sicurezza).
-- Cerca negli script del place i segni tipici dei modelli infetti della Toolbox:
--   require(numero)        carica un modulo dal catalogo (il backdoor vero sta li')
--   loadstring / getfenv / setfenv    eseguono testo come codice
--   string.char lunghi / \x.. / \ddd  testo nascosto (offuscamento)
--   "rbxassetid" + require, HttpService:GetAsync/PostAsync verso siti sconosciuti
-- Restituisce un elenco: percorso, motivo, riga. Non cancella niente: decide Mirko (Cestino).
local PATTERNS = {
	{ "require%s*%(%s*%d%d%d%d%d+%s*%)", "require di un ID del catalogo" },
	{ "loadstring", "loadstring (esegue testo come codice)" },
	{ "getfenv", "getfenv" },
	{ "setfenv", "setfenv" },
	{ "string%.char%s*%(%s*%d+%s*,%s*%d+%s*,%s*%d+%s*,%s*%d+", "string.char lungo (testo nascosto)" },
	{ "\\x%x%x\\x%x%x\\x%x%x", "sequenze \\x (offuscamento)" },
	{ "\\%d%d%d\\%d%d%d\\%d%d%d", "sequenze \\ddd (offuscamento)" },
	{ "GetObjects", "GetObjects (carica modelli dal catalogo)" },
	{ "PostAsync", "HttpService:PostAsync" },
	{ "MarketplaceService:PromptPurchase%(%s*game%.Players", "acquisto forzato" },
}
-- i nostri script (Rojo) usano HttpService per JSON: PostAsync/GetAsync non li usiamo
return function(): { string }
	local found = {}
	for _, d in game:GetDescendants() do
		local ok, src = pcall(function()
			return (d :: any).Source
		end)
		if ok and type(src) == "string" and d:IsA("LuaSourceContainer") then
			for _, p in PATTERNS do
				local at = string.find(src, p[1])
				if at then
					local line = select(2, string.gsub(string.sub(src, 1, at), "\n", "")) + 1
					table.insert(found, string.format("%s  [%s]  riga %d", d:GetFullName(), p[2], line))
				end
			end
		end
	end
	return found
end
