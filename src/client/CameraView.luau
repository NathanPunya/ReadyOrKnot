--!strict
-- First-person vs third-person for crosshair + cast aim.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Camera closer than this to the head counts as first person (Classic zoom “over shoulder” is still fairly close).
local FIRST_PERSON_HEAD_DISTANCE = 6.5

-- When true, cursor stays visible (e.g. dock shop modal) even in first person.
local shopModalOpen = false

local CameraView = {}

function CameraView.isFirstPerson(): boolean
	if player.CameraMode == Enum.CameraMode.LockFirstPerson then
		return true
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return false
	end
	local char = player.Character
	if not char then
		return false
	end
	local head = char:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return false
	end
	local subj = cam.CameraSubject
	if subj and subj:IsA("Humanoid") and subj.Parent ~= char then
		return false
	end
	return (cam.CFrame.Position - head.Position).Magnitude < FIRST_PERSON_HEAD_DISTANCE
end

local function shouldShowMouseCursor(): boolean
	if GuiService.MenuIsOpen then
		return true
	end
	if shopModalOpen then
		return true
	end
	if not CameraView.isFirstPerson() then
		return true
	end
	return false
end

local function applyMouseState()
	local show = shouldShowMouseCursor()
	UserInputService.MouseIconEnabled = show
	-- MouseIconEnabled alone is often not enough; LockCenter hides the system cursor for camera-look FPS.
	if show then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
end

function CameraView.setShopModalOpen(open: boolean)
	shopModalOpen = open
end

function CameraView.init()
	-- Run late so other code doesn’t override cursor state the same frame.
	RunService:BindToRenderStep("ReadyOrKnotMouseCursor", Enum.RenderPriority.Last.Value, function()
		applyMouseState()
	end)
end

return CameraView
