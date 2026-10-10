--!strict
-- Traiettoria dei draghi volanti nemici (server/Flyers li guida, client/Combat li muove).
-- Il server scrive sul modello solo il "pezzo" di volo in corso (attributi Seg*), ogni client
-- calcola da se' dove sta il drago a ogni frame: la posizione non viaggia in rete e server e
-- client la vedono uguale (serve per i colpi).
--   orbit  giro attorno a Center (raggio Radius, quota assoluta Alt, Speed in radianti al secondo,
--          angolo iniziale A0)
--   curve  curva di Bezier P0 -> P1 -> P2 in SegDur secondi (picchiate, avvicinamenti, decollo)
--   hold   fermo in P0 (in aria o a terra), girato verso Look, con un'oscillazione di Bob studs

local FlyerPath = {}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function bezier(a: Vector3, b: Vector3, c: Vector3, u: number): Vector3
	local v = 1 - u
	return a * (v * v) + b * (2 * v * u) + c * (u * u)
end

-- get(nome) legge un attributo (dal modello o da una tabella); t = secondi del server
function FlyerPath.pose(get: (string) -> any, t: number): CFrame
	local kind = get("SegKind")
	local t0 = (get("SegT0") or t) :: number
	if kind == "orbit" then
		local center = get("Center") :: Vector3
		local r = get("Radius") :: number
		local speed = get("Speed") :: number
		local a = (get("A0") or 0) + speed * (t - t0)
		local p = Vector3.new(center.X + math.cos(a) * r, (get("Alt") :: number) + math.sin(t * 0.9) * 4, center.Z + math.sin(a) * r)
		local dir = math.sign(speed)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * (if dir == 0 then 1 else dir)
		return CFrame.lookAt(p, p + tangent) * CFrame.Angles(0, 0, math.rad(-16 * dir)) -- inclinato nella curva
	elseif kind == "curve" then
		local dur = math.max((get("SegDur") or 1) :: number, 0.05)
		local u = smooth((t - t0) / dur)
		local p0, p1, p2 = get("P0") :: Vector3, get("P1") :: Vector3, get("P2") :: Vector3
		local p = bezier(p0, p1, p2, u)
		local ahead = bezier(p0, p1, p2, math.min(1, u + 0.04)) - p
		if ahead.Magnitude < 0.05 then
			ahead = p2 - p1
		end
		-- non si punta del tutto in giu' o in su: il muso segue la curva ma resta leggibile
		local flat = Vector3.new(ahead.X, 0, ahead.Z)
		local look = if flat.Magnitude > 0.05 then flat.Unit + Vector3.new(0, math.clamp(ahead.Unit.Y, -0.7, 0.7), 0) else ahead.Unit
		return CFrame.lookAt(p, p + look)
	end
	-- hold
	local p0 = (get("P0") or Vector3.zero) :: Vector3
	local bob = (get("Bob") or 0) :: number
	local p = p0 + Vector3.new(0, math.sin(t * 2.2) * bob, 0)
	local lookAt = get("Look")
	if typeof(lookAt) == "Vector3" then
		local d = Vector3.new(lookAt.X - p.X, 0, lookAt.Z - p.Z)
		if d.Magnitude > 0.5 then
			return CFrame.lookAt(p, p + d)
		end
	end
	return CFrame.new(p)
end

function FlyerPath.fromModel(m: Instance, t: number): CFrame
	return FlyerPath.pose(function(name)
		return m:GetAttribute(name)
	end, t)
end

return FlyerPath
