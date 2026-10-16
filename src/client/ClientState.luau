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
	gas = 0, -- quanto sei dentro la valle dei gas (0-1): il meteo infittisce la nebbia
	petLook = nil :: Vector3?, -- dove guarda il tuo drago (vista dal drago nell'arena: dove miri)
	dragonMode = false, -- nell'arena sei il drago (niente suggerimenti dell'arrampicata)
	petSnap = false, -- il drago riparte subito accanto al padrone (uscita dall'arena)
	petAnchor = nil :: Vector3?, -- addestramento: dove vola il tuo drago (dentro l'arena)
	noFallUntil = 0, -- niente danni da caduta fino a (os.clock), es. dopo il Rampino
	riding = false, -- in groppa al drago adulto (client/DragonRide)
	editingControls = false, -- si stanno spostando i tasti del telefono (client/MobileControls)
	controlsCustom = nil :: any, -- tasti spostati (MobileControls), con MenuFrac = posizione del tasto del menu
	grappling = false, -- il Rampino ti sta tirando (il parapendio si chiude)
}

-- punto dello schermo dove si mira col Rampino (mirino e colpo usano lo stesso): il mouse sul
-- computer; sul telefono un po' sopra il centro, perche' al centro c'e' il personaggio
function ClientState.aimPoint(): Vector2
	local UIS = game:GetService("UserInputService")
	local camera = workspace.CurrentCamera
	if UIS.TouchEnabled and UIS:GetLastInputType() == Enum.UserInputType.Touch or not UIS.MouseEnabled then
		local vp = camera.ViewportSize
		return Vector2.new(vp.X / 2, vp.Y * 0.36)
	end
	if UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return camera.ViewportSize / 2
	end
	return UIS:GetMouseLocation()
end

return ClientState
