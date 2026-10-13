-- Costruisce le mesh VFX da JSON locale, le carica come asset Mesh e crea i MeshPart in VFXLib.Mesh
local NAMES = { "VFX_41_GeloLanciaAurora" } -- nomi dei JSON da caricare (a gruppi di ~10: ogni caricamento richiede qualche secondo)
local PALETTE = "rbxassetid://109155444409384"
local HS = game:GetService("HttpService")
local AS = game:GetService("AssetService")
local lib = game.ReplicatedStorage.VFXLib.Mesh
local ids = {}
HS.HttpEnabled = true
local out = {}
for _, name in NAMES do
	local ok, err = pcall(function()
		local d = HS:JSONDecode(HS:GetAsync("http://127.0.0.1:8765/" .. name .. ".json"))
		local em = AS:CreateEditableMesh({})
		local P, U, N = {}, {}, {}
		local p, u, n = d.p, d.u, d.n
		for i = 1, #p, 3 do P[#P + 1] = em:AddVertex(Vector3.new(p[i], p[i + 1], p[i + 2])) end
		for i = 1, #u, 2 do U[#U + 1] = em:AddUV(Vector2.new(u[i], u[i + 1])) end
		for i = 1, #n, 3 do N[#N + 1] = em:AddNormal(Vector3.new(n[i], n[i + 1], n[i + 2])) end
		local t = d.t
		for i = 1, #t, 9 do
			local f = em:AddTriangle(P[t[i] + 1], P[t[i + 3] + 1], P[t[i + 6] + 1])
			em:SetFaceUVs(f, { U[t[i + 1] + 1], U[t[i + 4] + 1], U[t[i + 7] + 1] })
			em:SetFaceNormals(f, { N[t[i + 2] + 1], N[t[i + 5] + 1], N[t[i + 8] + 1] })
		end
		local res, id = AS:CreateAssetAsync(em, Enum.AssetType.Mesh, { Name = name, Description = "Climbing & Dragons VFX" })
		assert(res == Enum.CreateAssetResult.Success, "upload " .. tostring(res))
		local mp = AS:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. id), { CollisionFidelity = Enum.CollisionFidelity.Box })
		mp.Name = name
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanTouch = false
		mp.CanQuery = false
		mp.CastShadow = false
		mp.Massless = true
		mp.Color = Color3.new(1, 1, 1)
		mp.Material = Enum.Material.Neon
		if tonumber(string.match(name, "VFX_(%d+)")) >= 37 then
			mp.TextureID = PALETTE
			mp.Material = Enum.Material.SmoothPlastic
		end
		mp:SetAttribute("MeshAsset", id)
		local old = lib:FindFirstChild(name)
		if old then old:Destroy() end
		mp.Parent = lib
		ids[name] = id
		em:Destroy()
	end)
	table.insert(out, name .. " " .. (ok and tostring(ids[name]) or ("ERR " .. tostring(err))))
	task.wait()
end
HS.HttpEnabled = false
return table.concat(out, "\n")
