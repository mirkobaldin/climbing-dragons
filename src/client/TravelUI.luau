--!strict
-- Viaggio (pagina Travel del menu unico), impaginato come il mockup scelto da Mirko il 15/10:
-- a sinistra le destinazioni (icona, nome, distanza, lucchetto se non scoperte); passandoci
-- sopra col mouse quella si allunga e le altre si ritirano, e a destra compaiono foto del
-- posto, distanza, descrizione e cosa ci si fa, con "Set waypoint" e "Travel".
-- Autorizzazione e spostamento restano sul server (Remotes.Teleport, server/Teleports): si
-- parte solo da un punto di viaggio (attributo AtWaypoint, server/BaseCamps), a casa da ovunque.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Ui = require(RS:WaitForChild("Shared"):WaitForChild("UiView"))
local Theme = require(script.Parent.Theme)
local UiGlow = require(script.Parent.UiGlow)
local UiKit = require(script.Parent.UiKit)
local player = Players.LocalPlayer
local TravelUI = {}

type Place = { key: string, server: string, title: string, icon: string, photo: string, text: string, todo: { string }, needDragon: boolean? }
-- "server" e' il nome che capisce server/Teleports
local FIXED: { Place } = {
	{ key = "Hub", server = "Base camp (hub)", title = "Base camp", icon = "item_TravelHub", photo = "travel_Hub",
		text = "The main camp at the foot of the mountain, where every climb starts.",
		todo = { "Shop and sell ores", "Workbench and trader", "Start your climb" } },
	{ key = "Home", server = "My camp", title = "Home", icon = "item_TravelHome", photo = "travel_Home",
		text = "Your house, your nest and the farm where your dragons rest.",
		todo = { "Hatch eggs in your nest", "Resting dragons make coins", "Craft at your Workbench" } },
	{ key = "Arena", server = "Dragon training", title = "Dragon arena", icon = "item_TravelArena", photo = "travel_Arena",
		text = "Train your dragons and fight the Dragon Duel at the red altar.",
		todo = { "Train your dragon: XP", "Dragon Duel: evolution stones", "Become stronger before the summit" }, needDragon = true },
	{ key = "Gym", server = "Muscle Beach (gym)", title = "Muscle Beach", icon = "item_TravelGym", photo = "travel_Gym",
		text = "The gym by the sea: lift, punch and train with your friends.",
		todo = { "Train your strength", "Hit harder with your ice axe", "Hang out with other players" } },
	{ key = "Island", server = "Dragon Island", title = "Dragon Island", icon = "item_TravelIsland", photo = "travel_Island",
		text = "A floating island of dragons, high above the sea to the west.",
		todo = { "Become your dragon at the orange altar", "Dragon fires and perches", "Meet the dragon tamer" }, needDragon = true },
}

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

local function position(p: Place): Vector3?
	if p.key == "Hub" then
		local markers = workspace:FindFirstChild("MapMarkers")
		local m = markers and markers:FindFirstChild("HubSpawn", true)
		return if m and m:IsA("BasePart") then m.Position else nil
	elseif p.key == "Home" then
		local v = player:GetAttribute("PlotSpawn") or player:GetAttribute("PlotPosition")
		return if typeof(v) == "Vector3" then v else nil
	elseif p.key == "Arena" or p.key == "Gym" or p.key == "Island" then
		local v = workspace:GetAttribute(if p.key == "Arena" then "TrainingPad" elseif p.key == "Island" then "DragonIslandArrival" else "GymCenter")
		return if typeof(v) == "Vector3" then v else nil
	end
	local n = tonumber(string.match(p.key, "%d+"))
	return if n then campPos(n) else nil
end

-- tutte le destinazioni: le cinque fisse, i campi base scoperti e (bloccati) quelli da trovare
local function places(): { { place: Place, found: boolean } }
	local out = {}
	for _, p in FIXED do
		table.insert(out, { place = p, found = true })
	end
	local found: { [number]: boolean } = {}
	for _, n in campNumbers() do
		found[n] = true
	end
	local markers = workspace:FindFirstChild("MapMarkers")
	local camps = markers and markers:FindFirstChild("BaseCamps")
	local all: { number } = {}
	for _, c in (if camps then camps:GetChildren() else {}) :: { Instance } do
		local n = tonumber(string.match(c.Name, "^BaseCamp(%d+)$"))
		if n then
			table.insert(all, n)
		end
	end
	for n in found do
		if not table.find(all, n) then
			table.insert(all, n)
		end
	end
	table.sort(all)
	for _, n in all do
		table.insert(out, {
			place = { key = "Camp" .. n, server = "Base Camp " .. n, title = "Base Camp " .. n, icon = "item_TravelCamp", photo = "travel_Camp",
				text = "A camp you found on the mountain: rest, craft and trade before climbing higher.",
				todo = { "Workbench and trader", "Travel point", "Warm up by the fire" } },
			found = found[n] == true,
		})
	end
	return out
