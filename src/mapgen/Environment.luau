--!strict
-- Aspetto realistico del terreno: colori dei materiali meno "plasticosi", acqua turchese
-- trasparente (le lagune si vedono chiare sulla sabbia), nuvole volumetriche.
-- Luci, atmosfera ed effetti sono invece in default.project.json (Lighting).

local Environment = {}

local MATERIAL_COLORS = {
	Grass = Color3.fromRGB(78, 100, 52),
	LeafyGrass = Color3.fromRGB(66, 92, 46),
	Ground = Color3.fromRGB(102, 86, 66),
	Mud = Color3.fromRGB(74, 62, 48),
	Sand = Color3.fromRGB(214, 200, 164),
	Sandstone = Color3.fromRGB(176, 156, 120),
	Rock = Color3.fromRGB(122, 118, 110),
	Slate = Color3.fromRGB(96, 98, 100),
	Basalt = Color3.fromRGB(62, 62, 66),
	Limestone = Color3.fromRGB(150, 140, 122),
	Snow = Color3.fromRGB(236, 241, 246),
	Glacier = Color3.fromRGB(122, 178, 214), -- ghiaccio vivo, azzurro (non deve sembrare neve)
	Cobblestone = Color3.fromRGB(128, 120, 108),
	-- valle dei gas (colori del drago Gas): roccia blu-viola e croste che brillano fucsia
	Asphalt = Color3.fromRGB(34, 26, 72),
	CrackedLava = Color3.fromRGB(240, 80, 220),
	-- grotta di ghiaccio: azzurro intenso
	Ice = Color3.fromRGB(64, 150, 214),
	-- zone a tema: ossa (bianco osso), guglie del fulmine nero e santuario (nero viola), altopiano
	-- cosmico (viola)
	Salt = Color3.fromRGB(226, 218, 198),
	Pavement = Color3.fromRGB(28, 24, 40),
	Concrete = Color3.fromRGB(70, 44, 130),
}

function Environment.apply()
	local terrain = workspace.Terrain
	for name, color in MATERIAL_COLORS do
		terrain:SetMaterialColor((Enum.Material :: any)[name], color)
	end
	-- ciuffi d'erba animati: la proprieta' non e' scrivibile da script in tutte le versioni di
	-- Studio (prima faceva fallire tutto lo stage: acqua e nuvole non venivano mai impostate)
	pcall(function()
		(terrain :: any).Decoration = true
	end)
	-- acqua di montagna: verde-blu scuro e poco riflettente (col cielo riflesso diventava
	-- un celeste piatto da piscina)
	terrain.WaterColor = Color3.fromRGB(18, 84, 92)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.22
	terrain.WaterWaveSize = 0.1
	terrain.WaterWaveSpeed = 8

	-- Funzioni recenti di Roblox (se questo Studio le ha): illuminazione "realistica" e priorita'
	-- alla qualita' delle luci. Le proprieta' restano salvate nel place.
	local Lighting = game:GetService("Lighting")
	pcall(function()
		(Lighting :: any).LightingStyle = (Enum :: any).LightingStyle.Realistic
	end)
	pcall(function()
		(Lighting :: any).PrioritizeLightingQuality = true
	end)

	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Parent = terrain
end

return Environment
