--!strict

-- init.client.luau turns the parent folder into this LocalScript; UI is a child of this script.
local CameraView = require(script:WaitForChild("CameraView"))
CameraView.init()
local FishingVisual = require(script:WaitForChild("FishingVisual"))
FishingVisual.init()
local UI = require(script:WaitForChild("UI"))
UI.mount()
