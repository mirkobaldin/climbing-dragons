--!strict
-- Barra degli attrezzi 1-5: quale attrezzo sta in quale casella. La usano la barra dell'HUD
-- (client/HUD) e lo zaino (client/MainMenu, dove si assegnano, spostano e tolgono).
-- L'ordine e' l'attributo HotbarOrder (JSON, salvato da server/Progression): le prime 5 voci
-- sono le caselle (nome del Tool o "" = vuota), le voci dopo sono attrezzi gia' visti e tolti
-- dalla barra apposta. Un attrezzo nuovo (mai visto) va da solo nella prima casella libera;
-- uno tolto resta nello zaino e non torna nella barra finche' il giocatore non ce lo rimette.
-- Nella barra vanno solo i Tool veri (quelli che si tengono in mano): minerali, materiali,
-- uova e attrezzatura passiva (ramponi, tuta...) no.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClimbConfig = require(script.Parent.ClimbConfig)

local Hotbar = {}
Hotbar.SLOTS = 5
-- ordine di partenza (come prima che si potesse scegliere)
Hotbar.DEFAULT = { ClimbConfig.TOOL_NAME, ClimbConfig.PICKAXE_NAME, ClimbConfig.GRAPPLE_NAME, ClimbConfig.TORCH_NAME }
-- ricette di Gear che danno un Tool: cosi' lo zaino non mostra due volte lo stesso attrezzo
Hotbar.RECIPE_TOOL = { Rampino = ClimbConfig.GRAPPLE_NAME, Torcia = ClimbConfig.TORCH_NAME } :: { [string]: string }

-- i Tool che il giocatore ha adesso (nello zaino di Roblox o in mano)
function Hotbar.owned(player: Player): { Tool }
	local out: { Tool } = {}
	for _, parent in { player:FindFirstChildOfClass("Backpack"), player.Character } :: { Instance? } do
		if parent then
			for _, t in (parent :: Instance):GetChildren() do
				if t:IsA("Tool") then
					table.insert(out, t)
				end
			end
		end
	end
	table.sort(out, function(a, b)
		local x, y = table.find(Hotbar.DEFAULT, a.Name) or 99, table.find(Hotbar.DEFAULT, b.Name) or 99
		return if x == y then a.Name < b.Name else x < y
	end)
	return out
end

-- (caselle salvate, attrezzi conosciuti) dall'attributo; nil se il giocatore non ha mai scelto
function Hotbar.saved(player: Player): ({ string }?, { [string]: boolean })
	local raw = player:GetAttribute("HotbarOrder")
	local known: { [string]: boolean } = {}
	if type(raw) ~= "string" then
		return nil, known
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(list) ~= "table" then
		return nil, known
	end
	local slots = {}
	for i = 1, Hotbar.SLOTS do
		slots[i] = if type(list[i]) == "string" then list[i] else ""
	end
	for _, v in list do
		if type(v) == "string" and v ~= "" then
			known[v] = true
		end
	end
	return slots, known
end

-- casella -> Tool (nil = vuota), secondo la scelta del giocatore e gli attrezzi che ha
function Hotbar.layout(player: Player): { [number]: Tool }
	local tools = Hotbar.owned(player)
	local byName: { [string]: Tool } = {}
	for _, t in tools do
		byName[t.Name] = byName[t.Name] or t
	end
	local slots, known = Hotbar.saved(player)
	local out: { [number]: Tool } = {}
	local used: { [Tool]: boolean } = {}
	if slots then
		for i = 1, Hotbar.SLOTS do
			local t = byName[slots[i]]
			if t and not used[t] then
				out[i] = t
				used[t] = true
			end
		end
	end
	-- attrezzi mai visti: nella prima casella libera
	for _, t in tools do
		if not used[t] and not known[t.Name] then
			for i = 1, Hotbar.SLOTS do
				-- (una casella col nome di un attrezzo che ora non hai resta sua)
				if not out[i] and not (slots and slots[i] ~= "") then
					out[i] = t
					used[t] = true
					break
				end
			end
		end
	end
	return out
end

-- salva la scelta: slots = 5 nomi ("" = vuota). Gli attrezzi posseduti fuori dalla barra
-- restano "conosciuti" (non rientrano da soli)
function Hotbar.save(player: Player, slots: { string })
	local list: { string } = {}
	local seen: { [string]: boolean } = {}
	for i = 1, Hotbar.SLOTS do
		local v = slots[i] or ""
		table.insert(list, v)
		if v ~= "" then
			seen[v] = true
		end
	end
	local _, known = Hotbar.saved(player)
	for _, t in Hotbar.owned(player) do
		known[t.Name] = true
	end
	for name in known do
		if not seen[name] and #list < 16 then
			table.insert(list, name)
		end
	end
	local json = HttpService:JSONEncode(list)
	player:SetAttribute("HotbarOrder", json) -- subito sul client, poi il server lo salva
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("SaveHotbar")
	if remote and remote:IsA("RemoteEvent") and Players.LocalPlayer then
		remote:FireServer(json)
	end
end

-- nomi nelle 5 caselle adesso (per partire da li' quando il giocatore cambia qualcosa)
function Hotbar.current(player: Player): { string }
	local layout = Hotbar.layout(player)
	local out = {}
	for i = 1, Hotbar.SLOTS do
		out[i] = if layout[i] then layout[i].Name else ""
	end
	return out
end

return Hotbar
