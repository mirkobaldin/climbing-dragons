--!strict
-- Minerali sul client:
--   * contorno luminoso (Highlight) e una lucina sui giacimenti vicini, del colore del minerale:
--     nelle grotte buie prima non si vedevano. Solo i piu' vicini (Roblox disegna al massimo 31
--     Highlight insieme), aggiornati due volte al secondo.
--   * quando estrai (evento "MineFX" dal server): suono, "+1 Iron" che sale, scintille, piccola
--     scossa, e il giacimento che sobbalza; quando si esaurisce "Depleted".

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Names = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Names"))
local Sfx = require(script.Parent.Sfx)

local OreFX = {}

local NEAR = 70 -- distanza entro cui i giacimenti si illuminano
local MAX_LIT = 16

local COLORS: { [string]: Color3 } = {
	Carbone = Color3.fromRGB(200, 200, 210),
	Ferro = Color3.fromRGB(230, 230, 240),
	Oro = Color3.fromRGB(255, 200, 40),
	Cristallo = Color3.fromRGB(80, 230, 255),
	Rubino = Color3.fromRGB(255, 60, 70),
	Cosmico = Color3.fromRGB(230, 70, 255),
}
local SOUND: { [string]: string } = { Cristallo = "Vetro", Rubino = "Vetro", Cosmico = "Stelle" }

type Lit = { hl: Highlight, light: PointLight }
local lit: { [Instance]: Lit } = {}

local function posOf(node: Instance): Vector3?
	if node:IsA("Model") then
		return node:GetPivot().Position
	elseif node:IsA("BasePart") then
		return node.Position
	end
	return nil
end

local function firstPart(node: Instance): BasePart?
	return if node:IsA("BasePart") then node else node:FindFirstChildWhichIsA("BasePart", true)
end

local function unlight(node: Instance)
	local l = lit[node]
	if l then
		l.hl:Destroy()
		l.light:Destroy()
		lit[node] = nil
	end
end

local function light(node: Instance)
	local part = firstPart(node)
	if lit[node] or not part then
		return
	end
	local color = COLORS[(node:GetAttribute("OreType") or "") :: string] or Color3.new(1, 1, 1)
	local hl = Instance.new("Highlight")
	hl.FillColor = color
	hl.FillTransparency = 0.82
	hl.OutlineColor = color
	hl.OutlineTransparency = 0.15
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = node
	hl.Parent = node
	local pl = Instance.new("PointLight")
	pl.Color = color
	pl.Range = 9
	pl.Brightness = 0.9
	pl.Shadows = false
	pl.Parent = part
	lit[node] = { hl = hl, light = pl }
end

local function depleted(node: Instance): boolean
	return ((node:GetAttribute("Amount") or 1) :: number) <= 0
end

local function floatText(at: Vector3, text: string, color: Color3)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Position = at + Vector3.new(0, 2, 0)
	p.Parent = workspace
	local bill = Instance.new("BillboardGui")
	bill.Size = UDim2.fromOffset(160, 40)
	bill.Adornee = p
	bill.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Parent = bill
	TweenService:Create(p, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = p.Position + Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(p, 1.2)
end

local function sparks(at: Vector3, color: Color3, count: number)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = at
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Speed = NumberRange.new(10, 22)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -50, 0)
	e.Lifetime = NumberRange.new(0.3, 0.7)
	e.Size = NumberSequence.new(0.6, 0)
	e.Rate = 0
	e.Parent = p
	e:Emit(count)
	-- schegge di roccia
	for _ = 1, math.floor(count / 4) do
		local chip = Instance.new("Part")
		chip.Size = Vector3.one * (0.3 + math.random() * 0.4)
		chip.Color = color
		chip.Material = Enum.Material.Slate
		chip.CanCollide = false
		chip.CanQuery = false
		chip.Position = at
		chip.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(8, 18), math.random(-12, 12))
		chip.Parent = workspace
		Debris:AddItem(chip, 1.2)
	end
	Debris:AddItem(p, 1)
end

local function bump(at: Vector3)
	-- il giacimento colpito sobbalza un attimo
	for node in lit do
		local p = posOf(node)
		if p and (p - at).Magnitude < 1 and node:IsA("Model") then
			local cf = node:GetPivot()
			node:PivotTo(cf * CFrame.new(0, 0, 0.35))
			task.delay(0.08, function()
				if node.Parent then
					node:PivotTo(cf)
				end
			end)
		end
	end
end

local function shake(amount: number)
	local cam = workspace.CurrentCamera
	task.spawn(function()
		for k = 1, 5 do
			local s = amount * (1 - k / 5)
			cam.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.02 * s, (math.random() - 0.5) * 0.02 * s, 0)
			RunService.RenderStepped:Wait()
		end
	end)
end

function OreFX.start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local camera = workspace.CurrentCamera
			local here = camera and camera.CFrame.Position
			if here then
				local near = {}
				for _, node in CollectionService:GetTagged("OreNode") do
					local p = posOf(node)
					if p and not depleted(node) then
						local d = (p - here).Magnitude
						if d < NEAR then
							table.insert(near, { node = node, d = d })
						end
					end
				end
				table.sort(near, function(a, b)
					return a.d < b.d
				end)
				local keep: { [Instance]: boolean } = {}
				for i = 1, math.min(MAX_LIT, #near) do
					keep[near[i].node] = true
					light(near[i].node)
				end
				for node in lit do
					if not keep[node] or not node.Parent then
						unlight(node)
					end
				end
			end
		end
	end)
	task.spawn(function()
		local ev = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MineFX", 60) :: RemoteEvent?
		if not ev then
			return
		end
		(ev :: RemoteEvent).OnClientEvent:Connect(function(oreType: string, at: Vector3, left: number, color: Color3)
			local c = COLORS[oreType] or color
			Sfx.play(SOUND[oreType] or "Roccia", at, 1.2)
			sparks(at, c, if left <= 0 then 40 else 18)
			floatText(at, "+1 " .. Names.t(oreType), c)
			bump(at)
			shake(if left <= 0 then 1.4 else 0.6)
			if left <= 0 then
				task.delay(0.35, floatText, at + Vector3.new(0, 1.5, 0), "Depleted", Color3.fromRGB(200, 200, 200))
				Sfx.play("Esplosione", at, 0.5)
			end
		end)
	end)
end

return OreFX
