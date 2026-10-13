--!strict
-- Interfaccia piu' piccola sugli schermi piccoli (telefono): ogni pannello in cima a ogni
-- ScreenGui riceve un UIScale che lo rimpicciolisce attorno al suo punto di ancoraggio, cosi'
-- quelli negli angoli restano negli angoli. Si saltano gli schermi interi (trailer, cinematica,
-- morte, comandi touch) e i pannelli grandi quanto lo schermo.

local Players = game:GetService("Players")

local UIScaler = {}

-- solo le nostre interfacce: sulla chat di Roblox il UIScale mandava in loop il ridimensionamento
-- HUD, menu, pulsanti admin e speciale si adattano da soli (UiView.fitScale): qui
-- rimpicciolivano una seconda volta e sul telefono tutto finiva storto e minuscolo
local ONLY = { Teletrasporto = true, AdminBar = true, TargetRush = true, NomeZona = true, Mirino = true }
local scales: { UIScale } = {}

local function factor(): number
	local vp = workspace.CurrentCamera.ViewportSize
	-- 1 da 1100x620 in su; un telefono in orizzontale (circa 800x370) scende a ~0.6
	return math.clamp(math.min(vp.X / 1100, vp.Y / 620), 0.55, 1)
end

local function attach(obj: Instance)
	if not obj:IsA("GuiObject") or obj:FindFirstChildWhichIsA("UIScale") then
		return
	end
	local size = obj.Size
	if size.X.Scale >= 0.9 and size.Y.Scale >= 0.9 then
		return -- a schermo intero
	end
	local s = Instance.new("UIScale")
	s.Name = "AutoScale"
	s.Scale = factor()
	s.Parent = obj
	table.insert(scales, s)
end

local function watch(gui: Instance)
	if not gui:IsA("ScreenGui") or not ONLY[gui.Name] or gui:GetAttribute("ResponsiveUI") then
		return
	end
	for _, c in gui:GetChildren() do
		attach(c)
	end
	gui.ChildAdded:Connect(attach)
end

function UIScaler.start()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, g in pg:GetChildren() do
		watch(g)
	end
	pg.ChildAdded:Connect(watch)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local f = factor()
		for _, s in scales do
			s.Scale = f
		end
	end)
end

return UIScaler
