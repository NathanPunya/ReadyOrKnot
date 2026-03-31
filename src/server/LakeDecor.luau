--!strict
-- Lily pads, shore reeds, and simple autumn trees around the lake (reference: calm water + treeline).
-- Parts only — no custom meshes required.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type LakeInfo = {
	center: Vector3,
	waterRadius: number,
	carveRadius: number,
	plainTopY: number,
}

local FOLDER_NAME = "ReadyOrKnotLakeDecor"

local function destroyOld()
	local old = Workspace:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
end

local function lilyPadY(): number
	return Config.LAKE_WATER_SURFACE_Y + 0.06
end

-- Uniform random point in annulus (rMin, rMax) in XZ.
local function randomAnnulus(cx: number, cz: number, rMin: number, rMax: number): (number, number)
	local t = math.random() * math.pi * 2
	local u = math.random()
	local rad = math.sqrt(u) * (rMax - rMin) + rMin
	return cx + math.cos(t) * rad, cz + math.sin(t) * rad
end

local function addLilyPads(folder: Folder, cx: number, cz: number, waterR: number)
	local y = lilyPadY()
	local inner = math.max(18, waterR * 0.12)
	local outer = waterR - 10
	for _ = 1, 110 do
		local px, pz = randomAnnulus(cx, cz, inner, outer)
		local pad = Instance.new("Part")
		pad.Name = "LilyPad"
		pad.Shape = Enum.PartType.Cylinder
		pad.Size = Vector3.new(0.12, 1.2 + math.random() * 1.4, 1.2 + math.random() * 1.4)
		pad.CFrame = CFrame.new(px, y, pz) * CFrame.Angles(0, math.random() * math.pi * 2, math.rad(90))
		pad.Material = Enum.Material.Grass
		local g = 95 + math.random(0, 35)
		pad.Color = Color3.fromRGB(g, 120 + math.random(0, 40), 55 + math.random(0, 25))
		pad.Anchored = true
		pad.CanCollide = false
		pad.CastShadow = true
		pad.Transparency = 0.08
		pad.Parent = folder
	end
end

local function addReeds(folder: Folder, cx: number, cz: number, waterR: number, plainTopY: number)
	for _ = 1, 55 do
		local t = math.random() * math.pi * 2
		local rad = waterR + 1.5 + math.random() * 5
		local px = cx + math.cos(t) * rad
		local pz = cz + math.sin(t) * rad
		local h = 3.5 + math.random() * 4
		local reed = Instance.new("Part")
		reed.Name = "Reed"
		reed.Size = Vector3.new(0.22, h, 0.22)
		reed.CFrame = CFrame.new(px, plainTopY + h * 0.5, pz)
		reed.Material = Enum.Material.Grass
		reed.Color = Color3.fromRGB(78 + math.random(0, 30), 110 + math.random(0, 40), 48)
		reed.Anchored = true
		reed.CanCollide = false
		reed.Parent = folder
	end
end

local function buildTreeParts(model: Model, baseCf: CFrame)
	local trunkH = 6 + math.random() * 5
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(1.05, trunkH, 1.05)
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(72, 48, 34)
	trunk.Anchored = true
	trunk.CFrame = baseCf * CFrame.new(0, trunkH * 0.5, 0)
	trunk.Parent = model

	local palette = {
		Color3.fromRGB(210, 95, 38),
		Color3.fromRGB(225, 150, 42),
		Color3.fromRGB(190, 58, 42),
		Color3.fromRGB(100, 130, 52),
		Color3.fromRGB(215, 175, 48),
	}
	for _ = 1, 4 do
		local leaf = Instance.new("Part")
		leaf.Name = "Leaves"
		leaf.Shape = Enum.PartType.Ball
		local s = 4 + math.random() * 3
		leaf.Size = Vector3.new(s, s, s)
		leaf.Material = Enum.Material.Grass
		leaf.Color = palette[math.random(1, #palette)]
		leaf.Anchored = true
		local ox = (math.random() - 0.5) * 3
		local oz = (math.random() - 0.5) * 3
		local oy = trunkH + 1.5 + math.random() * 2.5
		leaf.CFrame = baseCf * CFrame.new(ox, oy, oz)
		leaf.Parent = model
	end
end

local function addTrees(folder: Folder, cx: number, cz: number, waterR: number, plainTopY: number)
	-- Treeline outside the water; skip a sector toward -Z where the dock/spawn sit.
	local r0 = waterR + 22
	local r1 = waterR + 58
	local dockDir = Vector3.new(0, 0, -1)
	local count = 0
	local attempts = 0
	while count < 48 and attempts < 260 do
		attempts += 1
		local t = math.random() * math.pi * 2
		local rad = r0 + math.random() * (r1 - r0)
		local px = cx + math.cos(t) * rad
		local pz = cz + math.sin(t) * rad
		local flat = Vector3.new(px - cx, 0, pz - cz)
		if flat.Magnitude >= 8 then
			local dir = flat.Unit
			if dockDir:Dot(dir) <= 0.78 then
				local tree = Instance.new("Model")
				tree.Name = "AutumnTree_" .. tostring(count)
				tree.Parent = folder
				local yaw = math.random() * 6.28
				buildTreeParts(tree, CFrame.new(px, plainTopY, pz) * CFrame.Angles(0, yaw, 0))
				count += 1
			end
		end
	end
end

local function addUnderwaterLog(folder: Folder, cx: number, cz: number, waterR: number)
	local px = cx + waterR * 0.35
	local pz = cz - waterR * 0.2
	local log = Instance.new("Part")
	log.Name = "SubmergedLog"
	log.Shape = Enum.PartType.Cylinder
	log.Size = Vector3.new(2.2, 14, 2.2)
	log.CFrame = CFrame.new(px, Config.LAKE_WATER_SURFACE_Y - 5, pz) * CFrame.Angles(0, math.rad(22), math.rad(88))
	log.Material = Enum.Material.Wood
	log.Color = Color3.fromRGB(58, 44, 32)
	log.Anchored = true
	log.CanCollide = false
	log.Transparency = 0.35
	log.Parent = folder
end

local LakeDecor = {}

function LakeDecor.build(lake: LakeInfo)
	destroyOld()

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	local cx, cz = lake.center.X, lake.center.Z
	local waterR = lake.waterRadius
	local plainTopY = lake.plainTopY

	addLilyPads(folder, cx, cz, waterR)
	addReeds(folder, cx, cz, waterR, plainTopY)
	addTrees(folder, cx, cz, waterR, plainTopY)
	addUnderwaterLog(folder, cx, cz, waterR)
end

return LakeDecor
