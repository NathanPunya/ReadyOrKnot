--!strict
-- Shack, dock, and shop ProximityPrompt (opens UI via RemoteEvent).

local Workspace = game:GetService("Workspace")

export type LakeInfo = {
	center: Vector3,
	waterRadius: number,
	carveRadius: number,
	plainTopY: number,
}

local wood = Enum.Material.Wood
local woodColor = Color3.fromRGB(133, 92, 58)
local roofColor = Color3.fromRGB(88, 58, 38)
local dockWood = Color3.fromRGB(120, 82, 52)

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	parent: Instance,
	color: Color3?,
	mat: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = true
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Color = color or Color3.fromRGB(200, 200, 200)
	p.Parent = parent
	return p
end

local WorldBuild = {}

function WorldBuild.build(lake: LakeInfo, openShop: RemoteEvent)
	local old = Workspace:FindFirstChild("ReadyOrKnotWorld")
	if old then
		old:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "ReadyOrKnotWorld"
	root.Parent = Workspace

	local c = lake.center
	local r = lake.waterRadius
	local topY = lake.plainTopY

	-- Dock on the north side of the lake (toward -Z), planks reach toward open water (+Z).
	local plankY = topY + 0.4
	local dockZStart = c.Z - r - 10
	local dockX = c.X

	local dock = Instance.new("Model")
	dock.Name = "Dock"
	dock.Parent = root

	for i = 0, 3 do
		local z = dockZStart + i * 2.9
		local pl = part(
			"Plank" .. tostring(i),
			Vector3.new(8.6, 0.45, 3.2),
			CFrame.new(dockX, plankY, z),
			dock,
			dockWood,
			wood
		)
		pl.CastShadow = true
	end

	for s = -1, 1, 2 do
		local post = part(
			"Post" .. tostring(s),
			Vector3.new(0.85, 5, 0.85),
			CFrame.new(dockX + s * 1.4, plankY - 2.3, dockZStart + 4.5),
			dock,
			dockWood,
			wood
		)
		post.Shape = Enum.PartType.Cylinder
		post.CFrame = post.CFrame * CFrame.Angles(0, 0, math.rad(90))
	end

	-- --- Shack (bait shop) ---
	local shackPos = Vector3.new(c.X - 58, topY + 4, c.Z - r - 36)
	local shack = Instance.new("Model")
	shack.Name = "BaitShack"
	shack.Parent = root

	local baseCf = CFrame.new(shackPos) * CFrame.Angles(0, math.rad(25), 0)
	local w, d, h = 14, 10, 12

	part("Floor", Vector3.new(w, 1, d), baseCf * CFrame.new(0, -h * 0.5, 0), shack, woodColor, wood)

	part("WallBack", Vector3.new(w, h, 0.6), baseCf * CFrame.new(0, 0, -d * 0.5 + 0.3), shack, woodColor, wood)

	part("WallLeft", Vector3.new(0.6, h, d - 1.2), baseCf * CFrame.new(-w * 0.5 + 0.3, 0, 0.2), shack, woodColor, wood)

	part("WallRight", Vector3.new(0.6, h, d - 1.2), baseCf * CFrame.new(w * 0.5 - 0.3, 0, 0.2), shack, woodColor, wood)

	-- Door opening: split front wall
	part(
		"WallFrontL",
		Vector3.new(w * 0.35, h, 0.6),
		baseCf * CFrame.new(-w * 0.25, 0, d * 0.5 - 0.3),
		shack,
		woodColor,
		wood
	)
	part(
		"WallFrontR",
		Vector3.new(w * 0.35, h, 0.6),
		baseCf * CFrame.new(w * 0.25, 0, d * 0.5 - 0.3),
		shack,
		woodColor,
		wood
	)

	-- Simple sloped roof (wedge)
	local roof = Instance.new("WedgePart")
	roof.Name = "Roof"
	roof.Size = Vector3.new(w + 1.2, 4, d + 1.2)
	roof.Material = wood
	roof.Color = roofColor
	roof.Anchored = true
	roof.CFrame = baseCf * CFrame.new(0, h * 0.5 + 1.8, 0) * CFrame.Angles(0, math.rad(90), math.rad(-18))
	roof.Parent = shack

	local sign = part(
		"Sign",
		Vector3.new(8, 2.2, 0.35),
		baseCf * CFrame.new(0, h * 0.35, d * 0.5 + 0.4) * CFrame.Angles(math.rad(-8), 0, 0),
		shack,
		Color3.fromRGB(220, 200, 140),
		Enum.Material.SmoothPlastic
	)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.AlwaysOnTop = false
	sg.LightInfluence = 0.2
	sg.Parent = sign
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.Cartoon
	lbl.Text = "BAIT & TACKLE"
	lbl.TextColor3 = Color3.fromRGB(40, 32, 24)
	lbl.TextScaled = true
	lbl.Parent = sg

	-- Counter (ProximityPrompt target)
	local counter = part(
		"Counter",
		Vector3.new(6, 2.2, 2.4),
		baseCf * CFrame.new(0, -h * 0.5 + 1.2, d * 0.5 - 1.8),
		shack,
		Color3.fromRGB(100, 70, 45),
		wood
	)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ObjectText = "Bait & Tackle"
	prompt.ActionText = "Open shop"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	prompt.Triggered:Connect(function(player: Player)
		openShop:FireClient(player)
	end)
end

return WorldBuild
