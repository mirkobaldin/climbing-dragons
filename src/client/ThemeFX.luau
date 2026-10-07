--!strict
-- Atmosfera delle zone a tema (mapgen/ThemeZones): quando ci entri il colore dell'aria prende
-- quello del drago, compare il nome della zona e nelle zone della tempesta e del fulmine nero
-- ogni tanto lampeggia un fulmine. Tutto locale.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ThemeFX = {}

local TINT: { [string]: Color3 } = {
	Roccia = Color3.fromRGB(255, 236, 205),
	Ossa = Color3.fromRGB(225, 255, 232),
	Tempesta = Color3.fromRGB(200, 215, 255),
	Fulmine = Color3.fromRGB(215, 200, 255),
	Cosmico = Color3.fromRGB(235, 205, 255),
	Eclissi = Color3.fromRGB(255, 220, 190),
}
local NAMES: { [string]: string } = {
	Roccia = "ROCKFALL CANYON",
	Ossa = "DRAGON GRAVEYARD",
	Tempesta = "STORM RIDGE",
	Fulmine = "BLACK LIGHTNING SPIRES",
	Cosmico = "STARFALL PLATEAU",
	Eclissi = "ECLIPSE SANCTUARY",
}
local STORMY = { Tempesta = true, Fulmine = true }

function ThemeFX.start()
	local player = Players.LocalPlayer
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ZonaATema"
	cc.Parent = Lighting
	local gui = Instance.new("ScreenGui")
	gui.Name = "NomeZona"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.16)
	title.Size = UDim2.fromScale(0.5, 0.07)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.3
	title.TextTransparency = 1
	title.Parent = gui

	local current: string? = nil
	local nextBolt = 0
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < 0.3 then
			return
		end
		accum = 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inside: string? = nil
		local insideTitle: string? = nil
		if root then
			for i = 1, (workspace:GetAttribute("ThemeZoneCount") or 0) :: number do
				local c = workspace:GetAttribute("ThemeZone" .. i .. "Center")
				local r = workspace:GetAttribute("ThemeZone" .. i .. "Radius")
				local e = workspace:GetAttribute("ThemeZone" .. i .. "Element")
				if typeof(c) == "Vector3" and type(r) == "number" and type(e) == "string" and ((root :: BasePart).Position - c).Magnitude < r * 1.1 then
					inside = e
					local tt = workspace:GetAttribute("ThemeZone" .. i .. "Title")
					insideTitle = if type(tt) == "string" then tt else nil
				end
			end
		end
		if inside ~= current then
			current = inside
			TweenService:Create(cc, TweenInfo.new(1.5), { TintColor = if inside then TINT[inside] or Color3.new(1, 1, 1) else Color3.new(1, 1, 1) }):Play()
			if inside then
				title.Text = insideTitle or NAMES[inside] or inside
				title.TextTransparency = 0
				task.delay(3, function()
					TweenService:Create(title, TweenInfo.new(1), { TextTransparency = 1 }):Play()
				end)
			end
		end
		-- fulmine: lampo bianco-azzurro (o viola) di un attimo
		if current and STORMY[current] and os.clock() > nextBolt then
			nextBolt = os.clock() + math.random(6, 14)
			local before = cc.Brightness
			cc.Brightness = 0.45
			cc.TintColor = if current == "Fulmine" then Color3.fromRGB(200, 170, 255) else Color3.fromRGB(210, 230, 255)
			task.delay(0.08, function()
				cc.Brightness = 0.15
				task.delay(0.07, function()
					TweenService:Create(cc, TweenInfo.new(0.4), { Brightness = before, TintColor = TINT[current or ""] or Color3.new(1, 1, 1) }):Play()
				end)
			end)
		end
	end)
end

return ThemeFX
