--!strict
-- Destinazioni e requisiti mostrati dal client; autorizzazione e spostamento restano sul server.
-- Oltre ai quattro punti fissi compaiono i campi base gia' scoperti (attributo CampsFound); si
-- parte solo da un punto di viaggio (attributo AtWaypoint, lo calcola server/BaseCamps).
local CAS = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Ui = require(RS:WaitForChild("Shared").UiView)
local Theme = require(script.Parent.Theme)
local player = Players.LocalPlayer
local TeleportMenu = {}
local FIXED = { "Base camp (hub)", "My camp", "Dragon training", "Muscle Beach (gym)", "Dragon Island" }
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
		local p = workspace:GetAttribute(if index == 3 then "TrainingPad" elseif index == 5 then "DragonIslandArrival" else "GymCenter")
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
	local destinations = panel.Destinations
	-- fondo scuro come le altre finestre (stile Black Ops 2), righe colorate sopra
	Ui.tint(panel, Theme.DARK, false, 0)
	local veil = panel:FindFirstChild("Tinta") :: Frame?
	if veil then
		veil.BackgroundTransparency = 0.1
	end
 local bound: { [Instance]: boolean } = {}
	local function bind(i: number)
		local b = destinations["Destination" .. i]
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
		local template = destinations:FindFirstChild("Destination4")
		for i = 6, #NAMES do -- nella GUI ci sono 4 pulsanti: gli altri sono copie del quarto
			if not destinations:FindFirstChild("Destination" .. i) and template then
				local c = template:Clone()
				c.Name = "Destination" .. i
				c.Parent = destinations
			end
			bind(i)
		end
		local count = #NAMES
  for i = 1, count do
   local b = destinations:FindFirstChild("Destination" .. i)
   if b then
    b.Position = UDim2.fromOffset(4, (i - 1) * 68 + 4)
    b.Size = UDim2.new(1, -16, 0, 60)
    b.Visible = true
    b.Text = ""
    b.Title.Position = UDim2.fromOffset(58, 8)
    b.Title.Size = UDim2.new(1, -168, 1, -16)
    b.Title.TextWrapped = false
    b.Icon.Position = UDim2.fromOffset(8, 8)
    b.Icon.Size = UDim2.fromOffset(44, 44)
    b.Distance.AnchorPoint = Vector2.new(1, 0.5)
    b.Distance.Position = UDim2.new(1, -14, 0.5, 0)
    b.Distance.Size = UDim2.fromOffset(100, 32)
    b.Distance.TextXAlignment = Enum.TextXAlignment.Right
    b.Title.TextXAlignment = Enum.TextXAlignment.Left
    Theme.fitText(b.Title, 22, false)
    Theme.fitText(b.Distance, 18, false)
    -- riga piatta colorata: niente PNG con la sua cornice dentro un'altra cornice
    b:SetAttribute("UiNative", true)
    Theme.action(b, "alt")
    bind(i)
   end
  end
  destinations.CanvasSize = UDim2.fromOffset(0, count * 68 + 8)

		local k = count + 1
		while destinations:FindFirstChild("Destination" .. k) do
			destinations["Destination" .. k].Visible = false
			k += 1
		end
	end
	local function refresh()
		layout()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local here = player:GetAttribute("AtWaypoint") == true
		panel.Title.Text = "Travel"
  local titles = {"Base camp", "Home", "Dragon arena", "Muscle Beach", "Dragon Island"}
  local icons = {"TravelHub", "TravelHome", "TravelArena", "TravelGym", "TravelIsland"}
  for i, name in NAMES do
   local b = destinations["Destination" .. i]
   local locked = ((i == 3 or i == 5) and ((player:GetAttribute("DragonCount") or 0) :: number) < 1)
    or (not here and i ~= 2)
   local homeFar = name == "My camp" and not here
   b.Title.Text = titles[i] or name
   Theme.assetPreview(b.Icon, "item_" .. (icons[i] or "TravelCamp"), nil)
   local pos = destination(i)
   b.Distance.Text = if locked then "Locked" elseif homeFar then "◷ 60 s"
    elseif root and pos then string.format("%d m", math.floor((root.Position - pos).Magnitude)) else "—"
   -- distanza / "Locked" come semplice scritta a destra (prima un riquadro col bordo)
   b.Distance.Text = if locked then "" else b.Distance.Text
   b.Distance.BackgroundTransparency = 1
   local ds = b.Distance:FindFirstChildOfClass("UIStroke")
   if ds then ds.Enabled = false end
   Theme.action(b, if i == 2 then "main" else "alt", locked)
   b.Title.TextTransparency = if locked then 0.35 else 0
   local lock = b:FindFirstChild("Lock") :: ImageLabel?
   if not lock then
    lock = Instance.new("ImageLabel")
    lock.Name = "Lock"
    lock.BackgroundTransparency = 1
    lock.AnchorPoint = Vector2.new(1, 0.5)
    lock.Position = UDim2.new(1, -16, 0.5, 0)
    lock.Size = UDim2.fromOffset(30, 30)
    lock.ZIndex = 4
    lock.Parent = b
   end
   Ui.asset(lock :: ImageLabel, "icon_lock")
   lock.Visible = locked
  end
	end
	for i = 1, 5 do -- il quinto (isola) lo crea e lo collega layout()
		bind(i)
	end
	local function toggle()
		if panel.Visible then
			panel.Visible = false
		else
			local menu = player.PlayerGui:FindFirstChild("MainMenu")
			if menu then menu:SetAttribute("MenuOpen", false) end
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
  local logical = Ui.fitScale(gui, vp)
  local m = Ui.menuMetrics(logical)
  local width = math.min(680, m.width)
  Ui.px(panel, 0.5, 0, 0, m.y, width, m.height, 0.5, 0)
  panel.Title.Position = UDim2.fromOffset(12, 8)
  panel.Title.Size = UDim2.new(1, -80, 0, 44)
  Ui.px(panel.Close, 1, -8, 0, 8, 44, 44, 1, 0)
  destinations.Position = UDim2.fromOffset(8, 60)
  destinations.Size = UDim2.new(1, -16, 1, -68)
 end)
	refresh()
end
return TeleportMenu
