--!strict
-- Luce di casa: al chiuso (un tetto sopra la testa e pareti attorno) una luce calda e morbida
-- attorno al personaggio, solo per te. Le case dei borghi e quelle vecchie dentro erano nere;
-- cosi' si vede in tutte senza mettere centinaia di luci nella mappa. Le grotte (tetto di
-- terreno) restano buie: li' servono la torcia e le luci azzurre.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local IndoorLight = {}

local player = Players.LocalPlayer
local DIRS = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }

function IndoorLight.start()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local light: PointLight? = nil
	local inside = false
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.3 then
			return
		end
		acc = 0
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if not head then
			return
		end
		local skip: { Instance } = { character :: Instance }
		local pets = workspace:FindFirstChild("Pets")
		if pets then
			table.insert(skip, pets)
		end
		params.FilterDescendantsInstances = skip
		local now = false
		local up = workspace:Raycast(head.Position, Vector3.new(0, 30, 0), params)
		if up and up.Instance ~= workspace.Terrain then
			local walls = 0
			for _, d in DIRS do
				local hit = workspace:Raycast(head.Position, d * 26, params)
				if hit and hit.Instance ~= workspace.Terrain then
					walls += 1
				end
			end
			now = walls >= 2
		end
		if now ~= inside then
			inside = now
			if not light or not light.Parent then
				local l = Instance.new("PointLight")
				l.Name = "LuceDiCasa"
				l.Color = Color3.fromRGB(255, 205, 150)
				l.Range = 24
				l.Brightness = 0
				l.Shadows = false
				l.Parent = head
				light = l
			end
			TweenService:Create(light :: PointLight, TweenInfo.new(0.6), { Brightness = if inside then 1.3 else 0 }):Play()
		end
	end)
end

return IndoorLight
