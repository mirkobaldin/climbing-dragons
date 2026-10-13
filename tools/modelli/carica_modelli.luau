-- Caricamento in Studio dei modelli di Codex (tools/modelli/LEGGIMI.md). Si usa come ModuleScript:
--   require(modulo)(nomeModello, primaParte, quante)  -> testo con l'esito
-- Legge i JSON da http://127.0.0.1:8766/json/<Modello>/ (tools/modelli/serve.js), carica ogni
-- parte come asset Mesh e mette il modello in ServerStorage.CaseCodex.<Modello>, in metri (1 stud
-- = 1 metro: la grandezza giusta la da' il gioco con ScaleTo). Le collisioni sono scatole
-- invisibili, le luci stanno nei punti FX_Light/FX_Fire dei marcatori.

local HS = game:GetService("HttpService")
local AS = game:GetService("AssetService")
local SS = game:GetService("ServerStorage")

local BASE = "http://127.0.0.1:8766/json/"

-- materiali senza texture: materiale e colore di Roblox
local PLAIN = {
	MAT_WarmLight = { Enum.Material.Neon, Color3.fromRGB(255, 196, 120), 0 },
	MAT_Ember = { Enum.Material.Neon, Color3.fromRGB(255, 110, 40), 0 },
	MAT_Glass = { Enum.Material.Glass, Color3.fromRGB(170, 205, 230), 0.55 },
	MAT_Green = { Enum.Material.LeafyGrass, Color3.fromRGB(78, 122, 62), 0 },
	MAT_Gold = { Enum.Material.Metal, Color3.fromRGB(214, 176, 70), 0 },
	MAT_StormEnergy = { Enum.Material.Neon, Color3.fromRGB(110, 200, 255), 0 },
	MAT_IceCrystal = { Enum.Material.Glass, Color3.fromRGB(190, 235, 255), 0.2 },
	MAT_DragonWing_Lava = { Enum.Material.Neon, Color3.fromRGB(255, 100, 30), 0 },
}

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
		-- triangoli degeneri (vertici fusi dall'arrotondamento, area nulla): Roblox rifiuta la mesh
		local a, b, c = V[t[i] + 1], V[t[i + 3] + 1], V[t[i + 6] + 1]
		if (b - a):Cross(c - a).Magnitude < 1e-7 then
			continue
		end
		local f = em:AddTriangle(P[t[i] + 1], P[t[i + 3] + 1], P[t[i + 6] + 1])
		em:SetFaceUVs(f, { U[t[i + 1] + 1], U[t[i + 4] + 1], U[t[i + 7] + 1] })
		em:SetFaceNormals(f, { N[t[i + 2] + 1], N[t[i + 5] + 1], N[t[i + 8] + 1] })
	end
	return em
end

return function(modelName: string, first: number?, count: number?): string
	HS.HttpEnabled = true
	local ok, result = pcall(function()
		local ix = get(modelName .. "/index.json")
		local mats = get("matids.json")
		local root = SS:FindFirstChild("CaseCodex") or Instance.new("Folder")
		root.Name = "CaseCodex"
		root.Parent = SS
		local model = root:FindFirstChild(modelName) :: Model?
		if not model then
			local m = Instance.new("Model")
			m.Name = modelName
			m.WorldPivot = CFrame.identity
			m.Parent = root
			model = m
		end
		local mdl = model :: Model
		local visual = mdl:FindFirstChild("Mesh") or Instance.new("Folder")
		visual.Name = "Mesh"
		visual.Parent = mdl
		local done = {}
		local a = first or 1
		local b = math.min(#ix.parts, a + (count or #ix.parts) - 1)
		for i = a, b do
			local part = ix.parts[i]
			if visual:FindFirstChild(part.file) then
				continue
			end
			local d = get(modelName .. "/" .. part.file .. ".json")
			local mn, mx = Vector3.new(part.min[1], part.min[2], part.min[3]), Vector3.new(part.max[1], part.max[2], part.max[3])
			local center = (mn + mx) / 2
			local em = meshFrom(d, center)
			-- Roblox ogni tanto rifiuta (troppi caricamenti di fila): si riprova dopo una pausa
			local res, id
			for try = 1, 5 do
				res, id = AS:CreateAssetAsync(em, Enum.AssetType.Mesh, { Name = string.sub(part.file, 1, 50), Description = "Climbing & Dragons " .. modelName }) -- nomi oltre 50 caratteri: rifiutati
				if res == Enum.CreateAssetResult.Success then
					break
				end
				task.wait(4 * try)
			end
			em:Destroy()
			assert(res == Enum.CreateAssetResult.Success, "upload " .. part.file .. " " .. tostring(res))
			local mp = AS:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. id), { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic })
			mp.Name = part.file
			mp.Anchored = true
			mp.CanCollide = false
			mp.CanTouch = false
			mp.CanQuery = false
			mp.CFrame = CFrame.new(center)
			mp:SetAttribute("MeshAsset", id)
			mp:SetAttribute("Material", part.material)
			if part.bone then
				mp:SetAttribute("Bone", part.bone)
			end
			local tex = part.material and mats[part.material]
			if tex then
				local sa = Instance.new("SurfaceAppearance")
				sa.ColorMap = tex.BaseColor or ""
				sa.NormalMap = tex.Normal or ""
				sa.RoughnessMap = tex.Roughness or ""
				sa.Parent = mp
				mp.Color = Color3.new(1, 1, 1)
			else
				local plain = PLAIN[part.material or ""]
				if plain then
					mp.Material = plain[1]
					mp.Color = plain[2]
					mp.Transparency = plain[3]
				end
				mp.CastShadow = part.material ~= "MAT_Glass"
			end
			mp.Parent = visual
			table.insert(done, part.file)
			task.wait()
		end
		-- collisioni e luci (una volta sola, alla prima chiamata)
		if not mdl:FindFirstChild("Collisione") and #ix.boxes > 0 then
			local col = Instance.new("Folder")
			col.Name = "Collisione"
			for _, bx in ix.boxes do
				local p = Instance.new("Part")
				p.Name = bx.name
				local x, y, z = bx.axes[1], bx.axes[2], bx.axes[3]
				p.Size = Vector3.new(math.max(bx.size[1], 0.05), math.max(bx.size[2], 0.05), math.max(bx.size[3], 0.05))
				p.CFrame = CFrame.fromMatrix(Vector3.new(bx.c[1], bx.c[2], bx.c[3]), Vector3.new(x[1], x[2], x[3]), Vector3.new(y[1], y[2], y[3]), Vector3.new(z[1], z[2], z[3]))
				p.Anchored = true
				p.Transparency = 1
				p.CanCollide = true
				p.CanQuery = true
				p.CanTouch = false
				p.CastShadow = false
				p.Parent = col
			end
			col.Parent = mdl
		end
		if not mdl:FindFirstChild("Luci") and ix.markers then
			local holder = Instance.new("Part")
			holder.Name = "Luci"
			holder.Size = Vector3.one * 0.2
			holder.Transparency = 1
			holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
			holder.CFrame = CFrame.identity
			for _, mk in ix.markers do
				local pos = mk.position_y_up_m
				if pos then
					local att = Instance.new("Attachment")
					att.Name = mk.name
					att.Position = Vector3.new(pos[1], pos[2], pos[3])
					att.Parent = holder
					if string.find(mk.name, "Light") then
						local l = Instance.new("PointLight")
						l.Color = Color3.fromRGB(255, 196, 130)
						l.Brightness = 1.6
						l.Range = 7 -- metri (il gioco lo moltiplica per la scala del modello)
						l.Shadows = false
						l:SetAttribute("RangeM", 7)
						l.Parent = att
					elseif string.find(mk.name, "Fire") then
						local f = Instance.new("Fire")
						f.Size = 2
						f.Heat = 4
						f.Color = Color3.fromRGB(255, 140, 50)
						f.SecondaryColor = Color3.fromRGB(255, 60, 20)
						f.Parent = att
					end
				end
			end
			holder.Parent = mdl
			mdl.PrimaryPart = holder
		end
		for name, bone in ix.bones or {} do
			mdl:SetAttribute("BoneHead_" .. name, Vector3.new(bone.head[1], bone.head[2], bone.head[3]))
			mdl:SetAttribute("BoneTail_" .. name, Vector3.new(bone.tail[1], bone.tail[2], bone.tail[3]))
		end
		return string.format("%s: %d parti caricate (%d-%d di %d), %d in tutto", modelName, #done, a, b, #ix.parts, #visual:GetChildren())
	end)
	HS.HttpEnabled = false
	return if ok then result else "ERRORE " .. tostring(result)
end
