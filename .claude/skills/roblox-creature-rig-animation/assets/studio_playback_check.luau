--!strict
-- Roblox Studio inspection + playback check for an imported creature (validation scenario 3).
-- STATUS: written, NOT RUN. Run in Studio's Command Bar or through the Roblox Studio MCP
-- `execute_luau` tool, in Edit mode or Play (Server) mode, after importing the rig FBX.
-- It never deletes anything. It creates an AnimationController/Animator only if CREATE_CONTROLLER = true.

local MODEL_NAME = "val_dragon_rig"      -- name of the imported Model in Workspace
local ANIMATION_ID = ""                  -- e.g. "rbxassetid://1234567890" (published clip); empty = skip playback
local CREATE_CONTROLLER = false          -- set true to insert AnimationController + Animator if missing
local SAMPLE_BONE = "DEF-wing_humerus_L" -- bone sampled during playback to prove motion

local report: {[string]: any} = {}
local model = workspace:FindFirstChild(MODEL_NAME)
if not model then
	warn("Model not found in Workspace: " .. MODEL_NAME)
	return
end

local meshParts, bones, surfaceAppearances = {}, {}, 0
for _, d in model:GetDescendants() do
	if d:IsA("MeshPart") then
		table.insert(meshParts, string.format("%s size=(%.2f, %.2f, %.2f)", d.Name, d.Size.X, d.Size.Y, d.Size.Z))
		if d:FindFirstChildOfClass("SurfaceAppearance") then
			surfaceAppearances += 1
		end
	elseif d:IsA("Bone") then
		table.insert(bones, d.Name)
	end
end
report.meshParts = meshParts
report.boneCount = #bones
report.surfaceAppearances = surfaceAppearances
local okBbox, cf, size = pcall(function() return model:GetBoundingBox() end)
if okBbox then
	report.boundingBoxStuds = string.format("%.2f x %.2f x %.2f", size.X, size.Y, size.Z)
	report.lookVector = tostring(cf.LookVector)
end

local controller = model:FindFirstChildOfClass("AnimationController") or model:FindFirstChildOfClass("Humanoid")
if not controller and CREATE_CONTROLLER then
	controller = Instance.new("AnimationController")
	controller.Parent = model
end
local animator = controller and controller:FindFirstChildOfClass("Animator")
if controller and not animator and CREATE_CONTROLLER then
	animator = Instance.new("Animator")
	animator.Parent = controller
end
report.controller = controller and controller.ClassName or "none"
report.animator = animator ~= nil

if ANIMATION_ID ~= "" and animator then
	local anim = Instance.new("Animation")
	anim.AnimationId = ANIMATION_ID
	local track = (animator :: Animator):LoadAnimation(anim)
	track:Play()
	local bone = model:FindFirstChild(SAMPLE_BONE, true) :: Bone?
	local samples = {}
	for i = 1, 5 do
		task.wait(0.2)
		if bone then
			local p = bone.TransformedWorldCFrame.Position
			table.insert(samples, string.format("%.3f,%.3f,%.3f", p.X, p.Y, p.Z))
		end
	end
	report.trackLength = track.Length
	report.isPlaying = track.IsPlaying
	report.looped = track.Looped
	report.boneSamples = samples
	track:Stop()
end

for k, v in report do
	if typeof(v) == "table" then
		print(k, "=", table.concat(v :: {string}, " | "))
	else
		print(k, "=", v)
	end
end
