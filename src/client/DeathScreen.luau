--!strict
-- Schermata di morte: la logica di rinascita continua a passare dal server (Remotes.Respawn).
-- Impaginata qui in pixel logici (UiView.fitScale): fondo scuro che copre HUD ed eventi (prima
-- si leggevano in trasparenza e confondevano), un riquadro al centro con titolo, causa, due dati
-- e un consiglio corto, e il pulsante Respawn grande in mezzo. La barra degli attrezzi si nasconde.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Shared = RS:WaitForChild("Shared")
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local Ui = require(Shared:WaitForChild("UiView"))
local player = Players.LocalPlayer
local DeathScreen = {}
local TIPS = {
	"Place pitons before hard parts: the rope catches you.",
	"Stay near fires or craft the Thermal Suit when it's cold.",
	"Rockslide warning? Move aside!",
	"Ice walls need Crampons.",
	"Base camps are respawn points.",
	"Falling into water doesn't hurt.",
}

local function setBackpack(on: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, on)
	end)
end

function DeathScreen.start()
	local gui = Ui.screen("DeathScreen")
	gui.DisplayOrder = 50 -- sopra HUD, menu, montepremi e comandi del telefono
	gui.IgnoreGuiInset = true
	local panel = Ui.node(gui, "Panel")
	local background = Ui.node(gui, "Background")
	local shade = gui:FindFirstChild("Shade") :: Frame?
	-- fondo: l'immagine solo accennata sopra un velo scuro quasi pieno
	if shade then
		shade.Size = UDim2.fromScale(1, 1)
		shade.Position = UDim2.fromScale(0, 0)
		shade.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
		shade.BackgroundTransparency = 0.04
		shade.ZIndex = 0
	end
	background.ImageTransparency = 0.7
	background.ZIndex = 1
	panel.ZIndex = 2
	local pc = panel:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 18)
	pc.Parent = panel
	local ps = panel:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	ps.Color = Color3.fromRGB(200, 50, 50)
	ps.Thickness = 3
	ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ps.Parent = panel

	local revive = panel.Revive
	local respawn = panel.Respawn
	revive.Visible = ShopConfig.DEV_PRODUCTS.Revive > 0
	respawn.Text = "Respawn"
	revive.Text = "Revive here"
	respawn.Activated:Connect(function()
		(RS.Remotes:WaitForChild("Respawn") :: RemoteEvent):FireServer()
	end)
	revive.Activated:Connect(function()
		(RS.Remotes:WaitForChild("Shop") :: RemoteFunction):InvokeServer("robux", "Revive")
	end)

	-- impaginazione: riquadro 560x360 al centro
	local P = Ui.px
	local function layout(vp: Vector2)
		Ui.fitScale(gui, vp)
		P(panel, 0.5, 0, 0.5, 0, 560, 360, 0.5, 0.5)
		panel.BackgroundColor3 = Color3.fromRGB(22, 20, 30)
		panel.BackgroundTransparency = 0.05
		P(panel.Title, 0, 0, 0, 26, 560, 64)
		Ui.text(panel.Title, 52, true)
		panel.Title.TextColor3 = Color3.fromRGB(235, 60, 60)
		panel.Title.TextXAlignment = Enum.TextXAlignment.Center
		P(panel.Cause, 0, 30, 0, 98, 500, 30)
		Ui.fit(panel.Cause, 22, 14, true)
		panel.Cause.TextXAlignment = Enum.TextXAlignment.Center
		panel.Cause.TextColor3 = Color3.fromRGB(240, 235, 225)
		P(panel.Stats, 0, 30, 0, 136, 500, 26)
		Ui.text(panel.Stats, 17, true)
		panel.Stats.TextXAlignment = Enum.TextXAlignment.Center
		panel.Stats.TextColor3 = Color3.fromRGB(255, 200, 90)
		P(panel.Tip, 0, 40, 0, 176, 480, 44)
		Ui.fit(panel.Tip, 15, 11)
		panel.Tip.TextXAlignment = Enum.TextXAlignment.Center
		panel.Tip.TextColor3 = Color3.fromRGB(170, 175, 190)
		-- pulsanti: Respawn grande in mezzo (con Revive, due affiancati)
		if revive.Visible then
			P(respawn, 0.5, -8, 1, -28, 230, 68, 1, 1)
			P(revive, 0.5, 8, 1, -28, 230, 68, 0, 1)
		else
			P(respawn, 0.5, 0, 1, -28, 320, 72, 0.5, 1)
		end
		for _, b in { respawn, revive } do
			Ui.text(b, 26, true)
			local lim = b:FindFirstChild("SizeLimit")
			if lim then
				lim:Destroy()
			end
		end
		Ui.tint(respawn, Color3.fromRGB(70, 175, 80), false)
		Ui.tint(revive, Color3.fromRGB(230, 160, 40), false)
	end
	Ui.viewportChanged(layout)

	local function show()
		local cause = player:GetAttribute("DeathCause")
		panel.Cause.Text = if type(cause) == "string" then cause else "You fell"
		local raw = player:GetAttribute("DeathStats")
		local maxY, alive = 0, 0
		if type(raw) == "string" then
			local a, b = string.match(raw, "^(%d+)|(%d+)$")
			maxY, alive = tonumber(a) or 0, tonumber(b) or 0
		end
		panel.Stats.Text = string.format("Best height %d m   ·   Time %d:%02d", maxY, alive // 60, alive % 60)
		panel.Tip.Text = "Tip: " .. TIPS[math.random(1, #TIPS)]
		gui.Enabled = true
		setBackpack(false)
		Ui.open(panel)
	end
	local function onCharacter(character: Model)
		gui.Enabled = false
		setBackpack(true)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			task.wait(0.4)
			if player.Character == character and humanoid.Health <= 0 then
				show()
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end
return DeathScreen
