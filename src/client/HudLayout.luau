--!strict
-- HUD modificabile, sul telefono E sul computer (Mirko 16/10, docs/CLOUD_UI_RIFINITURA.md punto 10).
-- Ogni elemento spostabile (personaggio, drago, missione, meteo, tasti ?/HIDE/⚙, barra 1-5, MENU,
-- Roar/Z) si registra qui col suo nome. In modifica (tasto ⚙ dell'HUD) compare una barra in alto
-- con DONE e RESET e ogni elemento ha un contorno dorato col nome: si trascina col dito o col
-- mouse. Le posizioni sono frazioni dello schermo (centro dell'elemento) e si salvano nello
-- stesso attributo ControlsLayout dei tasti del telefono (server/Progression, Remotes.SaveControls),
-- una disposizione per il telefono (HUD_touch) e una per il computer (HUD_pc). RESET rimette tutto
-- com'era (anche i tasti del telefono).
--
--   HudLayout.register(name, obj, title)  elemento spostabile (obj sta in una ScreenGui)
--   HudLayout.place(name, obj) -> bool    dopo l'impaginazione normale: se il giocatore l'ha
--                                         spostato lo rimette li' (true)
--   HudLayout.onChange(fn)                l'impaginazione cambia (trascinamento, reset, caricamento)
--   HudLayout.onEditing(fn)               si entra/esce dalla modifica
--   HudLayout.setEditing(on), HudLayout.editing()
--   HudLayout.data()                      la tabella di ControlsLayout (MobileControls ci tiene i
--                                         suoi tasti in pixel dall'angolo e MenuFrac)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Ui = require(RS:WaitForChild("Shared"):WaitForChild("UiView"))
local ClientState = require(script.Parent.ClientState)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local HudLayout = {}

type Entry = { obj: GuiObject, title: string, outline: Frame? }
local entries: { [string]: Entry } = {}
local order: { string } = {}
local changeHooks: { () -> () } = {}
local editHooks: { (boolean) -> () } = {}
local editing = false

-- ControlsLayout -> tabella (le voci HUD_* sono tabelle di posizioni, le altre dei tasti)
local loadedRaw: any = false
function HudLayout.data(): { [string]: any }
	local raw = player:GetAttribute("ControlsLayout")
	if raw ~= loadedRaw or (ClientState :: any).controlsCustom == nil then
		loadedRaw = raw
		local t: { [string]: any } = {}
		if type(raw) == "string" then
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if ok and type(decoded) == "table" then
				for k, v in decoded do
					if type(k) == "string" and type(v) == "table" then
						t[k] = v
					end
				end
			end
		end
		;(ClientState :: any).controlsCustom = t
	end
	return (ClientState :: any).controlsCustom
end

function HudLayout.device(): string
	return if Ui.touch() then "touch" else "pc"
end

local function section(create: boolean): { [string]: { number } }?
	local d = HudLayout.data()
	local key = "HUD_" .. HudLayout.device()
	local s = d[key]
	if type(s) ~= "table" then
		if not create then
			return nil
		end
		s = {}
		d[key] = s
	end
	return s
end

-- posizione scelta (frazioni x, y del centro), o nil
function HudLayout.get(name: string): { number }?
	local s = section(false)
	local v = s and s[name]
	if type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" then
		return { math.clamp(v[1], 0.02, 0.98), math.clamp(v[2], 0.03, 0.97) }
	end
	-- il tasto MENU del telefono era gia' spostabile (voce MenuFrac)
	if name == "Menu" and HudLayout.device() == "touch" then
		local m = HudLayout.data().MenuFrac
		if type(m) == "table" and type(m[1]) == "number" and type(m[2]) == "number" then
			return { math.clamp(m[1], 0.02, 0.98), math.clamp(m[2], 0.03, 0.97) }
		end
	end
	return nil
end

local function fire()
	for _, fn in changeHooks do
		task.spawn(fn)
	end
end

function HudLayout.onChange(fn: () -> ())
	table.insert(changeHooks, fn)
end

function HudLayout.onEditing(fn: (boolean) -> ())
	table.insert(editHooks, fn)
end

function HudLayout.editing(): boolean
	return editing
end

-- rimette l'elemento dove l'ha messo il giocatore (centro = frazione della sua ScreenGui)
function HudLayout.place(name: string, obj: GuiObject?): boolean
	local e = entries[name]
	local o = obj or (e and e.obj)
	if not o then
		return false
	end
	local f = HudLayout.get(name)
	if not f then
		return false
	end
	o.AnchorPoint = Vector2.new(0.5, 0.5)
	o.Position = UDim2.fromScale(f[1], f[2])
	return true
end

function HudLayout.register(name: string, obj: GuiObject, title: string?)
	if not entries[name] then
		table.insert(order, name)
	end
	entries[name] = { obj = obj, title = title or name }
end

------------------------------------------------------------------------------------------
-- Modalita' di modifica: barra in alto (DONE / RESET) e contorni sugli elementi
local bar: ScreenGui? = nil
local dragging: { name: string, input: InputObject? }? = nil

local function scaleOf(gui: ScreenGui): number
	local u = gui:FindFirstChild("ScalaUI") :: UIScale?
	return if u and u.Scale > 0 then u.Scale else 1
end

local function outlineOf(name: string): Frame?
	local e = entries[name]
	if not e then
		return nil
	end
	local gui = e.obj:FindFirstAncestorWhichIsA("ScreenGui")
	if not gui then
		return nil
	end
	local o = e.outline
	if not o or not o.Parent then
		local f = Instance.new("Frame")
		f.Name = "ContornoModifica_" .. name
		f.BackgroundColor3 = UiKit.ACCENT
		f.BackgroundTransparency = 0.88
		f.BorderSizePixel = 0
		f.Active = true
		f.ZIndex = 200
		f:SetAttribute("UiNative", true)
		local s = Instance.new("UIStroke")
		s.Color = UiKit.ACCENT
		s.Thickness = 2
		s.Transparency = 0.1
		s:SetAttribute("KeepStroke", true)
		s.Parent = f
		local l = UiKit.label(f, e.title, "status", 13)
		l.TextColor3 = UiKit.ACCENT
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.AnchorPoint = Vector2.new(0.5, 1)
		l.Position = UDim2.new(0.5, 0, 0, -2)
		l.Size = UDim2.new(1, 40, 0, 18)
		l.TextTruncate = Enum.TextTruncate.None
		l.ZIndex = 201
		f.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = { name = name, input = if input.UserInputType == Enum.UserInputType.Touch then input else nil }
			end
		end)
		f.Parent = gui
		e.outline = f
		o = f
	end
	-- sopra l'elemento (stessa ScreenGui: stesse coordinate)
	local of = o :: Frame
	local k = scaleOf(gui)
	local pos = (e.obj.AbsolutePosition - gui.AbsolutePosition) / k
	local size = e.obj.AbsoluteSize / k
	of.AnchorPoint = Vector2.zero
	of.Position = UDim2.fromOffset(pos.X - 4, pos.Y - 4)
	of.Size = UDim2.fromOffset(math.max(28, size.X + 8), math.max(28, size.Y + 8))
	of.Visible = editing and e.obj.Visible and gui.Enabled
	return of
end

local function refreshOutlines()
	for _, name in order do
		outlineOf(name)
	end
end

local function save()
	local remote = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("SaveControls")
	if not remote then
		return
	end
	local d = HudLayout.data()
	local raw = if next(d) ~= nil then HttpService:JSONEncode(d) else nil
	loadedRaw = raw -- il server rimette lo stesso attributo: niente ricaricamento
	;(remote :: RemoteEvent):FireServer(raw)
end

function HudLayout.reset()
	local d = HudLayout.data()
	d["HUD_" .. HudLayout.device()] = nil
	if HudLayout.device() == "touch" then
		-- anche i tasti del telefono e il vecchio MenuFrac tornano a posto
		for k in d do
			if string.sub(k, 1, 4) ~= "HUD_" then
				d[k] = nil
			end
		end
	end
	fire()
	task.defer(refreshOutlines)
end

local function makeBar(): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = "ModificaHUD"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = false
	g.DisplayOrder = 60
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Enabled = false
	g.Parent = player:WaitForChild("PlayerGui")
	local panel = Instance.new("Frame")
	panel.Name = "Barra"
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.fromOffset(560, 84)
	panel.Parent = g
	UiKit.panel(panel, { border = 10 })
	local title = UiKit.label(panel, "EDIT HUD", "name", 20)
	title.TextColor3 = UiKit.ACCENT
	title.Position = UDim2.fromOffset(22, 10)
	title.Size = UDim2.new(1, -280, 0, 28)
	title.ZIndex = 3
	local hint = UiKit.label(panel, "", "body", 15)
	hint.Name = "Aiuto"
	hint.Position = UDim2.fromOffset(22, 40)
	hint.Size = UDim2.new(1, -280, 0, 36)
	hint.TextWrapped = true
	hint.TextTruncate = Enum.TextTruncate.None
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.ZIndex = 3
	local reset = Instance.new("TextButton")
	reset.Name = "Reset"
	reset.AnchorPoint = Vector2.new(1, 0.5)
	reset.Position = UDim2.new(1, -140, 0.5, 0)
	reset.Size = UDim2.fromOffset(112, 46)
	reset.ZIndex = 4
	reset.Parent = panel
	UiKit.button(reset, "secondary")
	reset.Text = "RESET"
	local done = Instance.new("TextButton")
	done.Name = "Fatto"
	done.AnchorPoint = Vector2.new(1, 0.5)
	done.Position = UDim2.new(1, -18, 0.5, 0)
	done.Size = UDim2.fromOffset(112, 46)
	done.ZIndex = 4
	done.Parent = panel
	UiKit.button(done, "primary")
	done.Text = "DONE"
	reset.Activated:Connect(HudLayout.reset)
	done.Activated:Connect(function()
		HudLayout.setEditing(false)
	end)
	Ui.viewportChanged(function(vp)
		Ui.fitScale(g, vp)
	end, g)
	return g
end

function HudLayout.setEditing(on: boolean)
	if editing == on then
		return
	end
	editing = on
	ClientState.editingControls = on
	if not bar then
		bar = makeBar()
	end
	local b = bar :: ScreenGui
	b.Enabled = on
	local hint = b:FindFirstChild("Aiuto", true) :: TextLabel?
	if hint then
		hint.Text = if Ui.touch() then "Drag the highlighted parts and the buttons where you like."
			else "Drag the highlighted parts with the mouse."
	end
	for _, fn in editHooks do
		task.spawn(fn, on)
	end
	refreshOutlines()
	if not on then
		dragging = nil
		save()
	end
end

-- trascinamento: il centro dell'elemento segue il dito o il mouse
UIS.InputChanged:Connect(function(input)
	local d = dragging
	if not d or not editing then
		return
	end
	if d.input and input ~= d.input then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local e = entries[d.name]
	local gui = e and e.obj:FindFirstAncestorWhichIsA("ScreenGui")
	if not e or not gui or gui.AbsoluteSize.X < 1 then
		return
	end
	local p = Vector2.new(input.Position.X, input.Position.Y) - gui.AbsolutePosition
	local s = section(true) :: { [string]: { number } }
	s[d.name] = {
		math.floor(math.clamp(p.X / gui.AbsoluteSize.X, 0.02, 0.98) * 1000) / 1000,
		math.floor(math.clamp(p.Y / gui.AbsoluteSize.Y, 0.03, 0.97) * 1000) / 1000,
	}
	HudLayout.place(d.name)
	outlineOf(d.name)
end)
UIS.InputEnded:Connect(function(input)
	local d = dragging
	if d and (input == d.input or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragging = nil
		fire()
		task.defer(refreshOutlines)
	end
end)
-- contorni al passo degli elementi (si aprono, si piegano, cambiano grandezza)
task.spawn(function()
	while true do
		task.wait(0.2)
		if editing then
			refreshOutlines()
		end
	end
end)
-- disposizione nuova dal server (all'ingresso): tutti si rimettono a posto
player:GetAttributeChangedSignal("ControlsLayout"):Connect(function()
	if player:GetAttribute("ControlsLayout") ~= loadedRaw then
		HudLayout.data()
		fire()
	end
end)

return HudLayout
