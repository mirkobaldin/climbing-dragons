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

	-- CASA: sempre un segnaposto sopra il tuo accampamento ("Home" e i metri, anche attraverso le
	-- montagne) e, quando e' fuori dallo schermo, una freccia sul bordo che ci punta (come GTA)
	local HOME = Color3.fromRGB(120, 230, 255)
	local homeMark = Instance.new("Part")
	homeMark.Name = "SegnaCasa"
	homeMark.Anchored, homeMark.CanCollide, homeMark.CanQuery, homeMark.CanTouch = true, false, false, false
	homeMark.Transparency = 1
	homeMark.Size = Vector3.one
	homeMark.Parent = folder
	local homeBoard = Instance.new("BillboardGui")
	homeBoard.AlwaysOnTop = true
	homeBoard.LightInfluence = 0
	homeBoard.Size = UDim2.fromOffset(110, 52)
	homeBoard.StudsOffset = Vector3.new(0, 14, 0)
	homeBoard.MaxDistance = 100000
	homeBoard.Enabled = false
	homeBoard.Parent = homeMark
	local homeText = text:Clone()
	homeText.TextColor3 = HOME
	homeText.Size = UDim2.new(1, 0, 0, 34)
	homeText.Parent = homeBoard
	local homePin = pin:Clone()
	homePin.TextColor3 = HOME
	homePin.Position = UDim2.fromOffset(0, 30)
	homePin.Parent = homeBoard
	local edgeGui = Instance.new("ScreenGui")
	edgeGui.Name = "BussolaCasa"
	edgeGui.ResetOnSpawn = false
	edgeGui.IgnoreGuiInset = true
	edgeGui.DisplayOrder = 5
	edgeGui.Parent = player:WaitForChild("PlayerGui")
	local edge = Instance.new("Frame")
	edge.AnchorPoint = Vector2.new(0.5, 0.5)
	edge.Size = UDim2.fromOffset(46, 46)
	edge.BackgroundColor3 = Color3.fromRGB(18, 26, 40)
	edge.BackgroundTransparency = 0.15
	edge.Visible = false
	edge.Parent = edgeGui
	local ec = Instance.new("UICorner")
	ec.CornerRadius = UDim.new(1, 0)
	ec.Parent = edge
	local es = Instance.new("UIStroke")
	es.Color = HOME
	es.Thickness = 2
	es.Parent = edge
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextSize = 26
	arrow.TextColor3 = HOME
	arrow.Text = "^"
	arrow.Parent = edge
	local edgeLabel = Instance.new("TextLabel")
	edgeLabel.AnchorPoint = Vector2.new(0.5, 0)
	edgeLabel.Position = UDim2.new(0.5, 0, 1, 2)
	edgeLabel.Size = UDim2.fromOffset(90, 16)
	edgeLabel.BackgroundTransparency = 1
	edgeLabel.Font = Enum.Font.GothamBold
	edgeLabel.TextSize = 13
	edgeLabel.TextColor3 = HOME
	edgeLabel.TextStrokeTransparency = 0.3
	edgeLabel.Parent = edge
	local function updateHome(root: BasePart?)
		local home = player:GetAttribute("PlotSpawn") or player:GetAttribute("PlotPosition")
		if typeof(home) ~= "Vector3" or not root then
			homeBoard.Enabled = false
			edge.Visible = false
			return
		end
		local dist = (home - root.Position).Magnitude
		homeMark.Position = home
		homeBoard.Enabled = dist > 40
		homeText.Text = string.format("Home\n%d m", math.floor(dist))
		local camera = workspace.CurrentCamera
		local sp, onScreen = camera:WorldToViewportPoint(home + Vector3.new(0, 14, 0))
		local vp = camera.ViewportSize
		local inside = onScreen and sp.X > 0 and sp.X < vp.X and sp.Y > 0 and sp.Y < vp.Y
		edge.Visible = dist > 40 and not inside
		if edge.Visible then
			-- direzione della casa rispetto alla camera, portata sul bordo dello schermo
			local rel = camera.CFrame:PointToObjectSpace(home)
			local dir = Vector2.new(rel.X, -rel.Y)
			if rel.Z > 0 then
				dir = Vector2.new(rel.X, math.abs(rel.Y) + 1) -- dietro di te: freccia in basso
			end
			dir = if dir.Magnitude > 0.001 then dir.Unit else Vector2.new(0, 1)
			local half = vp / 2 - Vector2.new(48, 48)
			local k = math.min(half.X / math.max(math.abs(dir.X), 0.001), half.Y / math.max(math.abs(dir.Y), 0.001))
			local at = vp / 2 + dir * k
			edge.Position = UDim2.fromOffset(at.X, at.Y)
			arrow.Rotation = math.deg(math.atan2(dir.X, -dir.Y)) -- gira solo la freccia
			edgeLabel.Text = string.format("Home %d m", math.floor(dist))
		end
	end

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		updateHome(root)
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
