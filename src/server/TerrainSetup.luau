--!strict
-- Grassy plain + flat circular lake using Terrain:FillCylinder (short cylinder = flat disk, not a sphere).

local Workspace = game:GetService("Workspace")

export type LakeInfo = {
	center: Vector3,
	waterRadius: number,
	carveRadius: number,
	plainTopY: number,
}

local TerrainSetup = {}

function TerrainSetup.build(): LakeInfo
	local terrain = Workspace.Terrain

	local lakeX = 168
	local lakeZ = 102
	-- Circle: carve radius slightly larger than water so the shore is grass → sand/rock → water.
	local carveRadius = 138
	local waterRadius = 126

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

	-- Flat circular floor layers (thin cylinders — reads as a pond bottom, not a column).
	terrain:FillCylinder(CFrame.new(lakeX, -10, lakeZ), 12, carveRadius - 5, Enum.Material.Rock)
	terrain:FillCylinder(CFrame.new(lakeX, -3.5, lakeZ), 8, carveRadius - 8, Enum.Material.Sand)
	-- Shallow water disk (small height = flat surface).
	terrain:FillCylinder(CFrame.new(lakeX, 4.5, lakeZ), 9, waterRadius, Enum.Material.Water)

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
