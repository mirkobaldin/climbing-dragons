-- Mondo Roblox finto per provare client/DragonProcedural fuori da Roblox (esegui.sh lo mette
-- prima del modulo). Terreno: piano a quota GROUND_Y (cambiabile dal test con setGround).
local GROUND = { y = 0, slope = 0, z0 = 0 } -- piano, poi pendio da z0 verso -z
function setGround(y: number, slope: number?, z0: number?)
	GROUND.y = y
	GROUND.slope = slope or 0
	GROUND.z0 = z0 or 0
end
local function groundY(x: number, z: number): number
	return GROUND.y + GROUND.slope * math.min(0, z - GROUND.z0)
end
warn = function(...) print("[warn]", ...) end
Vector2 = { new = function(x, y) return { X = x, Y = y } end, zero = { X = 0, Y = 0 } }
Enum = { RaycastFilterType = { Exclude = "Exclude" } }
RaycastParams = { new = function() return { FilterType = nil, FilterDescendantsInstances = {} } end }
local heartbeat = {}
local RunServiceMock = { Heartbeat = { Connect = function(_, fn) table.insert(heartbeat, fn) end } }
function stepHeartbeat()
	for _, fn in heartbeat do fn() end
end
local posts = {}
local KfsPlayerMock = { setPost = function(model, fn) posts[model] = fn end }
function runPost(model, dt)
	local fn = posts[model]
	if fn then fn(dt) end
end
local PlayersMock = { GetPlayers = function() return {} end }
local SharedMock = {
	WaitForChild = function(_, name)
		if name == "DragonSkeleton" then return DragonSkeleton end
		if name == "DragonGait" then return DragonGait end
		error("modulo sconosciuto " .. name)
	end,
}
local ReplicatedStorageMock = { WaitForChild = function(_, name) assert(name == "Shared"); return SharedMock end }
game = {
	GetService = function(_, name)
		if name == "Players" then return PlayersMock end
		if name == "ReplicatedStorage" then return ReplicatedStorageMock end
		if name == "RunService" then return RunServiceMock end
		error("servizio " .. name)
	end,
}
workspace = {
	CurrentCamera = { CFrame = CFrame.new(0, 10, 30) },
	Raycast = function(_, origin, dir, _params)
		-- piano (con pendenza lungo z): intersezione col segmento
		local y0 = groundY(origin.X, origin.Z)
		local y1 = groundY(origin.X + dir.X, origin.Z + dir.Z)
		local a, b = origin.Y - y0, origin.Y + dir.Y - y1
		if a >= 0 and b <= 0 and a ~= b then
			local t = a / (a - b)
			local p = origin + dir * t
			local n = if p.Z < GROUND.z0 then Vector3.new(0, 1, -GROUND.slope).Unit else Vector3.new(0, 1, 0)
			return { Position = Vector3.new(p.X, groundY(p.X, p.Z), p.Z), Normal = n }
		end
		return nil
	end,
}
script = { Parent = { KfsPlayer = KfsPlayerMock } }
local require = function(x) return x end
-- costruisce un modello finto dalle ossa di scheletri.txt (rotazioni identita', perno in 0)
function modelloFinto(d)
	local part = { Name = "Corpo", CFrame = CFrame.identity }
	function part:IsA(c) return c == "BasePart" end
	local bones = {}
	for i, o in d.ossa do
		local b = { Name = "Bone_" .. i, Transform = CFrame.identity }
		function b:IsA(c) return c == "Bone" end
		bones[i] = b
	end
	for i, o in d.ossa do
		local b = bones[i]
		if o.parent == 0 then
			b.Parent = part
			b.CFrame = CFrame.new(o.pos)
		else
			b.Parent = bones[o.parent]
			b.CFrame = CFrame.new(o.pos - d.ossa[o.parent].pos)
		end
	end
	local model = { Name = d.nome, Parent = workspace, pivot = CFrame.identity, part = part, bones = bones }
	function model:GetDescendants() local t = { part }; for _, b in bones do table.insert(t, b) end; return t end
	function model:GetPivot() return self.pivot end
	function model:GetScale() return 1 end
	function model:GetAttribute(_) return nil end
	function model:PivotTo(cf) self.pivot = cf; part.CFrame = cf end
	return model
end
-- mondo di un osso con le Transform attuali
function mondoOsso(model, b)
	local chain = {}
	local cur = b
	while cur.IsA and cur:IsA("Bone") do
		table.insert(chain, 1, cur)
		cur = cur.Parent
	end
	local cf = cur.CFrame
	for _, x in chain do cf = cf * x.CFrame * x.Transform end
	return cf
end
