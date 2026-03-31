--!strict
-- Grassy plain + flat circular lake using Terrain:FillCylinder (short cylinder = flat disk, not a sphere).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PhotorealLighting = require(script.Parent:WaitForChild("PhotorealLighting"))

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

	-- Do not add a full-radius surface Sand disk before Water: overlapping Sand voxels are not reliably replaced
	-- by Water, so the lake can end up all sand. Shore tone comes from the deeper sand/rock fills + reeds in `LakeDecor`.

	-- Open water only here. Do not stack Mud then Water: on many builds the mud voxels stay on top and hide water.
	-- Shore band = the wider sand layers above + rock/sand bed; wet edge is sand meeting water.
	terrain:FillCylinder(CFrame.new(lakeX, waterCenterY, lakeZ), waterHeight, waterRadius, Enum.Material.Water)

	pcall(function()
		local tr = terrain :: any
		if tr.WaterWaveSpeed ~= nil then
			tr.WaterWaveSpeed = 2.8
		end
		if tr.WaterReflectance ~= nil then
			tr.WaterReflectance = 0.42
		end
	end)

	-- `Terrain.GrassLength` is documented but often ineffective from server scripts / varies by session.
	-- For reliably “short” grass from code: turn off 3D blades (flat Grass material). For tall blades + length,
	-- enable Decoration in Studio (Home → Terrain) and set grass length there.
	pcall(function()
		local anyTerrain = terrain :: any
		if anyTerrain.Decoration ~= nil then
			anyTerrain.Decoration = false
		end
	end)

	PhotorealLighting.apply()

	-- Player spawn is built in `WorldBuild` (dock landing + invisible SpawnLocation).

	return {
		center = lakeCenter,
		waterRadius = waterRadius,
		carveRadius = carveRadius,
		plainTopY = plainTopY,
	}
end

return TerrainSetup
