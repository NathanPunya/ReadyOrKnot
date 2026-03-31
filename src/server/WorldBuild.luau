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
	-- Slight overlap between planks (3.2 deep) avoids visible gaps from render/terrain.
	local plankSpacing = 2.75
	local plankCount = 9

	local dock = Instance.new("Model")
	dock.Name = "Dock"
	dock.Parent = root

	for i = 0, plankCount - 1 do
		local z = dockZStart + i * plankSpacing
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

	local function addPosts(zOffset: number, suffix: string)
		for s = -1, 1, 2 do
			local post = part(
				"Post" .. suffix .. tostring(s),
				Vector3.new(0.85, 5, 0.85),
				CFrame.new(dockX + s * 1.4, plankY - 2.3, dockZStart + zOffset),
				dock,
				dockWood,
				wood
			)
			post.Shape = Enum.PartType.Cylinder
			post.CFrame = post.CFrame * CFrame.Angles(0, 0, math.rad(90))
		end
	end

	addPosts(4.5, "A")
	addPosts(20, "B")

	-- --- Spawn landing (shore side of dock; faces the lake +Z) ---
	local spawnFolder = Instance.new("Model")
	spawnFolder.Name = "SpawnLanding"
	spawnFolder.Parent = root

	local spawnZ = dockZStart - 14
	local spawnX = dockX
	local deckThick = 0.55
	local deckY = topY + deckThick * 0.5
	local deck = part(
		"Deck",
		Vector3.new(22, deckThick, 18),
		CFrame.new(spawnX, deckY, spawnZ),
		spawnFolder,
		dockWood,
		wood
	)
	deck.CastShadow = true

	for _, corner in { { -10, -7 }, { 10, -7 }, { -10, 7 }, { 10, 7 } } do
		part(
			"Bollard_" .. tostring(corner[1]) .. "_" .. tostring(corner[2]),
			Vector3.new(0.5, 2.1, 0.5),
			CFrame.new(spawnX + corner[1], deckY + deckThick * 0.5 + 1.05, spawnZ + corner[2]),
			spawnFolder,
			dockWood,
			wood
		)
	end

	local signY = deckY + deckThick * 0.5 + 2.85
	local signZ = spawnZ - 9.2
	local welcome = part(
		"WelcomeSign",
		Vector3.new(12, 3, 0.35),
		CFrame.new(spawnX, signY, signZ) * CFrame.Angles(0, math.rad(180), 0) * CFrame.Angles(math.rad(-10), 0, 0),
		spawnFolder,
		Color3.fromRGB(215, 195, 145),
		Enum.Material.SmoothPlastic
	)
	local wgui = Instance.new("SurfaceGui")
	wgui.Face = Enum.NormalId.Front
	wgui.LightInfluence = 0.25
	wgui.Parent = welcome
	local w1 = Instance.new("TextLabel")
	w1.Size = UDim2.new(1, -10, 0.42, 0)
	w1.Position = UDim2.new(0, 5, 0, 6)
	w1.BackgroundTransparency = 1
	w1.Font = Enum.Font.GothamBold
	w1.Text = "Ready Or Knot"
	w1.TextColor3 = Color3.fromRGB(32, 48, 62)
	w1.TextScaled = true
	w1.Parent = wgui
	local w2 = Instance.new("TextLabel")
	w2.Size = UDim2.new(1, -10, 0.38, 0)
	w2.Position = UDim2.new(0, 5, 0.52, 0)
	w2.BackgroundTransparency = 1
	w2.Font = Enum.Font.GothamMedium
	w2.Text = "Fish the lake — cast from the dock"
	w2.TextColor3 = Color3.fromRGB(55, 72, 88)
	w2.TextScaled = true
	w2.Parent = wgui

	part(
		"TackleCrate",
		Vector3.new(2.1, 1.35, 1.55),
		CFrame.new(spawnX - 7.2, deckY + deckThick * 0.5 + 0.68, spawnZ + 5) * CFrame.Angles(0, math.rad(22), 0),
		spawnFolder,
		Color3.fromRGB(92, 64, 38),
		wood
	)
	local barrel = part(
		"Barrel",
		Vector3.new(2.3, 2.5, 2.3),
		CFrame.new(spawnX + 7.8, deckY + deckThick * 0.5 + 1.25, spawnZ + 4.2),
		spawnFolder,
		Color3.fromRGB(85, 58, 36),
		wood
	)
	barrel.Shape = Enum.PartType.Cylinder
	barrel.CFrame = barrel.CFrame * CFrame.Angles(0, 0, math.rad(90))

	part(
		"NetRoll",
		Vector3.new(3.2, 0.25, 1.1),
		CFrame.new(spawnX - 8.5, deckY + deckThick * 0.5 + 0.2, spawnZ - 2) * CFrame.Angles(math.rad(-4), math.rad(35), math.rad(2)),
		spawnFolder,
		Color3.fromRGB(180, 188, 198),
		Enum.Material.Fabric
	)

	for _, old in Workspace:GetChildren() do
		if old:IsA("SpawnLocation") and old.Name == "DockSpawn" then
			old:Destroy()
		end
	end

	local deckTop = deckY + deckThick * 0.5
	local spawnPos = Vector3.new(spawnX, deckTop + 0.5, spawnZ)
	local sp = Instance.new("SpawnLocation")
	sp.Name = "DockSpawn"
	sp.Size = Vector3.new(14, 1, 14)
	sp.CFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(0, 0, 1))
	sp.Anchored = true
	sp.Neutral = true
	sp.Duration = 0
	sp.TeamColor = BrickColor.new("Bright blue")
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Parent = spawnFolder

	-- --- Shack (bait shop) ---
	local shackPos = Vector3.new(c.X - 58, topY + 4, c.Z - r - 36)
	local shack = Instance.new("Model")
	shack.Name = "BaitShack"
	shack.Parent = root

	local baseCf = CFrame.new(shackPos) * CFrame.Angles(0, math.rad(25), 0)
	local w, d, h = 14, 10, 12
	local tWall = 0.6
	local doorGap = 2.1
	local doorHalf = doorGap * 0.5
	-- Inner X of side walls (flush with front segments); outer faces sit at ±w/2.
	local xInL = -w * 0.5 + tWall
	local xInR = w * 0.5 - tWall

	part("Floor", Vector3.new(w, 1, d), baseCf * CFrame.new(0, -h * 0.5, 0), shack, woodColor, wood)

	part(
		"WallBack",
		Vector3.new(w, h, tWall),
		baseCf * CFrame.new(0, 0, -d * 0.5 + tWall * 0.5),
		shack,
		woodColor,
		wood
	)

	-- Full-depth side walls (meet back + front segments; door is center-front only).
	part(
		"WallLeft",
		Vector3.new(tWall, h, d),
		baseCf * CFrame.new(-w * 0.5 + tWall * 0.5, 0, 0),
		shack,
		woodColor,
		wood
	)
	part(
		"WallRight",
		Vector3.new(tWall, h, d),
		baseCf * CFrame.new(w * 0.5 - tWall * 0.5, 0, 0),
		shack,
		woodColor,
		wood
	)

	-- Front wall: span from inner side wall to door jamb (old w*0.35 missed corners by ~0.45 studs).
	local frontZ = d * 0.5 - tWall * 0.5
	local fwL = (-doorHalf) - xInL
	local cxL = (xInL + (-doorHalf)) * 0.5
	local fwR = xInR - doorHalf
	local cxR = (doorHalf + xInR) * 0.5
	part("WallFrontL", Vector3.new(fwL, h, tWall), baseCf * CFrame.new(cxL, 0, frontZ), shack, woodColor, wood)
	part("WallFrontR", Vector3.new(fwR, h, tWall), baseCf * CFrame.new(cxR, 0, frontZ), shack, woodColor, wood)

	-- Flat roof parallel to the ground (only baseCf’s Y‑yaw turns with the building; no extra pitch/roll).
	local roofThick = 0.52
	local roofOverhang = 0.75
	local roof = part(
		"Roof",
		Vector3.new(w + roofOverhang * 2, roofThick, d + roofOverhang * 2),
		baseCf * CFrame.new(0, h * 0.5 + roofThick * 0.5, 0),
		shack,
		roofColor,
		wood
	)
	roof.CastShadow = true

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
