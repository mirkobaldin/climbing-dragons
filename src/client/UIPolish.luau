--!strict
-- Pressione leggera e stati delle immagini, senza cicli per-frame.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Ui = require(RS:WaitForChild("Shared").UiView)
local UIPolish = {}
local ONLY = {
	ClimbHUD = true,
	MainMenu = true,
	Teletrasporto = true,
	DeathScreen = true,
	MobileControls = true,
	CombatHUD = true,
	Caricamento = true,
}
local bound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function polish(b: Instance)
	if not b:IsA("GuiButton") or bound[b] then
		return
	end
	-- Le copie dei modelli ricevono le proprie connessioni dopo la clonazione.
	if b:FindFirstAncestor("Templates") then
		return
	end
	bound[b] = true
	local hover, pressed = false, false
	local position = b.Position
	local moving = false
	local generation = 0
	local tween: Tween? = nil
	local key = b:GetAttribute("UiAsset")
	local base = if type(key) == "string" then string.gsub(key, "_normal$", "") else ""
	local function update()
		key = b:GetAttribute("UiAsset")
		base = if type(key) == "string" then key:gsub("_normal$", ""):gsub("_hover$", ""):gsub("_pressed$", "") else ""
		if b:GetAttribute("UiDisabled") then hover, pressed = false, false end
		generation += 1
		local version = generation
		if tween then
			tween:Cancel()
		end
		-- (niente piu' spostamento di 2 px alla pressione: se intanto l'impaginazione spostava il
		-- pulsante, il tween lo rimetteva nel posto vecchio e restava storto)
		local _ = version
		if base ~= "" and base ~= key then
			Ui.skin(b, base .. (if pressed then "_pressed" elseif hover then "_hover" else "_normal"))
		end
	end
	b:GetPropertyChangedSignal("Position"):Connect(function()
		if not moving then
			position = b.Position
		end
	end)
	-- L'offset di pressione e' l'unica misura in pixel: non cambia l'area di tocco minima.
	b.MouseEnter:Connect(function()
		hover = true
		update()
	end)
	b.MouseLeave:Connect(function()
		hover = false
		pressed = false
		update()
	end)
	b.MouseButton1Down:Connect(function()
		if not pressed then
			position = b.Position
		end
		pressed = true
		update()
	end)
	b.MouseButton1Up:Connect(function()
		pressed = false
		update()
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			pressed = false
			update()
		end
	end)
	b.Destroying:Connect(function()
		if tween then
			tween:Cancel()
		end
	end)
end
local function watch(gui: Instance)
	if not gui:IsA("ScreenGui") or not ONLY[gui.Name] then
		return
	end
	for _, d in gui:GetDescendants() do
		polish(d)
	end
	gui.DescendantAdded:Connect(function(d)
		task.defer(polish, d)
	end)
end
function UIPolish.start()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, gui in pg:GetChildren() do
		watch(gui)
	end
	pg.ChildAdded:Connect(watch)
end
return UIPolish
