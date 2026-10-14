-- CFrame e Vector2 minimi (solo per i test fuori da Roblox, vedi esegui.sh). Usa il Vector3
-- finto (globale). Matrice di rotazione 3x3 per righe + posizione.
local C = {}
local function mk(x, y, z, m)
	return setmetatable({ p = Vector3.new(x, y, z), m = m }, C)
end
local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mulM(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end
local function mulV(m, v)
	return Vector3.new(m[1] * v.X + m[2] * v.Y + m[3] * v.Z, m[4] * v.X + m[5] * v.Y + m[6] * v.Z, m[7] * v.X + m[8] * v.Y + m[9] * v.Z)
end
local function tr(m)
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end
C.__index = function(cf, k)
	if k == "Position" then return cf.p
	elseif k == "Rotation" then return setmetatable({ p = Vector3.zero, m = cf.m }, C)
	elseif k == "LookVector" then return -Vector3.new(cf.m[3], cf.m[6], cf.m[9])
	elseif k == "RightVector" then return Vector3.new(cf.m[1], cf.m[4], cf.m[7])
	elseif k == "UpVector" then return Vector3.new(cf.m[2], cf.m[5], cf.m[8])
	elseif k == "X" then return cf.p.X elseif k == "Y" then return cf.p.Y elseif k == "Z" then return cf.p.Z
	end
	return C[k]
end
C.__mul = function(a, b)
	if getmetatable(b) == C then
		return setmetatable({ p = a.p + mulV(a.m, b.p), m = mulM(a.m, b.m) }, C)
	end
	return a.p + mulV(a.m, b)
end
C.__add = function(a, v) return setmetatable({ p = a.p + v, m = a.m }, C) end
C.__eq = function(a, b)
	if a.p.X ~= b.p.X or a.p.Y ~= b.p.Y or a.p.Z ~= b.p.Z then return false end
	for i = 1, 9 do if a.m[i] ~= b.m[i] then return false end end
	return true
end
function C.Inverse(cf)
	local t = tr(cf.m)
	return setmetatable({ p = -mulV(t, cf.p), m = t }, C)
end
function C.ToObjectSpace(a, b) return a:Inverse() * b end
function C.PointToObjectSpace(a, v) return mulV(tr(a.m), v - a.p) end
function C.PointToWorldSpace(a, v) return a * v end
function C.VectorToWorldSpace(a, v) return mulV(a.m, v) end
function C.VectorToObjectSpace(a, v) return mulV(tr(a.m), v) end
local function quat(m)
	local t = m[1] + m[5] + m[9]
	local w, x, y, z
	if t > 0 then
		local s = math.sqrt(t + 1) * 2
		w, x, y, z = 0.25 * s, (m[8] - m[6]) / s, (m[3] - m[7]) / s, (m[4] - m[2]) / s
	elseif m[1] > m[5] and m[1] > m[9] then
		local s = math.sqrt(1 + m[1] - m[5] - m[9]) * 2
		w, x, y, z = (m[8] - m[6]) / s, 0.25 * s, (m[2] + m[4]) / s, (m[3] + m[7]) / s
	elseif m[5] > m[9] then
		local s = math.sqrt(1 + m[5] - m[1] - m[9]) * 2
		w, x, y, z = (m[3] - m[7]) / s, (m[2] + m[4]) / s, 0.25 * s, (m[6] + m[8]) / s
	else
		local s = math.sqrt(1 + m[9] - m[1] - m[5]) * 2
		w, x, y, z = (m[4] - m[2]) / s, (m[3] + m[7]) / s, (m[6] + m[8]) / s, 0.25 * s
	end
	return w, x, y, z
end
local function fromQ(w, x, y, z)
	local n = math.sqrt(w * w + x * x + y * y + z * z)
	w, x, y, z = w / n, x / n, y / n, z / n
	return {
		1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
		2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
		2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y),
	}
end
function C.Lerp(a, b, t)
	local w1, x1, y1, z1 = quat(a.m)
	local w2, x2, y2, z2 = quat(b.m)
	if w1 * w2 + x1 * x2 + y1 * y2 + z1 * z2 < 0 then w2, x2, y2, z2 = -w2, -x2, -y2, -z2 end
	local m = fromQ(w1 + (w2 - w1) * t, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, z1 + (z2 - z1) * t)
	return setmetatable({ p = a.p:Lerp(b.p, t), m = m }, C)
end
local CFrame = {}
function CFrame.new(x, y, z)
	if type(x) == "table" then return mk(x.X, x.Y, x.Z, I) end
	return mk(x or 0, y or 0, z or 0, I)
end
CFrame.identity = CFrame.new()
function CFrame.fromAxisAngle(axis, a)
	local u = axis.Unit
	local c, s, t = math.cos(a), math.sin(a), 1 - math.cos(a)
	local x, y, z = u.X, u.Y, u.Z
	return mk(0, 0, 0, {
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c,
	})
end
function CFrame.fromMatrix(p, vx, vy, vz)
	vz = vz or vx:Cross(vy).Unit
	return mk(p.X, p.Y, p.Z, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
end
function CFrame.Angles(rx, ry, rz)
	return CFrame.fromAxisAngle(Vector3.new(1, 0, 0), rx) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), ry) * CFrame.fromAxisAngle(Vector3.new(0, 0, 1), rz)
end
return CFrame
