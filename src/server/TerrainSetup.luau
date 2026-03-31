--!strict
-- Grassy plain + flat circular lake using Terrain:FillCylinder (short cylinder = flat disk, not a sphere).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type LakeInfo = {
	center: Vector3,
	waterRadius: number,
	carveRadius: number,
	plainTopY: number,
}

local TerrainSetup = {}

function TerrainSetup.build(): LakeInfo
	local terrain = Workspace.Terrain

	-- Same XZ as `Config.LAKE_CENTER_*` (client fishing UI proximity uses those values).
	local lakeX = Config.LAKE_CENTER_X
	local lakeZ = Config.LAKE_CENTER_Z
	-- Circle: keep rock/sand/water radii close to the carve so there’s no empty “moat” between land and water.
	local carveRadius = 152
	local waterRadius = 150

	local plainSize = 920
	local plainHeight = 16
	local plainY = 8
	local plainTopY = plainY + plainHeight * 0.5

	local lakeCenter = Vector3.new(lakeX, plainY, lakeZ)

	-- Reset working volume between Play sessions.
	local clearExtent = 520
	terrain:FillBlock(CFrame.new(0, 20, 0), Vector3.new(clearExtent * 2, 200, clearExtent * 2), Enum.Material.Air)

	terrain:FillBlock(CFrame.new(0, plainY, 0), Vector3.new(plainSize, plainHeight, plainSize), Enum.Material.Grass)

	-- Vertical cylinders: axis is CFrame.Y (default). Tall Air = circular cut through the grass.
	terrain:FillCylinder(CFrame.new(lakeX, 2, lakeZ), 34, carveRadius, Enum.Material.Air)

	-- Flat circular floor layers — radii nearly match the hole so the shore meets the grass.
	terrain:FillCylinder(CFrame.new(lakeX, -10, lakeZ), 12, carveRadius - 2, Enum.Material.Rock)
	terrain:FillCylinder(CFrame.new(lakeX, -3.5, lakeZ), 8, carveRadius - 1, Enum.Material.Sand)
	-- Shallow sand shelf (extra layer) so the slope toward the wet shore isn’t one flat tone.
	local sandShelfRadius = math.min(carveRadius - 2, waterRadius + 9)
	terrain:FillCylinder(CFrame.new(lakeX, -0.5, lakeZ), 9, sandShelfRadius, Enum.Material.Sand)

	--[[ Water column
	    API: Terrain:FillCylinder(cframe, height, radius, material)  — height FIRST, then radius.
	    If you swap them, ~147 is used as HEIGHT → giant vertical pillar and broken terrain.
	    Never use waterRadius as the CFrame Y (that would center the lake hundreds of studs up).

	    Anchor the bottom of the water to the lake bed; only the top moves when you raise waterHeight.
	]]
	local waterBottomY = 1
	local waterHeight = 14
	local maxWaterSurfaceY = plainTopY + 0.5
	local waterSurfaceY = waterBottomY + waterHeight
	if waterSurfaceY > maxWaterSurfaceY then
		waterHeight = math.max(4, maxWaterSurfaceY - waterBottomY)
		waterSurfaceY = waterBottomY + waterHeight
	end
	local waterCenterY = waterBottomY + waterHeight * 0.5

	-- Open water only here. Do not stack Mud then Water: on many builds the mud voxels stay on top and hide water.
	-- Shore band = the wider sand layers above + rock/sand bed; wet edge is sand meeting water.
	terrain:FillCylinder(CFrame.new(lakeX, waterCenterY, lakeZ), waterHeight, waterRadius, Enum.Material.Water)

	pcall(function()
		local anyTerrain = terrain :: any
		if anyTerrain.GrassLength ~= nil then
			anyTerrain.GrassLength = 0.95
		end
	end)

	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 17
	lighting.GeographicLatitude = 15
	lighting.Ambient = Color3.fromRGB(130, 148, 125)
	lighting.OutdoorAmbient = Color3.fromRGB(118, 136, 112)
	lighting.Brightness = 2.15
	lighting.EnvironmentDiffuseScale = 0.48
	lighting.EnvironmentSpecularScale = 0.58

	local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = lighting
	end
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(175, 210, 225)
	atmosphere.Decay = Color3.fromRGB(135, 165, 185)
	atmosphere.Glare = 0.16
	atmosphere.Haze = 0.6

	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") and child.Name == "DockSpawn" then
			child:Destroy()
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "DockSpawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(42, plainTopY + 2, -118) * CFrame.Angles(0, math.rad(55), 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TeamColor = BrickColor.new("Bright blue")
	spawn.Transparency = 1
	spawn.Parent = Workspace

	return {
		center = lakeCenter,
		waterRadius = waterRadius,
		carveRadius = carveRadius,
		plainTopY = plainTopY,
	}
end

return TerrainSetup