end

local function fmtDist(d: number): string
	local s = tostring(math.floor(d))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function TravelUI.mount(container: Frame, status: (string, boolean) -> (), ctx: any?): () -> ()
	local remote = RS:WaitForChild("Remotes"):WaitForChild("Teleport", 30) :: RemoteEvent?
	local root = Theme.frame(container, Color3.new(), 1)
	root.Name = "Viaggio"
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = false

	local listBox = Theme.frame(root, Color3.new(), 1)
	listBox.Name = "Destinazioni"
	local list = Theme.scroll(listBox)
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.None
	list.ClipsDescendants = true

	local side = Theme.frame(root, Theme.DARK, 1)
	side.Name = "Scheda"
	UiKit.panel(side, { transparency = 0.22 })
	local photo = Instance.new("ImageLabel")
	photo.Name = "Foto"
	photo.BackgroundColor3 = Theme.DARK2
	photo.BackgroundTransparency = 0.2
	photo.ScaleType = Enum.ScaleType.Crop
	photo.ZIndex = 3
	photo.ClipsDescendants = true
	photo.Parent = side
	UiKit.edge(photo, UiKit.LINE, 1, 0.6)
	local photoIcon = Instance.new("ImageLabel") -- ripiego senza foto: l'icona grande sui raggi
	photoIcon.BackgroundTransparency = 1
	photoIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	photoIcon.Position = UDim2.fromScale(0.5, 0.5)
	photoIcon.Size = UDim2.fromScale(0.62, 0.9)
	photoIcon.ZIndex = 5
	photoIcon.Parent = photo
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = photoIcon
	local rays = UiGlow.rays(photo, Theme.ACCENT, 10, 6)
	rays.ZIndex = 4
	local info = Theme.frame(side, Color3.new(), 1)
	info.ZIndex = 3
	local infoIcon = Instance.new("ImageLabel")
	infoIcon.BackgroundTransparency = 1
	infoIcon.Size = UDim2.fromOffset(84, 84)
	infoIcon.ZIndex = 4
	infoIcon.Parent = info
	local infoTitle = Theme.label(info, "", 28, Theme.TEXT, true)
	infoTitle.Font = Enum.Font.GothamBlack
	infoTitle.ZIndex = 4
	local infoDist = UiKit.label(info, "", "stat", 18)
	infoDist.TextColor3 = UiKit.ICE
	infoDist.ZIndex = 4
	local infoFound = UiKit.label(info, "", "status")
	infoFound.ZIndex = 4
	-- descrizione e "cosa ci fai" in un riquadro che scorre: se manca altezza scorre il testo, i
	-- pulsanti in fondo restano sempre dentro lo schermo
	local infoScroll = Theme.scroll(info)
	infoScroll.Name = "Testo"
	infoScroll.ZIndex = 4
	infoScroll.ScrollBarThickness = 4
	local infoText = UiKit.label(infoScroll, "", "body")
	infoText.TextWrapped = true
	infoText.TextTruncate = Enum.TextTruncate.None
	infoText.TextYAlignment = Enum.TextYAlignment.Top
	infoText.RichText = true
	infoText.AutomaticSize = Enum.AutomaticSize.Y
	infoText.Size = UDim2.new(1, -8, 0, 20)
	infoText.ZIndex = 4
	local waypoint = Instance.new("TextButton")
	waypoint.ZIndex = 4
	waypoint.Parent = side
	local go = Instance.new("TextButton")
	go.ZIndex = 4
	go.Parent = side
	local note = UiKit.label(side, "", "secondary")
	note.ZIndex = 4

	type Row = { button: TextButton, entry: { place: Place, found: boolean } }
	local rows: { Row } = {}
	local selected: string = "Home"
	local hovered: string? = nil
	local entries: { { place: Place, found: boolean } } = {}
	local rowH = 76

	local function uiScale(): number
		local gui = container:FindFirstAncestorWhichIsA("ScreenGui")
		local su = gui and gui:FindFirstChild("ScalaUI") :: UIScale?
		return if su and su.Scale > 0 then su.Scale else 1
	end
	local function myPos(): Vector3?
		local character = player.Character
		local r = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return if r then r.Position else nil
	end
	-- perche' non si puo' partire (nil = si puo')
	local function blocked(e: { place: Place, found: boolean }): string?
		if not e.found then
			return "Undiscovered: find this camp on the mountain first"
		end
		if e.place.needDragon and ((player:GetAttribute("DragonCount") or 0) :: number) < 1 then
			return "Unlocks with your first dragon"
		end
		local home = e.place.key == "Home"
		if home and player:GetAttribute("DescentStart") then
			return "Finish your timed descent first"
		end
		if not home and player:GetAttribute("AtWaypoint") ~= true then
			return "Travel only from a base camp, your home, the arena or the gym"
		end
		-- stessa ricarica del server (server/Teleports: 20 s, 60 s per casa da lontano)
		local at = player:GetAttribute("TeleportAt")
		if type(at) == "number" then
			local cd = if home and player:GetAttribute("AtWaypoint") ~= true then 60 else 20
			local left = math.ceil(cd - (workspace:GetServerTimeNow() - at))
			if left > 0 then
				return string.format("Travel ready in %d s", left)
			end
		end
		return nil
	end
	local function entryFor(key: string): { place: Place, found: boolean }?
		for _, e in entries do
			if e.place.key == key then
				return e
			end
		end
		return nil
	end

	local function showSide()
		local e = entryFor(hovered or selected) or entries[1]
		if not e then
			return
		end
		local p = e.place
		local hasPhoto = Ui.asset(photo, p.photo)
		-- la foto riempie il riquadro (UiView.asset la rimette in Fit e restavano due bande scure)
		photo.ScaleType = Enum.ScaleType.Crop
		photo.Visible = true -- (UiView.asset la nasconde se l'immagine manca: resta il riquadro con l'icona)
		photoIcon.Visible = not hasPhoto
		rays.Visible = not hasPhoto
		if not hasPhoto then
			photo.Image = ""
			Theme.assetPreview(photoIcon, p.icon, nil)
		end
		Theme.assetPreview(infoIcon, p.icon, nil)
		infoTitle.Text = p.title
		local here, there = myPos(), position(p)
		infoDist.Text = if not e.found then "Location unknown"
			elseif here and there then fmtDist((here - there).Magnitude) .. " m away" else "—"
		infoFound.Text = if e.found then "DISCOVERED" else "UNDISCOVERED"
		infoFound.TextColor3 = if e.found then UiKit.GOOD else UiKit.DIM
		local bullets = {}
		for _, t in p.todo do
			table.insert(bullets, "•  " .. t)
		end
		infoText.Text = p.text .. "\n\n<font color=\"#F0F4FA\">WHAT YOU CAN DO</font>\n" .. table.concat(bullets, "\n")
		local why = blocked(e)
		-- Travel e' l'azione principale quando si puo' partire, Set waypoint quella secondaria
		UiKit.button(go, if why then "disabled" else "primary")
		go.Text = "TRAVEL"
		UiKit.button(waypoint, if e.found and there then "secondary" else "disabled")
		waypoint.Text = "SET WAYPOINT"
		note.Text = (why or (if p.key == "Home" and player:GetAttribute("AtWaypoint") ~= true then "Home works from anywhere (60 s recharge)" else "Ready to travel"))
	end

	local function placeRows(animate: boolean)
		local w = list.AbsoluteSize.X / uiScale() - 12
		for i, r in rows do
			local key = r.entry.place.key
			local active = key == (hovered or selected)
			-- quella sotto il mouse (o scelta) si allunga, le altre si ritirano
			local pull = if hovered and not active then 36 elseif not active then 14 else 0
			local goal = {
				Position = UDim2.fromOffset(4, (i - 1) * (rowH + 10) + 4),
				Size = UDim2.fromOffset(math.max(120, w - pull), rowH),
			}
			if animate then
				TweenService:Create(r.button, TweenInfo.new(0.16, Enum.EasingStyle.Quad), goal):Play()
			else
				r.button.Position, r.button.Size = goal.Position, goal.Size
			end
			-- la scelta avanza (accento e piu' vicina), le spente restano scure e indietro
			UiKit.select(r.button, key == selected)
			r.button.BackgroundTransparency = if not r.entry.found then 0.5 elseif active then 0.08 else 0.25
		end
		list.CanvasSize = UDim2.fromOffset(0, #rows * (rowH + 10) + 10)
	end

	local function build()
		for _, r in rows do
			r.button:Destroy()
		end
		table.clear(rows)
		entries = places()
		local here = myPos()
		for _, e in entries do
			local p = e.place
			local b = Instance.new("TextButton")
			b.Name = p.key
			b.Text = ""
			b.AutoButtonColor = false
			b:SetAttribute("UiNative", true)
			b.Parent = list
			UiKit.card(b, p.key == selected)
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.Position = UDim2.fromOffset(12, 6)
			icon.Size = UDim2.fromOffset(rowH - 12, rowH - 12)
			icon.ZIndex = 3
			icon.ImageTransparency = if e.found then 0 else 0.35
			icon.Parent = b
			Theme.assetPreview(icon, p.icon, nil)
			local t = UiKit.label(b, p.title, "name", 22)
			t.TextColor3 = if e.found then UiKit.TEXT else UiKit.DIM
			t.Font = Enum.Font.GothamBlack
			t.Position = UDim2.fromOffset(rowH + 8, 0)
			t.Size = UDim2.new(1, -(rowH + 8 + 150), 1, 0)
			t.ZIndex = 3
			local there = position(p)
			local d = Theme.label(b, if not e.found then "Undiscovered" elseif here and there then fmtDist((here - there).Magnitude) .. " m" else "—",
				18, if e.found then Theme.BLUE else Theme.MUTED, true)
			d.TextXAlignment = Enum.TextXAlignment.Right
			d.AnchorPoint = Vector2.new(1, 0)
			d.Position = UDim2.new(1, -46, 0, 0)
			d.Size = UDim2.new(0, 140, 1, 0)
			d.ZIndex = 3
			local arrow = Instance.new("ImageLabel")
			arrow.BackgroundTransparency = 1
			arrow.AnchorPoint = Vector2.new(1, 0.5)
			arrow.Position = UDim2.new(1, -12, 0.5, 0)
			arrow.Size = UDim2.fromOffset(26, 26)
			arrow.ZIndex = 3
			arrow.Parent = b
			if e.found then
				local chevron = UiKit.label(b, ">", "name", 24)
				chevron.TextXAlignment = Enum.TextXAlignment.Center
				chevron.AnchorPoint = Vector2.new(1, 0)
				chevron.Position = UDim2.new(1, -8, 0, 0)
				chevron.Size = UDim2.new(0, 30, 1, 0)
				chevron.ZIndex = 3
				arrow.Visible = false
			else
				Ui.asset(arrow, "icon_lock")
			end
			b.MouseEnter:Connect(function()
				hovered = p.key
				placeRows(true)
				showSide()
			end)
			b.MouseLeave:Connect(function()
				if hovered == p.key then
					hovered = nil
					placeRows(true)
					showSide()
				end
			end)
			b.Activated:Connect(function()
				selected = p.key
				hovered = nil
				placeRows(true)
				showSide()
			end)
			table.insert(rows, { button = b, entry = e })
		end
		if not entryFor(selected) then
			selected = "Home"
		end
		placeRows(false)
		showSide()
	end

	waypoint.Activated:Connect(function()
		local e = entryFor(selected)
		local there = e and e.found and position(e.place)
		if not e or not there then
			status("You haven't found this place yet", false)
			return
		end
		-- freccia e distanza della guida (client/Guide) verso il posto scelto
		player:SetAttribute("GuideTarget", there)
		player:SetAttribute("GuideLabel", e.place.title)
		status("Waypoint set: " .. e.place.title, true)
	end)
	go.Activated:Connect(function()
		local e = entryFor(selected)
		if not e then
			return
		end
		local why = blocked(e)
		if why then
			status(why, false)
			return
		end
		if remote then
			remote:FireServer(e.place.server)
		end
		local menu = player.PlayerGui:FindFirstChild("MainMenu")
		if menu then
			menu:SetAttribute("MenuOpen", false)
		end
	end)

	local function layout()
		local w = root.AbsoluteSize.X / uiScale()
		local h = root.AbsoluteSize.Y / uiScale()
		if w < 50 then
			return
		end
		-- destinazioni a sinistra (56%), scheda del posto a destra (44%), anche sul telefono in
		-- orizzontale (riferimento di Mirko 16/10); solo una pagina davvero stretta va in colonna
		local stacked = w < 600
		local sideW = if stacked then w else math.clamp(math.floor(w * 0.44), 300, 560)
		local listH, sideH = 260, 460
		if stacked then
			listBox.Position = UDim2.fromOffset(0, 0)
			listBox.Size = UDim2.new(1, 0, 0, listH)
			side.Position = UDim2.fromOffset(0, listH + 12)
			side.Size = UDim2.new(1, 0, 0, sideH)
			h = sideH
		else
			listBox.Position = UDim2.fromOffset(0, 0)
			listBox.Size = UDim2.new(1, -(sideW + 14), 1, 0)
			side.Position = UDim2.new(1, -sideW, 0, 0)
			side.Size = UDim2.new(0, sideW, 1, 0)
		end
		local wantH = if stacked then listH + 12 + sideH else 0
		if container:GetAttribute("AltezzaMinima") ~= wantH then
			container:SetAttribute("AltezzaMinima", wantH)
			if ctx and ctx.fit then
				task.defer(ctx.fit)
			end
		end
		local low = h < 420 -- telefono in orizzontale
		rowH = if low then 50 elseif h < 520 then 58 else 76
		-- piede fisso: Set waypoint e Travel, sotto la riga col motivo del blocco o il tempo
		local btnH = if low then 40 else 48
		local noteH = if low then 20 else 26
		local footH = btnH + noteH + (if low then 12 else 18)
		-- la foto prende quello che avanza (mai piu' di meta' dello spazio sopra il piede)
		local photoH = math.floor(math.min((sideW - 24) * 0.56, (h - footH) * (if low then 0.42 else 0.5)))
		photo.Position = UDim2.fromOffset(10, 10)
		photo.Size = UDim2.new(1, -20, 0, photoH)
		local y = photoH + (if low then 16 else 22)
		info.Position = UDim2.fromOffset(12, y)
		info.Size = UDim2.new(1, -24, 1, -(y + footH))
		local ic = if low then 40 elseif h < 520 then 64 else 84
		infoIcon.Size = UDim2.fromOffset(ic, ic)
		infoIcon.Position = UDim2.fromOffset(0, 0)
		infoTitle.TextSize = if low then 20 else 28
		infoTitle.Position = UDim2.fromOffset(ic + 10, 0)
		infoTitle.Size = UDim2.new(0.6, -(ic + 10), 0, if low then 22 else if h < 520 then 28 else 34)
		if low then
			-- una riga sola: nome, distanza, stato
			infoDist.Position = UDim2.fromOffset(ic + 10, 22)
			infoDist.Size = UDim2.new(0.5, -(ic + 10) / 2, 0, 18)
			infoDist.TextSize = 15
			infoFound.Position = UDim2.new(0.5, (ic + 10) / 2, 0, 22)
			infoFound.Size = UDim2.new(0.5, -(ic + 10) / 2, 0, 18)
		else
			infoDist.Position = UDim2.fromOffset(ic + 10, if h < 520 then 26 else 34)
			infoDist.Size = UDim2.new(0.5, -(ic + 10) / 2, 0, 22)
			infoFound.Position = if h < 520 then UDim2.new(0.5, (ic + 10) / 2, 0, 26) else UDim2.fromOffset(ic + 10, 58)
			infoFound.Size = UDim2.new(0.5, -(ic + 10) / 2, 0, 22)
		end
		infoScroll.Position = UDim2.fromOffset(0, ic + 4)
		infoScroll.Size = UDim2.new(1, 0, 1, -(ic + 4))
		infoText.TextSize = if low then 14 elseif h < 520 then 14 else 16
		waypoint.AnchorPoint = Vector2.new(0, 1)
		waypoint.Position = UDim2.new(0, 12, 1, -(noteH + 8))
		waypoint.Size = UDim2.new(0.5, -18, 0, btnH)
		go.AnchorPoint = Vector2.new(1, 1)
		go.Position = UDim2.new(1, -12, 1, -(noteH + 8))
		go.Size = UDim2.new(0.5, -18, 0, btnH)
		note.AnchorPoint = Vector2.new(0, 1)
		note.Position = UDim2.new(0, 14, 1, -4)
		note.Size = UDim2.new(1, -28, 0, noteH)
		note.TextWrapped = true
		for _, r in rows do
			for _, c in r.button:GetChildren() do
				if c:IsA("ImageLabel") and c.Size.X.Offset > 30 then
					c.Size = UDim2.fromOffset(rowH - 12, rowH - 12)
				end
			end
		end
		placeRows(false)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	list.MouseLeave:Connect(function()
		if hovered then
			hovered = nil
			placeRows(true)
			showSide()
		end
	end)
	-- la ricarica scende da sola mentre la pagina e' aperta
	task.spawn(function()
		while root.Parent do
			task.wait(1)
			local at = player:GetAttribute("TeleportAt")
			if container.Visible and type(at) == "number" and workspace:GetServerTimeNow() - at < 62 then
				showSide()
			end
		end
	end)
	for _, attr in { "DragonCount", "CampsFound", "AtWaypoint", "PlotPosition", "PlotSpawn", "TeleportAt", "DescentStart" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if container.Visible then
				build()
			end
		end)
	end

	return function()
		build()
		layout()
		if ctx and ctx.sub then
			ctx.sub("Choose your destination.")
		end
	end
end

return TravelUI
