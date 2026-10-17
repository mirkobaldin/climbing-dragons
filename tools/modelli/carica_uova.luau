-- Carica in Studio un uovo 3D di Codex (v6) dai JSON di tools/modelli/esporta_uova.py: ogni parte
-- diventa un asset Mesh, le texture PBR (gia' caricate, ID in <json>/texids.json) vanno in una
-- SurfaceAppearance, la guida dell'emissione accende vene e crepe col colore dell'elemento. Il
-- modello va in ServerStorage.Uova.Uovo_<Elemento> (lo trova DragonModels, come i vecchi); il
-- vecchio va in ServerStorage.Cestino.UovaVecchie.
-- Uso (Edit, json serviti da tools/modelli/serve.js su /json/): require(modulo)("Roccia")
local HS = game:GetService("HttpService")
local AS = game:GetService("AssetService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")

local BASE = "http://127.0.0.1:8766/json/"

local function get(path: string): any
	return HS:JSONDecode(HS:GetAsync(BASE .. path))
end

local function meshFrom(d: any, center: Vector3): EditableMesh
	local em = AS:CreateEditableMesh({})
	local P, U, N, V = {}, {}, {}, {}
	local p, u, n = d.p, d.u, d.n
	for i = 1, #p, 3 do
		local v = Vector3.new(p[i], p[i + 1], p[i + 2]) - center
		V[#V + 1] = v
		P[#P + 1] = em:AddVertex(v)
	end
	for i = 1, #u, 2 do
		U[#U + 1] = em:AddUV(Vector2.new(u[i], u[i + 1]))
	end
	for i = 1, #n, 3 do
		N[#N + 1] = em:AddNormal(Vector3.new(n[i], n[i + 1], n[i + 2]))
	end
	local t = d.t
	for i = 1, #t, 9 do
		local a, b, c = V[t[i] + 1], V[t[i + 3] + 1], V[t[i + 6] + 1]
		if (b - a):Cross(c - a).Magnitude < 1e-9 then
			continue -- triangoli degeneri: Roblox rifiuta la mesh
		end
		local f = em:AddTriangle(P[t[i] + 1], P[t[i + 3] + 1], P[t[i + 6] + 1])
		em:SetFaceUVs(f, { U[t[i + 1] + 1], U[t[i + 4] + 1], U[t[i + 7] + 1] })
		em:SetFaceNormals(f, { N[t[i + 2] + 1], N[t[i + 5] + 1], N[t[i + 8] + 1] })
	end
	return em
end

return function(element: string): string
	HS.HttpEnabled = true
	local ok, result = pcall(function()
		local name = "Uovo_" .. element
		local ix = get(name .. "/index.json")
		local tex = get("texids.json")[element]
		local DragonConfig = require(RS.Shared.DragonConfig)
		local el = DragonConfig.element(element)
		local glow = if el then el.glow else Color3.new(1, 1, 1)
		local model = Instance.new("Model")
		model.Name = name
		model:SetAttribute("UovoV6", true)
		local shell: MeshPart? = nil
		for _, part in ix.parts do
			local d = get(name .. "/" .. part.file .. ".json")
			local mn, mx = Vector3.new(part.min[1], part.min[2], part.min[3]), Vector3.new(part.max[1], part.max[2], part.max[3])
			local center = (mn + mx) / 2
			local em = meshFrom(d, center)
			local res, id
			for try = 1, 5 do
				res, id = AS:CreateAssetAsync(em, Enum.AssetType.Mesh, { Name = string.sub(part.file, 1, 50), Description = "Climbing & Dragons uovo " .. element })
				if res == Enum.CreateAssetResult.Success then
					break
				end
				task.wait(4 * try)
			end
			em:Destroy()
			assert(res == Enum.CreateAssetResult.Success, "upload " .. part.file .. " " .. tostring(res))
			local mp = AS:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. id), { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Precise })
			mp.Name = part.file
			mp.Anchored = true
			mp.CanCollide = false
			mp.CanTouch = false
			mp.CFrame = CFrame.new(center)
			mp:SetAttribute("MeshAsset", id)
			local isLight = string.find(part.file, "_Luce$") ~= nil
			if isLight then
				-- la luce dentro il guscio (si vede fra le scaglie): neon del colore dell'elemento
				mp.Material = Enum.Material.Neon
				mp.Color = glow
				mp.CastShadow = false
				mp.CanQuery = false
			else
				local maps = tex and tex[part.set]
				if maps then
					local sa = Instance.new("SurfaceAppearance")
					sa.ColorMap = "rbxassetid://" .. maps.color
					sa.NormalMap = "rbxassetid://" .. maps.normal
					sa.RoughnessMap = "rbxassetid://" .. maps.roughness
					sa.MetalnessMap = "rbxassetid://" .. maps.metalness
					pcall(function()
						(sa :: any).EmissiveMaskContent = Content.fromUri("rbxassetid://" .. maps.emission)
						;(sa :: any).EmissiveTint = glow
						;(sa :: any).EmissiveStrength = if part.set == "wings" then 2.5 else 1.5
					end)
					sa.Parent = mp
				end
				mp.Color = Color3.new(1, 1, 1)
			end
			if part.file == name then
				shell = mp
			end
			mp.Parent = model
			task.wait()
		end
		if shell then
			model.PrimaryPart = shell
			shell.CanQuery = true
		end
		local uova = SS:FindFirstChild("Uova") or Instance.new("Folder")
		uova.Name = "Uova"
		uova.Parent = SS
		local old = uova:FindFirstChild(name)
		if old then
			local bin = SS:FindFirstChild("Cestino") or Instance.new("Folder")
			bin.Name = "Cestino"
			bin.Parent = SS
			local vecchie = bin:FindFirstChild("UovaVecchie") or Instance.new("Folder")
			vecchie.Name = "UovaVecchie"
			vecchie.Parent = bin
			if old:GetAttribute("UovoV6") then
				old:Destroy()
			else
				old.Parent = vecchie
			end
		end
		model.Parent = uova
		local _, size = model:GetBoundingBox()
		return string.format("%s: %d parti, ingombro %s", name, #model:GetChildren(), tostring(size))
	end)
	HS.HttpEnabled = false
	return if ok then result else "ERRORE " .. tostring(result)
end
