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
		-- con un menu aperto la freccia finiva sopra la finestra
		local menu = player.PlayerGui:FindFirstChild("MainMenu")
		local menuOpen = menu ~= nil and menu:GetAttribute("MenuOpen") == true
		-- un solo indicatore principale: con un obiettivo (freccia e segnale della missione) la
		-- freccia "Home" a bordo schermo si toglie (Mirko 16/10)
		local hasGoal = typeof(player:GetAttribute("GuideTarget")) == "Vector3"
		edge.Visible = dist > 40 and not inside and not menuOpen and not hasGoal
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
			-- mai sopra la barra degli attrezzi e i comandi in basso
			at = Vector2.new(at.X, math.min(at.Y, vp.Y - 160))
			edge.Position = UDim2.fromOffset(at.X, at.Y)
			arrow.Rotation = math.deg(math.atan2(dir.X, -dir.Y)) -- gira solo la freccia
			edgeLabel.Text = string.format("Home %d m", math.floor(dist))
		end
	end

	-- PERCORSO VERO (Mirko 16/10: nella grotta di ghiaccio le frecce andavano dritte verso il
	-- vuoto). Ogni tanto si calcola un percorso camminabile (PathfindingService) e le frecce lo
	-- seguono; se non c'e' (bisogna arrampicarsi, meta troppo lontana) restano dritte ma solo
	-- dove sotto c'e' terreno: mai frecce sospese nel vuoto
	local PathfindingService = game:GetService("PathfindingService")
	local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5.5, AgentCanJump = true, WaypointSpacing = 4 })
	local route: { Vector3 }? = nil
	local routeTarget: Vector3? = nil
	local routeFrom = Vector3.zero
	local routeAt = -math.huge
	local computing = false
	local function updateRoute(from: Vector3, to: Vector3)
		local moved = (from - routeFrom).Magnitude
		local stale = routeTarget == nil or ((routeTarget :: Vector3) - to).Magnitude > 4
		if computing or (not stale and moved < 12 and os.clock() - routeAt < 4) then
			return
		end
		computing = true
		routeFrom, routeAt = from, os.clock()
		task.spawn(function()
			local ok = (from - to).Magnitude < 1500 and pcall(function()
				path:ComputeAsync(from, to)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				local pts = {}
				for _, w in path:GetWaypoints() do
					table.insert(pts, w.Position)
				end
				route = pts
			else
				route = nil
			end
			routeTarget = to
			computing = false
		end)
	end
	-- punto e direzione a distanza d lungo il percorso, partendo dal punto piu' vicino al giocatore
	local function along(pts: { Vector3 }, from: Vector3, d: number): (Vector3?, Vector3?)
		local best, bi = math.huge, 1
		for i, p in pts do
			local m = (p - from).Magnitude
			if m < best then
				best, bi = m, i
			end
		end
		local left = d
		for i = bi, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local seg = (b - a).Magnitude
			if seg > 0.01 then
				if left <= seg then
					local flatDir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
					return a:Lerp(b, left / seg), if flatDir.Magnitude > 0.01 then flatDir.Unit else nil
				end
				left -= seg
			end
		end
		return nil, nil
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
		local from = (root :: BasePart).Position
		updateRoute(from, target :: Vector3)
		local pts = route
		local shift = (os.clock() * 6) % SPACING -- scorrono in avanti
		for k, a in arrows do
			local dist = 3 + (k - 1) * SPACING + shift
			if dist > flat.Magnitude - 4 then
				hide(a)
				continue
			end
			local p: Vector3? = nil
			local dir = flat.Unit
			if pts then
				local q, d = along(pts, from, dist)
				p = q
				if d then
					dir = d
				end
			else
				p = from + dir * dist
			end
			if not p then
				hide(a)
				continue
			end
			local hit = workspace:Raycast((p :: Vector3) + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), params)
			if not hit then
				hide(a) -- niente terreno sotto: niente freccia sul vuoto
				continue
			end
			local pos = Vector3.new((p :: Vector3).X, hit.Position.Y + 0.3, (p :: Vector3).Z)
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
