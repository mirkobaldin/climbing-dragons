--!strict
-- Meteo e ciclo giorno/notte, decisi dal server e uguali per tutti.
-- Lo stato e' negli attributi di workspace ("Weather", "WindStrength", "WindDirection"):
-- i client li leggono per pioggia, neve, grandine, nebbia e vento.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClimbConfig = require(ReplicatedStorage.Shared.ClimbConfig)

local Weather = {}

-- peso = probabilita' relativa; cover = copertura nuvole; wind = forza del vento
local STATES = {
	{ name = "Clear", weight = 4, cover = 0.4, wind = 10 },
	{ name = "Cloudy", weight = 3, cover = 0.75, wind = 25 },
	{ name = "Rain", weight = 2, cover = 0.85, wind = 35 },
	{ name = "Storm", weight = 1, cover = 0.95, wind = 90 }, -- pioggia forte, grandine, raffiche
	{ name = "Snow", weight = 2, cover = 0.85, wind = 40 },
}

local function pick(rng: Random)
	local total = 0
	for _, s in STATES do
		total += s.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, s in STATES do
		roll -= s.weight
		if roll <= 0 then
			return s
		end
	end
	return STATES[1]
end

local rng = Random.new()
local forcedUntil = 0

local function apply(state: { name: string, cover: number, wind: number })
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	local angle = rng:NextNumber(0, 2 * math.pi)
	workspace:SetAttribute("Weather", state.name)
	workspace:SetAttribute("WindStrength", state.wind)
	workspace:SetAttribute("WindDirection", Vector3.new(math.cos(angle), 0, math.sin(angle)))
	if clouds then
		clouds.Cover = state.cover
		clouds.Density = if state.name == "Clear" then 0.5 else 0.8
	end
end

-- Forza un meteo (comandi admin): resta per almeno 5 minuti. Restituisce false se il nome
-- non esiste (Clear, Cloudy, Rain, Storm, Snow)
function Weather.set(name: string): boolean
	for _, s in STATES do
		if string.lower(s.name) == string.lower(name) then
			apply(s)
			forcedUntil = os.clock() + 300
			return true
		end
	end
	return false
end

function Weather.setup()
	task.spawn(function()
		while true do
			if os.clock() >= forcedUntil then
				apply(pick(rng))
			end
			task.wait(rng:NextNumber(ClimbConfig.WEATHER_MIN_SECONDS, ClimbConfig.WEATHER_MAX_SECONDS))
		end
	end)

	-- Giorno e notte: 24 ore di gioco in DAY_LENGTH_MINUTES minuti reali. Le luci ambiente
	-- seguono l'ora: alba e tramonto caldi, notte blu scura (cosi' lanterne, falo' e chalet
	-- illuminati si vedono davvero), mezzogiorno pieno.
	Lighting.ClockTime = ClimbConfig.START_CLOCK_TIME
	local hoursPerSecond = 24 / (ClimbConfig.DAY_LENGTH_MINUTES * 60)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		local t = (Lighting.ClockTime + dt * hoursPerSecond) % 24
		Lighting.ClockTime = t
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		-- day: 0 di notte, 1 di giorno (transizioni di ~1.5 ore attorno a 6:00 e 18:30)
		local day = math.clamp((t - 5.25) / 1.5, 0, 1) * math.clamp((19.25 - t) / 1.5, 0, 1)
		-- golden: massimo all'alba e al tramonto
		local golden = math.max(0, 1 - math.abs(t - 6.6) / 1.3) + math.max(0, 1 - math.abs(t - 18.2) / 1.4)
		golden = math.clamp(golden, 0, 1)
		-- notte al chiaro di luna: blu ma leggibile (si vedono sentieri e pareti)
		local night = Color3.fromRGB(96, 108, 150)
		-- Look cinematografico: poca luce ambiente di giorno (ombre profonde e leggibili, e' il
		-- sole a disegnare la montagna), sole forte, alba e tramonto molto caldi.
		Lighting.Brightness = 1.3 + 1.6 * day + 0.4 * golden
		Lighting.OutdoorAmbient = night:Lerp(Color3.fromRGB(108, 112, 124), day)
		Lighting.Ambient = Color3.fromRGB(56, 62, 88):Lerp(Color3.fromRGB(52, 54, 62), day)
		Lighting.ColorShift_Top = Color3.new(0, 0, 0):Lerp(Color3.fromRGB(255, 140, 60), golden)
		Lighting.ExposureCompensation = 0.25 * (1 - day)
		if atmosphere then
			atmosphere.Color = Color3.fromRGB(70, 80, 110):Lerp(Color3.fromRGB(199, 206, 216), day):Lerp(Color3.fromRGB(240, 170, 120), golden * 0.6)
			atmosphere.Decay = Color3.fromRGB(40, 44, 70):Lerp(Color3.fromRGB(106, 112, 125), day):Lerp(Color3.fromRGB(200, 110, 80), golden * 0.5)
		end
		if grade then
			grade.TintColor = Color3.fromRGB(196, 206, 255):Lerp(Color3.fromRGB(255, 250, 242), day):Lerp(Color3.fromRGB(255, 218, 186), golden * 0.8)
		end
		workspace:SetAttribute("Night", day < 0.3)
	end)
end

return Weather
