--!strict
-- Abilita' dei draghi al seguito, lato client (le altre sono sul server):
--   Ciliegio  recupero stamina x2 e corsa che stanca meno (letto da Climbing e Sprint)
--   Roccia    evidenzia rocce friabili e giacimenti vicini
--   Cosmico   doppio salto: Spazio a mezz'aria
--   Gelo      presa sul ghiaccio senza Ramponi (letto da Climbing e WeatherFX)
-- Egg Finder (gamepass): scrive nell'HUD dov'e' l'uovo piu' vicino.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local DragonConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragonConfig"))
local Names = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Names"))
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local Abilities = {}

local highlights: { [Instance]: Highlight } = {}

local function updateHighlights()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local active = root ~= nil and DragonConfig.hasAbility(player, "Roccia")
	local keep: { [Instance]: boolean } = {}
	if active then
		local pos = (root :: BasePart).Position
		for _, tag in { "CrumblingRock", "OreNode" } do
			for _, inst in CollectionService:GetTagged(tag) do
				local p = if inst:IsA("BasePart") then inst.Position elseif inst:IsA("Model") then inst:GetPivot().Position else nil
				if p and (p - pos).Magnitude < 90 then
					keep[inst] = true
					if not highlights[inst] then
						local h = Instance.new("Highlight")
						h.FillTransparency = 0.7
						h.FillColor = if tag == "OreNode" then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(255, 90, 60)
						h.OutlineColor = h.FillColor
						h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						h.Adornee = inst
						h.Parent = inst
						highlights[inst] = h
					end
				end
			end
		end
	end
	for inst, h in highlights do
		if not keep[inst] then
			h:Destroy()
			highlights[inst] = nil
		end
	end
end

-- Uovo piu' vicino (bussola del gamepass Egg Finder)
local function eggFinder()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local index = workspace:FindFirstChild("EggIndex")
	-- bussola: gamepass Egg Finder, oppure il drago Ossa al seguito
	if not root or not index or not (player:GetAttribute("Pass_EggFinder") or DragonConfig.hasAbility(player, "Ossa")) then
		ClientState.eggFinder = nil
		return
	end
	local best, bestDist, bestEl = nil, math.huge, ""
	for _, v in index:GetChildren() do
		if v:IsA("Vector3Value") then
			local d = (v.Value - (root :: BasePart).Position).Magnitude
			if d < bestDist then
				best, bestDist, bestEl = v.Value, d, v:GetAttribute("Element") or ""
			end
		end
	end
	if not best then
		ClientState.eggFinder = "No eggs nearby"
		return
	end
	local camera = workspace.CurrentCamera
	local offset = (best :: Vector3) - (root :: BasePart).Position
	local rel = camera.CFrame:VectorToObjectSpace(Vector3.new(offset.X, 0, offset.Z))
	local angle = math.deg(math.atan2(rel.X, -rel.Z))
	local arrows = { "↑", "↗", "→", "↘", "↓", "↙", "←", "↖" }
	local arrow = arrows[(math.floor((angle + 22.5) / 45) % 8) + 1]
	local vertical = if offset.Y > 30 then " (above)" elseif offset.Y < -30 then " (below)" else ""
	ClientState.eggFinder = string.format("%s %s egg %d m away%s", arrow, Names.t(bestEl), math.floor(bestDist), vertical)
end

-- Drago Eclissi: di notte e nelle grotte (roccia sopra la testa) una luce attorno al giocatore
local function eclipseSight()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local r = root :: BasePart
	local light = r:FindFirstChild("VistaEclissi") :: PointLight?
	local want = false
	if DragonConfig.hasAbility(player, "Eclissi") then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		local covered = workspace:Raycast(r.Position, Vector3.new(0, 80, 0), params) ~= nil
		want = covered or workspace:GetAttribute("Night") == true
	end
	if want and not light then
		local l = Instance.new("PointLight")
		l.Name = "VistaEclissi"
		l.Range = 48
		l.Brightness = 1.6
		l.Color = Color3.fromRGB(255, 214, 170)
		l.Shadows = false
		l.Parent = r
	elseif not want and light then
		light:Destroy()
	end
end

function Abilities.start()
	task.spawn(function()
		while true do
			pcall(eclipseSight)
			task.wait(0.5)
		end
	end)
	-- Doppio salto del Drago Cosmico
	local usedDouble = false
	UserInputService.JumpRequest:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root or ClientState.climbing then
			return
		end
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			usedDouble = false
			return
		end
		if not usedDouble and DragonConfig.hasAbility(player, "Cosmico") then
			usedDouble = true
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, 55, v.Z)
		end
	end)

	task.spawn(function()
		while true do
			pcall(updateHighlights)
			pcall(eggFinder)
			task.wait(0.5)
		end
	end)
end

return Abilities
