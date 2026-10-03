--!strict
-- Rumore procedurale e piccole utilita' matematiche usate dal generatore.

local noise = math.noise
local abs = math.abs
local clamp = math.clamp

local Noise = {}

-- Fractal Brownian Motion: somma di ottave di rumore, risultato circa in [-0.5, 0.5]
function Noise.fbm(x: number, z: number, seed: number, octaves: number): number
	local sum, amp, freq, norm = 0, 1, 1, 0
	for _ = 1, octaves do
		sum += noise(x * freq, z * freq, seed) * amp
		norm += amp
		amp *= 0.5
		freq *= 2.03 -- non esattamente 2 per evitare artefatti allineati
	end
	return sum / norm
end

-- Rumore "a creste": 1 sulle creste, verso 0 nelle valli. Risultato in [0, 1]
function Noise.ridged(x: number, z: number, seed: number, octaves: number): number
	local sum, amp, freq, norm = 0, 1, 1, 0
	for _ = 1, octaves do
		local n = 1 - clamp(abs(noise(x * freq, z * freq, seed)) * 2.2, 0, 1)
		sum += n * n * amp
		norm += amp
		amp *= 0.5
		freq *= 2.03
	end
	return sum / norm
end

function Noise.smoothstep(edge0: number, edge1: number, x: number): number
	local t = clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

function Noise.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Ogni strato di rumore usa una "fetta" diversa del rumore 3D, derivata dal seed
function Noise.seeds(seed: number, count: number): { number }
	local rng = Random.new(seed)
	local out = table.create(count)
	for i = 1, count do
		out[i] = rng:NextNumber(-500, 500) + 0.5
	end
	return out
end

return Noise
