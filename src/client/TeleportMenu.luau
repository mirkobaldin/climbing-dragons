--!strict
-- Destinazioni e requisiti mostrati dal client; autorizzazione e spostamento restano sul server.
-- Oltre ai quattro punti fissi compaiono i campi base gia' scoperti (attributo CampsFound); si
-- parte solo da un punto di viaggio (attributo AtWaypoint, lo calcola server/BaseCamps).
local CAS = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Ui = require(RS:WaitForChild("Shared").UiView)
local player = Players.LocalPlayer
local TeleportMenu = {}
local FIXED = { "Base camp (hub)", "My camp", "Dragon training", "Muscle Beach (gym)" }
local NAMES = table.clone(FIXED)
-- campi base scoperti, in ordine di numero (Base Camp 1, 2...)
local function campNumbers(): { number }
	local list = {}
	for n in string.gmatch(tostring(player:GetAttribute("CampsFound") or ""), "%d+") do
		table.insert(list, tonumber(n) :: number)
	end
	table.sort(list)
	return list
end
local function campPos(n: number): Vector3?
	local markers = workspace:FindFirstChild("MapMarkers")
	local camps = markers and markers:FindFirstChild("BaseCamps")
	local c = camps and camps:FindFirstChild("BaseCamp" .. n)
	return if c and c:IsA("BasePart") then c.Position else nil
end
local function destination(index: number): Vector3?
	if index > #FIXED then
		local n = tonumber(string.match(NAMES[index] or "", "%d+"))
		return if n then campPos(n) else nil
	end
	if index == 1 then
		local markers = workspace:FindFirstChild("MapMarkers")
		local m = markers and markers:FindFirstChild("HubSpawn", true)
		return if m and m:IsA("BasePart") then m.Position else nil
	elseif index == 2 then
		local p = player:GetAttribute("PlotSpawn") or player:GetAttribute("PlotPosition")
		return if typeof(p) == "Vector3" then p else nil
	else
		local p = workspace:GetAttribute(if index == 3 then "TrainingPad" else "GymCenter")
		return if typeof(p) == "Vector3" then p else nil
	end
end
function TeleportMenu.start()
	local remote = RS:WaitForChild("Remotes"):WaitForChild("Teleport", 30) :: RemoteEvent?
	if not remote then
		return
	end
	local gui = Ui.screen("Teletrasporto")
	local panel, open = Ui.node(gui, "Panel"), Ui.node(gui, "Open")
	open.Visible = player.PlayerGui:FindFirstChild("MainMenu") == nil
	local bound: { [Instance]: boolean } = {}
	local function bind(i: number)
		local b = panel["Destination" .. i]
		if b and not bound[b] then
			bound[b] = true
			b.Activated:Connect(function()
				panel.Visible = false
				(remote :: RemoteEvent):FireServer(NAMES[i])
			end)
		end
	end
	-- un pulsante per destinazione: i campi base sono copie del quarto; con piu' di 4 si va su
	-- due colonne e le righe si stringono
	local function layout()
		NAMES = table.clone(FIXED)
		for _, n in campNumbers() do
			table.insert(NAMES, "Base Camp " .. n)
		end
		local template = panel:FindFirstChild("Destination4")
		for i = #FIXED + 1, #NAMES do
			if not panel:FindFirstChild("Destination" .. i) and template then
				local c = template:Clone()
				c.Name = "Destination" .. i
				c.Parent = panel
			end
			bind(i)
		end
		local count = #NAMES
		local cols = if count > 4 then 2 else 1
		local rows = math.ceil(count / cols)
		local h = math.min(0.18, 0.78 / rows - 0.02)
		local w = if cols == 2 then 0.44 else 0.9
		for i = 1, count do
			local b = panel:FindFirstChild("Destination" .. i)
			if b then
				local col = if cols == 2 then (i - 1) % 2 else 0
				local row = if cols == 2 then (i - 1) // 2 else i - 1
				b.Position = UDim2.fromScale(0.05 + col * 0.46, 0.18 + row * (h + 0.02))
				b.Size = UDim2.fromScale(w, h)
				b.Visible = true
			end
		end
		local k = count + 1
		while panel:FindFirstChild("Destination" .. k) do
			panel["Destination" .. k].Visible = false
			k += 1
		end
	end
	local function refresh()
		layout()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local here = player:GetAttribute("AtWaypoint") == true
		panel.Title.Text = if here then "Teleport" else "Teleport · from here only Home"
		for i, name in NAMES do
			local b = panel["Destination" .. i]
			local locked = i == 3 and ((player:GetAttribute("DragonCount") or 0) :: number) < 1
			local homeFar = name == "My camp" and not here
			b.Title.Text = (if name == "My camp" then "Home" else name)
				.. (if locked then "\nFirst dragon required" elseif homeFar then "\nfrom anywhere · 60 s" elseif not here then "\nfrom a travel point" else "")
			Ui.asset(b.Icon, if locked then "icon_lock" else "icon_teleport")
			local pos = destination(i)
			b.Distance.Text = if root and pos
				then string.format("%d m", math.floor((root.Position - pos).Magnitude))
				else ""
		end
	end
	for i = 1, #FIXED do
		bind(i)
	end
	local function toggle()
		if panel.Visible then
			panel.Visible = false
		else
			refresh()
			Ui.open(panel)
		end
	end
	panel.Close.Activated:Connect(function()
		panel.Visible = false
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
	open.Activated:Connect(toggle)
	CAS:BindAction("TeleportMenu", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.T)
	for _, attr in { "DragonCount", "HouseLevel", "PlotPosition", "PlotSpawn", "CampsFound", "AtWaypoint" } do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	Ui.viewportChanged(function(vp)
		panel.Position = UDim2.fromScale(if vp.X < vp.Y then 0.04 else 0.2, 0.1)
		panel.Size = UDim2.fromScale(if vp.X < vp.Y then 0.92 else 0.65, 0.8)
	end)
	refresh()
end
return TeleportMenu
