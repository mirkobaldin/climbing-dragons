--!strict
-- Crea gli eventi di rete usati da client e server (ReplicatedStorage > Remotes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = { "PlacePiton", "UpdateRope", "ReleaseRope", "GrabRock", "OpenCrafting", "Travel", "OpenDragons", "Knockback", "OpenShop", "ClimbState" }

local Remotes = {}

function Remotes.setup(): { [string]: RemoteEvent }
	local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	local events = {}
	for _, name in NAMES do
		local event = folder:FindFirstChild(name) :: RemoteEvent? or Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		events[name] = event
	end
	folder.Parent = ReplicatedStorage
	return events
end

return Remotes
