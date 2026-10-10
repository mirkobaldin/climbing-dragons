--!strict
-- Comandi contestuali a ventaglio: stessi gesti del PC, area libera sotto per il salto Roblox.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Shared = RS:WaitForChild("Shared")
local Ui = require(Shared.UiView)
local Config = require(Shared.ClimbConfig)
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
	if not UIS.TouchEnabled then return end
	local actions = Ui.node(gui, "Actions")
	actions.Run.Activated:Connect(function()
		actions.Run.Text = if Sprint.toggle() then "Walk" else "Run"
	end)
	actions.Climb.Activated:Connect(function() Climbing.grabNearest() end)
	actions.JumpOff.Activated:Connect(Climbing.jumpOff)
	actions.Release.Activated:Connect(Climbing.releaseRope)
	actions.Throw.Activated:Connect(function() task.spawn(PickaxeThrow.activate) end)
	actions.Shoot.Activated:Connect(function() if TrainingFX.shoot then TrainingFX.shoot() end end)
	local function activateTool(name: string)
		local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if tool and tool.Name == name then tool:Activate() end
	end
	actions.Grapple.Activated:Connect(function() activateTool(Config.GRAPPLE_NAME) end)
	actions.Mine.Activated:Connect(function() activateTool(Config.PICKAXE_NAME) end)
	local function tap(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	actions.Piton.InputBegan:Connect(function(input) if tap(input) then Climbing.aimBegin() end end)
	actions.Piton.InputEnded:Connect(function(input) if tap(input) then Climbing.aimFinish() end end)
	local labels = {JumpOff="Jump off", Release="Unclip"}
	for name, label in labels do actions[name].Text = label end
	local vp = Vector2.new(844, 390)
	Ui.viewportChanged(function(size) vp = size end)
	local last = ""
	local function refresh()
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local climbing = ClientState.climbing
		local dragon = ClientState.dragonMode
		local available = {
			Run=not climbing and not dragon, Climb=not climbing and not dragon and Climbing.wallInReach(),
			JumpOff=climbing and not dragon, Piton=climbing and not dragon,
			Release=root ~= nil and root:FindFirstChild("BelayRope") ~= nil and not dragon,
			Grapple=tool ~= nil and tool.Name == Config.GRAPPLE_NAME and not dragon,
			Mine=tool ~= nil and tool.Name == Config.PICKAXE_NAME and not dragon and not climbing,
			Throw=tool ~= nil and tool.Name == Config.TOOL_NAME and not dragon and not climbing,
			Shoot=dragon,
		}
		local visible = {}
		for _, name in {"Run","Climb","JumpOff","Piton","Release","Grapple","Throw","Mine","Shoot"} do
			actions[name].Visible = available[name]
			if available[name] then table.insert(visible, name) end
		end
		local key = table.concat(visible, "|") .. tostring(vp)
		if key == last then return end
		last = key
		-- Un quadrato locale da 168 px mantiene almeno 44 px per bersaglio anche in orizzontale.
		actions.Position = UDim2.fromScale(1 - 178 / vp.X, .38)
		actions.Size = UDim2.fromScale(168 / vp.X, 110 / vp.Y)
		for i, name in visible do
			local button = actions[name]
			local col, row = (i-1) % 3, math.floor((i-1) / 3)
			button.Position = UDim2.fromScale(col * .34, row * .52 + (if col == 1 then 0 else .08))
			button.Size = UDim2.fromScale(.29, .45)
		end
	end
	-- Solo il controllo del contesto a 10 Hz; nessuna animazione per-frame aggiunta.
	task.spawn(function() while gui.Parent do refresh(); task.wait(.1) end end)
end
return MobileControls

