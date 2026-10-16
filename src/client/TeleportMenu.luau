--!strict
-- Il vecchio pannello "Teletrasporto" (StarterGui) e' stato sostituito dalla pagina Travel del
-- menu unico (client/TravelUI, tasto T in client/MainMenu): qui resta solo spento, perche'
-- altri script (HUD, Montepremi, MobileControls) ne controllano ancora la visibilita'.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Ui = require(RS:WaitForChild("Shared").UiView)
local player = Players.LocalPlayer
local TeleportMenu = {}

function TeleportMenu.start()
	local gui = Ui.screen("Teletrasporto")
	for _, name in { "Panel", "Open" } do
		local o = gui:FindFirstChild(name)
		if o and o:IsA("GuiObject") then
			o.Visible = false
		end
	end
	local _ = player
end

return TeleportMenu
