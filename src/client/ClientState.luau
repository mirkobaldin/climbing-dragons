--!strict
-- Stato condiviso tra i moduli del client (arrampicata, HUD, meteo).

local ClientState = {
	climbing = false,
	sprinting = false,
	stamina = 100,
	windFactor = 1, -- il vento fa consumare piu' stamina sulla parete
	hint = "",
	regenBoost = 1, -- moltiplicatore del recupero stamina (1 = normale)
	speedOverride = nil :: number?, -- comando admin "speed"
	eggFinder = nil :: string?, -- testo della bussola delle uova
	fovOffset = 0, -- apertura extra del campo visivo (arrampicata)
	gas = 0,
	petLook = nil :: Vector3?,
	petAnchor = nil :: Vector3?, -- addestramento: dove vola fermo il tuo drago (centro dell'arena) -- dove guarda il tuo drago (vista dal drago nell'arena: dove miri) -- quanto sei dentro la valle dei gas (0-1): il meteo infittisce la nebbia
	noFallUntil = 0, -- niente danni da caduta fino a (os.clock), es. dopo il Rampino
}

return ClientState
