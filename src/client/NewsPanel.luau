--!strict
-- Pannello WHAT'S NEW (Mirko 17/10: al posto del ritratto del giocatore nell'HUD un tasto delle
-- notizie). Elenco da shared/Novita; si apre dal tasto dell'HUD e da solo una volta quando c'e'
-- un aggiornamento nuovo (non durante il tutorial). Stile UiKit: pannello con la cornice di Codex.
--   NewsPanel.open()      apre il pannello e segna le novita' come viste
--   NewsPanel.unread()    true se c'e' una versione che il giocatore non ha visto
--   NewsPanel.onSeen(fn)  il tasto dell'HUD spegne il pallino rosso
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("UiView"))
local Novita = require(Shared:WaitForChild("Novita"))
local UiKit = require(script.Parent.UiKit)
local HudLayout = require(script.Parent.HudLayout)

local player = Players.LocalPlayer
local NewsPanel = {}

local gui: ScreenGui? = nil
local seenHooks: { () -> () } = {}

local function seenVersion(): number
	local v = HudLayout.data().Novita
	return if type(v) == "number" then v else 0
end

function NewsPanel.unread(): boolean
	return Novita.latest() > seenVersion()
end

function NewsPanel.onSeen(fn: () -> ())
	table.insert(seenHooks, fn)
end

local function build(): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = "Notizie"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = false
	g.DisplayOrder = 40
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Enabled = false
	g.Parent = player:WaitForChild("PlayerGui")
	local veil = Instance.new("TextButton") -- tocco fuori dal pannello = chiudi
	veil.Name = "Velo"
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0.45
	veil.Size = UDim2.fromScale(1, 1)
	veil.Parent = g
	local panel = Instance.new("Frame")
	panel.Name = "Pannello"
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Active = true
	panel.ZIndex = 2
	panel.Parent = g
	UiKit.panel(panel, { border = 12 })
	local title = UiKit.label(panel, "WHAT'S NEW", "title", 30)
	title.TextColor3 = UiKit.ACCENT
	title.Position = UDim2.fromOffset(28, 18)
	title.Size = UDim2.new(1, -170, 0, 40)
	title.ZIndex = 3
	local close = Instance.new("TextButton")
	close.Name = "Chiudi"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -22, 0, 18)
	close.Size = UDim2.fromOffset(110, 42)
	close.ZIndex = 4
	close.Parent = panel
	UiKit.button(close, "secondary")
	close.Text = "CLOSE"
	local list = Instance.new("ScrollingFrame")
	list.Name = "Elenco"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(28, 72)
	list.Size = UDim2.new(1, -56, 1, -94)
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = UiKit.LINE
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 3
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local order = 0
	local function add(text: string, kind: any, size: number?, color: Color3?)
		order += 1
		local l = UiKit.label(list, text, kind, size)
		l.LayoutOrder = order
		l.TextWrapped = true
		l.TextTruncate = Enum.TextTruncate.None
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Size = UDim2.new(1, -8, 0, 0)
		l.ZIndex = 4
		if color then
			l.TextColor3 = color
		end
	end
	for i, e in Novita.LIST do
		if i > 1 then
			add(" ", "secondary", 8)
		end
		add(string.upper(e.title), "name", 22, if i == 1 then UiKit.TEXT else UiKit.MUTED)
		add(e.date, "status", 13, UiKit.ACCENT)
		for _, line in e.lines do
			add("◆  " .. line, "body", 16)
		end
	end
	local function hide()
		g.Enabled = false
	end
	close.Activated:Connect(hide)
	veil.Activated:Connect(hide)
	Ui.viewportChanged(function(vp)
		local logical = Ui.fitScale(g, vp)
		panel.Size = UDim2.fromOffset(math.min(620, logical.X - 40), math.min(460, logical.Y - 40))
	end, g)
	return g
end

function NewsPanel.open()
	if not gui then
		gui = build()
	end
	(gui :: ScreenGui).Enabled = true
	if NewsPanel.unread() then
		HudLayout.data().Novita = Novita.latest()
		HudLayout.save()
	end
	for _, fn in seenHooks do
		task.spawn(fn)
	end
end

-- all'ingresso: se c'e' un aggiornamento non visto il pannello si apre da solo una volta (dopo
-- che ControlsLayout e' arrivato dal server; mai durante il tutorial, li' basta il pallino)
function NewsPanel.start()
	task.delay(8, function()
		if NewsPanel.unread() and type(player:GetAttribute("TutorialText")) ~= "string" then
			NewsPanel.open()
		end
	end)
end

return NewsPanel
