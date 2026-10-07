--!strict
-- Ritocchi all'interfaccia: ogni pulsante delle nostre schermate si ingrandisce un poco quando
-- ci passi sopra e si "schiaccia" quando lo premi (anche col dito sul telefono). I pulsanti
-- che hanno gia' un UIScale (quelli rimpiccioliti da UIScaler) si lasciano stare.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIPolish = {}

local ONLY = { ClimbHUD = true, MainMenu = true, Teletrasporto = true, AdminButtons = true, TargetRush = true }
local INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function polish(b: Instance)
	if not b:IsA("GuiButton") or b:FindFirstChildWhichIsA("UIScale") then
		return
	end
	local s = Instance.new("UIScale")
	s.Name = "Tocco"
	s.Parent = b
	local hover = false
	local function to(v: number)
		TweenService:Create(s, INFO, { Scale = v }):Play()
	end
	b.MouseEnter:Connect(function()
		hover = true
		to(1.06)
	end)
	b.MouseLeave:Connect(function()
		hover = false
		to(1)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.92)
	end)
	b.MouseButton1Up:Connect(function()
		to(if hover then 1.06 else 1)
	end)
	b.TouchTap:Connect(function()
		s.Scale = 0.9
		to(1)
	end)
end

local function watch(gui: Instance)
	if not gui:IsA("ScreenGui") or not ONLY[gui.Name] then
		return
	end
	-- dopo UIScaler (che mette i suoi UIScale sui pannelli in cima)
	task.defer(function()
		for _, d in gui:GetDescendants() do
			polish(d)
		end
		gui.DescendantAdded:Connect(function(d)
			task.defer(polish, d)
		end)
	end)
end

function UIPolish.start()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, g in pg:GetChildren() do
		watch(g)
	end
	pg.ChildAdded:Connect(watch)
end

return UIPolish
