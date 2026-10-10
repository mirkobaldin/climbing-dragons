--!strict
-- Schermata persistente: la logica di rinascita continua a passare dal server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local ShopConfig = require(Shared.ShopConfig)
local Ui = require(Shared.UiView)
local player = Players.LocalPlayer
local DeathScreen = {}
local TIPS = {
	"Place a piton (F) before long stretches: the rope catches you if you fall.",
	"Stay near fires or craft the Thermal Suit when it gets cold.",
	"When you hear a rockslide warning, move aside!",
	"Ice walls need Crampons.",
	"Base camps are respawn points: camp when you find one.",
	"Falling into water doesn't hurt.",
}
function DeathScreen.start()
	local gui = Ui.screen("DeathScreen")
	local panel = Ui.node(gui, "Panel")
	local background = Ui.node(gui, "Background")
	background.ImageTransparency = .35
	panel.Revive.Visible = ShopConfig.DEV_PRODUCTS.Revive > 0
	panel.Respawn.Activated:Connect(function() (RS.Remotes:WaitForChild("Respawn") :: RemoteEvent):FireServer() end)
	panel.Revive.Activated:Connect(function() (RS.Remotes:WaitForChild("Shop") :: RemoteFunction):InvokeServer("robux", "Revive") end)
	local function show()
		local cause = player:GetAttribute("DeathCause")
		panel.Cause.Text = if type(cause) == "string" then cause else "Unknown cause"
		local raw = player:GetAttribute("DeathStats")
		local maxY, alive = 0, 0
		if type(raw) == "string" then
			local a, b = string.match(raw, "^(%d+)|(%d+)$")
			maxY, alive = tonumber(a) or 0, tonumber(b) or 0
		end
		panel.Stats.Text = string.format("Highest point %d m · Survived %d:%02d", maxY, alive // 60, alive % 60)
		panel.Tip.Text = TIPS[math.random(1, #TIPS)]
		gui.Enabled = true
		Ui.open(panel)
	end
	local function onCharacter(character: Model)
		gui.Enabled = false
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			task.wait(.4)
			if player.Character == character and humanoid.Health <= 0 then show() end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
return DeathScreen

