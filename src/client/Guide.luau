--!strict
-- Frecce guida: una fila di frecce luminose che parte dai piedi del personaggio e indica
-- dove andare, piu' un segnale sopra la meta col nome ("GuideLabel") e i metri. Il bersaglio e'
-- l'attributo "GuideTarget" (lo mettono il tutorial e le missioni del server);
-- se porti un uovo e non c'e' altro, puntano al nido di casa tua.
-- Le frecce "scorrono" verso il bersaglio e seguono il terreno. Visibili solo a te.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Guide = {}

local COUNT = 8
local SPACING = 4.5
local COLOR = Color3.fromRGB(255, 214, 70)

function Guide.start()
	local folder = Instance.new("Folder")
	folder.Name = "GuideArrows"
	folder.Parent = workspace
	-- ogni freccia e' una "V" di due barrette luminose con la punta verso il bersaglio
	local arrows: { { Part } } = {}
	for _ = 1, COUNT do
		local pair = {}
		for _ = 1, 2 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.4, 0.2, 2.2)
			p.Color = COLOR
			p.Material = Enum.Material.Neon
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Transparency = 1
			p.Parent = folder
			table.insert(pair, p)
		end
		table.insert(arrows, pair)
	end
	local function hide(pair: { Part })
		for _, p in pair do
			p.Transparency = 1
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- segnale sopra la meta, visibile anche attraverso le montagne: nome e distanza
	-- (uova e grotte da lontano non si vedono, le frecce a terra da sole non bastavano)
	local beacon = Instance.new("Part")
	beacon.Name = "GuideMeta"
	beacon.Anchored, beacon.CanCollide, beacon.CanQuery, beacon.CanTouch = true, false, false, false
	beacon.Transparency = 1
	beacon.Size = Vector3.one
	beacon.Parent = folder
	local board = Instance.new("BillboardGui")
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Size = UDim2.fromOffset(170, 64)
	board.StudsOffset = Vector3.new(0, 3, 0)
	board.MaxDistance = 100000
	board.Enabled = false
	board.Parent = beacon
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 0, 40)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 16
	text.TextColor3 = COLOR
	text.TextStrokeTransparency = 0.3
	text.Text = ""
	text.Parent = board
	local pin = Instance.new("TextLabel")
	pin.BackgroundTransparency = 1
	pin.Position = UDim2.fromOffset(0, 36)
	pin.Size = UDim2.new(1, 0, 0, 26)
	pin.Font = Enum.Font.GothamBold
	pin.TextSize = 24
	pin.TextColor3 = COLOR
	pin.TextStrokeTransparency = 0.3
	pin.Text = "v"
	pin.Parent = board

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local target = player:GetAttribute("GuideTarget")
		if typeof(target) ~= "Vector3" and player:GetAttribute("CarryingEgg") then
			target = player:GetAttribute("NestPosition")
		end
		local show = root ~= nil and typeof(target) == "Vector3"
		local offset = if show then (target :: Vector3) - (root :: BasePart).Position else Vector3.zero
		local flat = Vector3.new(offset.X, 0, offset.Z)
		board.Enabled = show and offset.Magnitude > 15
		if board.Enabled then
			beacon.Position = target :: Vector3
			local label = player:GetAttribute("GuideLabel")
			text.Text = string.format("%s\n%d m", if type(label) == "string" then label else "Go here", math.floor(offset.Magnitude))
		end
		if not show or flat.Magnitude < 10 then
			for _, a in arrows do
				hide(a)
			end
			return
		end
		params.FilterDescendantsInstances = { character :: Instance, folder }
		local dir = flat.Unit
		local shift = (os.clock() * 6) % SPACING -- scorrono in avanti
		for k, a in arrows do
			local dist = 3 + (k - 1) * SPACING + shift
			if dist > flat.Magnitude - 4 then
				hide(a)
				continue
			end
			local p = (root :: BasePart).Position + dir * dist
			local hit = workspace:Raycast(p + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), params)
			local ground = if hit then hit.Position.Y + 0.3 else (root :: BasePart).Position.Y - 2.8
			local pos = Vector3.new(p.X, ground, p.Z)
			local tip = CFrame.lookAt(pos, pos + dir)
			local fade = math.clamp(dist / (COUNT * SPACING), 0, 1)
			for side, bar in a do
				bar.CFrame = tip * CFrame.Angles(0, (if side == 1 then 1 else -1) * 0.65, 0) * CFrame.new(0, 0, 1.1)
				bar.Transparency = 0.15 + fade * 0.6
			end
		end
	end)
end

return Guide
