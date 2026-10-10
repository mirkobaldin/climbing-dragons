--!strict
-- Comandi contestuali a ventaglio: stessi gesti del PC, area libera sotto per il salto Roblox.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Shared = RS:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("UiView"))
local Config = require(Shared:WaitForChild("ClimbConfig"))
local Climbing = require(script.Parent.Climbing)
local ClientState = require(script.Parent.ClientState)
local Sprint = require(script.Parent.Sprint)
local PickaxeThrow = require(script.Parent.PickaxeThrow)
local TrainingFX = require(script.Parent.TrainingFX)
local player = Players.LocalPlayer
local MobileControls = {}
function MobileControls.start()
	local gui = Ui.screen("MobileControls")
	gui.Enabled = UIS.TouchEnabled
	if not UIS.TouchEnabled then
		return
	end
	local actions = Ui.node(gui, "Actions")
	actions.Run.Activated:Connect(function()
		actions.Run.Text = if Sprint.toggle() then "Walk" else "Run"
	end)
	actions.Climb.Activated:Connect(function()
		Climbing.grabNearest()
	end)
	actions.JumpOff.Activated:Connect(Climbing.jumpOff)
	actions.Release.Activated:Connect(Climbing.releaseRope)
	actions.Throw.Activated:Connect(function()
		task.spawn(PickaxeThrow.activate)
	end)
	actions.Shoot.Activated:Connect(function()
		if TrainingFX.shoot then
			TrainingFX.shoot()
		end
	end)
	local function activateTool(name: string)
		local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if tool and tool.Name == name then
			tool:Activate()
		end
	end
	actions.Grapple.Activated:Connect(function()
		activateTool(Config.GRAPPLE_NAME)
	end)
	actions.Mine.Activated:Connect(function()
		activateTool(Config.PICKAXE_NAME)
	end)
	local function tap(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	actions.Piton.InputBegan:Connect(function(input)
		if tap(input) then
			Climbing.aimBegin()
		end
	end)
	actions.Piton.InputEnded:Connect(function(input)
		if tap(input) then
			Climbing.aimFinish()
		end
	end)
	local labels = { JumpOff = "Jump", Release = "Unclip", Grapple = "Hook" }
	for name, label in labels do
		actions[name].Text = label
	end
	local vp = Vector2.new(844, 390)
	Ui.viewportChanged(function(size)
		vp = size
	end)
	local last = ""
	local function refresh()
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local climbing = ClientState.climbing
		local dragon = ClientState.dragonMode
		local available = {
			Run = not climbing and not dragon,
			Climb = not climbing and not dragon and Climbing.wallInReach(),
			JumpOff = climbing and not dragon,
			Piton = climbing and not dragon,
			Release = root ~= nil and root:FindFirstChild("BelayRope") ~= nil and not dragon,
			Grapple = tool ~= nil and tool.Name == Config.GRAPPLE_NAME and not dragon,
			Mine = tool ~= nil and tool.Name == Config.PICKAXE_NAME and not dragon and not climbing,
			Throw = tool ~= nil and tool.Name == Config.TOOL_NAME and not dragon and not climbing,
			Shoot = dragon,
		}
		local visible = {}
		for _, name in { "Run", "Climb", "JumpOff", "Piton", "Release", "Grapple", "Throw", "Mine", "Shoot" } do
			actions[name].Visible = available[name]
			if available[name] then
				table.insert(visible, name)
			end
		end
		local key = table.concat(visible, "|") .. tostring(vp)
		if key == last then
			return
		end
		last = key
		-- Su schermi bassi il ventaglio usa una sola riga, sopra i 160 px riservati al salto.
		local portrait = vp.X < vp.Y
		actions.Position =
			UDim2.fromScale(1 - (if portrait then 178 else 222) / vp.X, if portrait then 0.64 else (vp.Y - 224) / vp.Y)
		actions.Size = UDim2.fromScale((if portrait then 168 else 212) / vp.X, (if portrait then 110 else 54) / vp.Y)
		for i, name in visible do
			local button = actions[name]
			if portrait then
				local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
				button.Position = UDim2.fromScale(col * 0.34, row * 0.52 + (if col == 1 then 0 else 0.08))
				button.Size = UDim2.fromScale(0.29, 0.45)
			else
				button.Position = UDim2.fromScale((i - 1) * 0.25, if i == 1 or i == 4 then 0.1 else 0)
				button.Size = UDim2.fromScale(0.22, 0.9)
			end
		end
	end
	-- Solo il controllo del contesto a 10 Hz; nessuna animazione per-frame aggiunta.
	task.spawn(function()
		while gui.Parent do
			refresh()
			task.wait(0.1)
		end
	end)
end
return MobileControls
