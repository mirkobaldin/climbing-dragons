--!strict
-- Destinazioni e requisiti mostrati dal client; autorizzazione e spostamento restano sul server.
local CAS = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Ui = require(RS:WaitForChild("Shared").UiView)
local player = Players.LocalPlayer
local TeleportMenu = {}
local NAMES = { "Base camp (hub)", "My camp", "Dragon training", "Muscle Beach (gym)" }
local function destination(index: number): Vector3?
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
	local function refresh()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for i, name in NAMES do
			local b = panel["Destination" .. i]
			local locked = i == 3 and ((player:GetAttribute("DragonCount") or 0) :: number) < 1
			b.Title.Text = name .. (if locked then "\nFirst dragon required" else "")
			Ui.asset(b.Icon, if locked then "icon_lock" else "icon_teleport")
			local pos = destination(i)
			b.Distance.Text = if root and pos
				then string.format("%d m", math.floor((root.Position - pos).Magnitude))
				else ""
		end
	end
	for i, name in NAMES do
		panel["Destination" .. i].Activated:Connect(function()
			panel.Visible = false
			(remote :: RemoteEvent):FireServer(name)
		end)
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
	for _, attr in { "DragonCount", "HouseLevel", "PlotPosition", "PlotSpawn" } do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	Ui.viewportChanged(function(vp)
		panel.Position = UDim2.fromScale(if vp.X < vp.Y then 0.04 else 0.2, 0.1)
		panel.Size = UDim2.fromScale(if vp.X < vp.Y then 0.92 else 0.65, 0.8)
	end)
	refresh()
end
return TeleportMenu
