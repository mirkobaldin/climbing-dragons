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
local Theme = require(script.Parent.Theme)
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
		local hud = player.PlayerGui:FindFirstChild("ClimbHUD")
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, on and not (hud and hud:GetAttribute("CustomToolBar")))
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
		shade.BackgroundColor3 = Theme.CARD
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
	ps.Color = Theme.BAD
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
		local logical = Ui.fitScale(gui, vp)
  local width, height = math.min(560, logical.X - 24), math.min(360, logical.Y - 24)
  P(panel, 0.5, 0, 0.5, 0, width, height, 0.5, 0.5)
  local limit = panel:FindFirstChildOfClass("UISizeConstraint")
  if limit then limit:Destroy() end
  panel.BackgroundColor3 = Theme.PANEL
  panel.BackgroundTransparency = 0
  P(panel.Title, 0, 12, 0, 12, width - 24, 58)
  P(panel.Cause, 0, 18, 0, 76, width - 36, 32)
  P(panel.Stats, 0, 18, 0, 112, width - 36, 32)
  P(panel.Tip, 0, 18, 0, 150, width - 36, 60)
  Theme.fitText(panel.Title, 44, false)
  Theme.fitText(panel.Cause, 22, false)
  Theme.fitText(panel.Stats, 17, false)
  Theme.fitText(panel.Tip, 16, true)
  for _, label in {panel.Title, panel.Cause, panel.Stats, panel.Tip} do
   label.TextXAlignment = Enum.TextXAlignment.Center
   label.TextColor3 = Theme.TEXT
  end
  if revive.Visible then
   P(respawn, 0, 12, 1, -12, (width - 32) / 2, 56, 0, 1)
   P(revive, 1, -12, 1, -12, (width - 32) / 2, 56, 1, 1)
  else
   P(respawn, 0.5, 0, 1, -12, math.min(320, width - 24), 56, 0.5, 1)
  end
  Theme.action(respawn, "buy")
  Theme.action(revive, "main")
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
