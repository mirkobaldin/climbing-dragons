--!strict
-- Guardia: difese del server contro i client modificati (exploit "injector") e i backdoor dei
-- modelli della Toolbox (Mirko 15/10: "sistemi di sicurezza anti injector").
--   * ANTI-FLOOD: ogni RemoteEvent/RemoteFunction in ReplicatedStorage.Remotes conta le chiamate
--     di ogni giocatore (secchio di gettoni). Chi supera di molto il limite (solo un exploit lo
--     fa: il gioco vero manda poche chiamate al secondo) viene espulso; le raffiche normali
--     (lag, tasti tenuti premuti) passano.
--   * REMOTE NUOVI: dopo l'avvio nessuno script del gioco crea RemoteEvent fuori da Remotes. Se
--     ne compare uno (tipico dei backdoor: "un modello gratis che apre una porta") lo si
--     segnala in Output con [Sicurezza] e lo si distrugge.
--   * Guardia.ok(player, chiave, perSecondo): limite per le azioni delicate (acquisti, draghi,
--     crafting). Restituisce false quando il giocatore va troppo veloce: la chiamata si ignora
--     senza risposta (non si danno indizi a chi prova).
-- Non si fida mai del client: i controlli veri (monete, possesso, distanza) restano nei
-- moduli che gestiscono ogni azione.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guardia = {}

-- gettoni per giocatore: si ricaricano a RATE al secondo fino a BURST; sotto -KICK_DEBT espulso
local RATE = 60 -- chiamate al secondo sostenibili su tutti i remote insieme (il gioco ne fa ~10)
local BURST = 240
local KICK_DEBT = 600 -- debito oltre il quale si espelle (minimo ~15 s di flood pieno)

type Bucket = { tokens: number, at: number, warned: boolean }
local buckets: { [Player]: Bucket } = {}
local limits: { [Player]: { [string]: number } } = {}

local function spend(player: Player): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = BURST, at = now, warned = false }
		buckets[player] = b
	end
	b.tokens = math.min(BURST, b.tokens + (now - b.at) * RATE)
	b.at = now
	b.tokens -= 1
	if b.tokens < 0 and not b.warned then
		b.warned = true
		warn(string.format("[Sicurezza] %s manda troppe chiamate ai remote", player.Name))
	end
	if b.tokens < -KICK_DEBT then
		warn(string.format("[Sicurezza] %s espulso: flood dei remote (exploit)", player.Name))
		buckets[player] = nil
		player:Kick("Connection error. Please rejoin.")
		return false
	end
	return b.tokens >= 0
end

-- limite per azione: true se il giocatore puo' farla adesso (al massimo perSecondo volte al secondo)
function Guardia.ok(player: Player, key: string, perSecond: number): boolean
	local list = limits[player]
	if not list then
		list = {}
		limits[player] = list
	end
	local now = os.clock()
	local last = list[key] or 0
	if now - last < 1 / perSecond then
		return false
	end
	list[key] = now
	return true
end

local function watchRemote(r: Instance)
	if r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent") then
		(r :: any).OnServerEvent:Connect(function(player: Player)
			spend(player)
		end)
	end
	-- (le RemoteFunction hanno un solo OnServerInvoke, gia' preso dal modulo che le gestisce:
	-- per quelle si usa Guardia.ok dentro il gestore)
end

function Guardia.setup()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	for _, r in remotes:GetDescendants() do
		watchRemote(r)
	end
	remotes.DescendantAdded:Connect(watchRemote)
	-- remote creati dopo l'avvio fuori dalla cartella Remotes: possibile backdoor
	task.delay(20, function()
		local function suspicious(d: Instance)
			if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent")) and not d:IsDescendantOf(remotes) then
				warn("[Sicurezza] remote sconosciuto creato in gioco, distrutto: " .. d:GetFullName())
				task.defer(function()
					d:Destroy()
				end)
			end
		end
		for _, service in { workspace, ReplicatedStorage, game:GetService("Lighting"), game:GetService("ReplicatedFirst") } do
			service.DescendantAdded:Connect(suspicious)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		limits[player] = nil
	end)
end

return Guardia
