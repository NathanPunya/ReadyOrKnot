--!strict
-- Local-only rod, line (Beam), hook + bait; ballistic cast with gravity and water buoyancy.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CameraView = require(script.Parent:WaitForChild("CameraView"))

local player = Players.LocalPlayer

local activeSim: (() -> ())? = nil
local rodFolderName = "ReadyOrKnotFishingRod"
local rodsWorkspaceRootName = "ReadyOrKnotFishingRods"
local rodFollowConn: RBXScriptConnection? = nil

local function lakeDistSqXZ(pos: Vector3): number
	local dx = pos.X - Config.LAKE_CENTER_X
	local dz = pos.Z - Config.LAKE_CENTER_Z
	return dx * dx + dz * dz
end

local function inLakeWaterColumn(pos: Vector3): boolean
	local r = Config.LAKE_WATER_RADIUS
	if lakeDistSqXZ(pos) > r * r then
		return false
	end
	return pos.Y <= Config.LAKE_WATER_SURFACE_Y + 1.2
end

local function getHandPart(character: Model): BasePart?
	local r = character:FindFirstChild("RightHand")
	if r and r:IsA("BasePart") then
		return r
	end
	local r6 = character:FindFirstChild("Right Arm")
	if r6 and r6:IsA("BasePart") then
		return r6
	end
	return nil
end

local function getRodsRoot(): Folder
	local r = Workspace:FindFirstChild(rodsWorkspaceRootName)
	if r and r:IsA("Folder") then
		return r
	end
	local f = Instance.new("Folder")
	f.Name = rodsWorkspaceRootName
	f.Parent = Workspace
	return f
end

local function getPlayerRodFolder(): Folder?
	local root = Workspace:FindFirstChild(rodsWorkspaceRootName)
	if not root then
		return nil
	end
	local f = root:FindFirstChild(tostring(player.UserId))
	if f and f:IsA("Folder") then
		return f
	end
	return nil
end

local function destroyRodVisual()
	if rodFollowConn then
		rodFollowConn:Disconnect()
		rodFollowConn = nil
	end
	local f = getPlayerRodFolder()
	if f then
		f:Destroy()
	end
	local char = player.Character
	if char then
		local legacy = char:FindFirstChild(rodFolderName)
		if legacy then
			legacy:Destroy()
		end
	end
end

local function updateRodToHand()
	local char = player.Character
	if not char then
		return
	end
	local hand = getHandPart(char)
	local folder = getPlayerRodFolder()
	if not hand or not folder then
		return
	end
	local shaft = folder:FindFirstChild("Shaft")
	local reel = folder:FindFirstChild("Reel")
	if shaft and shaft:IsA("BasePart") then
		shaft.CFrame = hand.CFrame * CFrame.new(0, 0.05, -0.4) * CFrame.Angles(math.rad(78), math.rad(-8), math.rad(6))
	end
	if reel and reel:IsA("BasePart") then
		reel.CFrame = hand.CFrame * CFrame.new(0, -0.35, -0.5) * CFrame.Angles(0, 0, math.rad(90))
	end
end

-- First person: viewport-center ray (matches crosshair). Third person: character facing (no crosshair).
local function getLaunchDirection(hrp: BasePart): Vector3
	local look: Vector3
	if CameraView.isFirstPerson() then
		local cam = Workspace.CurrentCamera
		if cam then
			local vs = cam.ViewportSize
			local ray = cam:ViewportPointToRay(vs.X * 0.5, vs.Y * 0.5)
			look = ray.Direction
		else
			look = hrp.CFrame.LookVector
		end
	else
		local f = hrp.CFrame.LookVector
		local flat = Vector3.new(f.X, 0, f.Z)
		if flat.Magnitude < 0.12 then
			flat = Vector3.new(0, 0, -1)
		else
			flat = flat.Unit
		end
		look = (flat * 0.94 + Vector3.new(0, 0.12, 0)).Unit
	end
	if look.Magnitude < 1e-4 then
		look = hrp.CFrame.LookVector
	end
	look = look.Unit
	if look.Y < -0.92 then
		look = Vector3.new(look.X, -0.35, look.Z).Unit
	end
	return look
end

-- Mix aim toward “up” for a lob; when the rod is high (e.g. cliff / dock), ease off the lob and bias downward.
local function applyCastArcBias(dir: Vector3, heightAboveWater: number): Vector3
	local d = dir.Unit
	local up = Vector3.new(0, 1, 0)
	local highT = math.clamp(heightAboveWater / 38, 0, 1)
	local upBlend = 0.38 * (1 - highT * 0.92)
	local mixed = d * (1 - upBlend) + up * upBlend
	if mixed.Magnitude < 1e-4 then
		return d
	end
	mixed = mixed.Unit
	if highT > 0.08 then
		local pullDown = highT * 0.26
		mixed = (mixed + Vector3.new(0, -pullDown, 0)).Unit
	end
	if mixed.Y < -0.35 then
		mixed = (d * 0.78 + up * 0.22).Unit
	end
	return mixed
end

local function smoothstep01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Beam curve control points use Attachment.CFrame.RightVector (see Beam.CurveSize docs), not world-down.
-- Without reorienting, the rod shaft’s local X axis bends the line sideways only.
-- Cast → settled bow change is done with signed CurveSize only (see Heartbeat); RightVector stays along gravity-in-plane (no sideways rotation).
local function alignBeamAttachmentsForGravitySag(
	shaft: BasePart,
	tipAtt: Attachment,
	hook: BasePart,
	hookAtt: Attachment,
	tipWorld: Vector3,
	hookWorld: Vector3
)
	local span = hookWorld - tipWorld
	local mag = span.Magnitude
	if mag < 1e-3 then
		return
	end
	local chordU = span / mag
	local down = Vector3.new(0, -1, 0)
	local gravInPlane = down - chordU * down:Dot(chordU)
	if gravInPlane.Magnitude < 0.06 then
		gravInPlane = chordU:Cross(Vector3.yAxis)
		if gravInPlane.Magnitude < 0.06 then
			gravInPlane = Vector3.new(1, 0, 0)
		end
	end
	local sagDir = gravInPlane.Unit
	local upAxis = chordU:Cross(sagDir)
	if upAxis.Magnitude < 0.06 then
		return
	end
	upAxis = upAxis.Unit
	local zAxis = sagDir:Cross(upAxis)
	local wTip = CFrame.fromMatrix(tipWorld, sagDir, upAxis, zAxis)
	tipAtt.CFrame = shaft.CFrame:Inverse() * wTip
	local wHook = CFrame.fromMatrix(hookWorld, sagDir, upAxis, zAxis)
	hookAtt.CFrame = hook.CFrame:Inverse() * wHook
end

-- Roblox Beam.Segments is capped low; many short Beams along the same cubic read much smoother.
local LINE_CHAIN_SUBDIV = 16
local LINE_CHAIN_BEAM_SEGMENTS = 6

local function cubicBezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local u = 1 - t
	return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
end

local function ensureRod(character: Model): (BasePart?, Attachment?)
	-- Workspace-parented rod + per-frame hand sync: stays visible in first person (character parts are often culled / transparent).
	local legacy = character:FindFirstChild(rodFolderName)
	if legacy then
		legacy:Destroy()
	end

	local folder = getPlayerRodFolder()
	if folder then
		local shaft = folder:FindFirstChild("Shaft")
		local tip = shaft and shaft:IsA("BasePart") and shaft:FindFirstChild("Tip")
		if shaft and shaft:IsA("BasePart") and tip and tip:IsA("Attachment") then
			if not rodFollowConn then
				rodFollowConn = RunService.RenderStepped:Connect(updateRodToHand)
			end
			return shaft, tip
		end
	end

	local hand = getHandPart(character)
	if not hand then
		return nil, nil
	end

	destroyRodVisual()

	local root = getRodsRoot()
	local newFolder = Instance.new("Folder")
	newFolder.Name = tostring(player.UserId)
	newFolder.Parent = root

	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.14, 0.14, 4.8)
	shaft.Color = Color3.fromRGB(88, 62, 42)
	shaft.Material = Enum.Material.Wood
	shaft.Massless = true
	shaft.CanCollide = false
	shaft.Anchored = true
	shaft.CastShadow = true
	shaft.Parent = newFolder

	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 0, -2.45)
	tip.Parent = shaft

	local reel = Instance.new("Part")
	reel.Name = "Reel"
	reel.Shape = Enum.PartType.Cylinder
	reel.Size = Vector3.new(0.35, 0.22, 0.22)
	reel.Color = Color3.fromRGB(70, 78, 92)
	reel.Material = Enum.Material.Metal
	reel.Massless = true
	reel.CanCollide = false
	reel.Anchored = true
	reel.Parent = newFolder

	updateRodToHand()

	if rodFollowConn then
		rodFollowConn:Disconnect()
	end
	rodFollowConn = RunService.RenderStepped:Connect(updateRodToHand)

	return shaft, tip
end

local function playCast(): boolean
	local character = player.Character
	if not character then
		return false
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return false
	end

	local shaft, tipAtt = ensureRod(character)
	if not shaft or not tipAtt then
		return false
	end

	local hook = Instance.new("Part")
	hook.Name = "HookVisual"
	hook.Shape = Enum.PartType.Ball
	hook.Size = Vector3.new(0.22, 0.22, 0.22)
	hook.Color = Color3.fromRGB(190, 195, 205)
	hook.Material = Enum.Material.Metal
	hook.Massless = true
	hook.CanCollide = false
	hook.Anchored = true
	hook.CastShadow = true
	hook.Parent = Workspace

	local hookAtt = Instance.new("Attachment")
	hookAtt.Name = "HookAtt"
	hookAtt.Parent = hook

	local bait = Instance.new("Part")
	bait.Name = "Bait"
	bait.Shape = Enum.PartType.Ball
	bait.Size = Vector3.new(0.18, 0.18, 0.18)
	bait.Color = Color3.fromRGB(220, 160, 120)
	bait.Material = Enum.Material.SmoothPlastic
	bait.Massless = true
	bait.CanCollide = false
	bait.Anchored = true
	bait.Parent = Workspace

	local lineFolder = Instance.new("Folder")
	lineFolder.Name = "FishingLineChain"
	lineFolder.Parent = shaft

	local chainNodes: { BasePart } = {}
	local chainLinkAtts: { Attachment } = {}
	for _ = 1, LINE_CHAIN_SUBDIV - 1 do
		local p = Instance.new("Part")
		p.Name = "LineNode"
		p.Size = Vector3.new(0.06, 0.06, 0.06)
		p.Transparency = 1
		p.CanCollide = false
		p.Anchored = true
		p.Massless = true
		p.CastShadow = false
		local att = Instance.new("Attachment")
		att.Name = "Link"
		att.Parent = p
		p.Parent = lineFolder
		table.insert(chainNodes, p)
		table.insert(chainLinkAtts, att)
	end

	for k = 1, LINE_CHAIN_SUBDIV do
		local a0: Attachment
		local a1: Attachment
		if k == 1 then
			a0 = tipAtt
			a1 = chainLinkAtts[1]
		elseif k == LINE_CHAIN_SUBDIV then
			a0 = chainLinkAtts[LINE_CHAIN_SUBDIV - 1]
			a1 = hookAtt
		else
			a0 = chainLinkAtts[k - 1]
			a1 = chainLinkAtts[k]
		end
		local seg = Instance.new("Beam")
		seg.Name = "LineSeg" .. tostring(k)
		seg.Attachment0 = a0
		seg.Attachment1 = a1
		local t0 = (k - 1) / LINE_CHAIN_SUBDIV
		local t1 = k / LINE_CHAIN_SUBDIV
		seg.Width0 = 0.02 + 0.015 * (1 - t0)
		seg.Width1 = 0.02 + 0.015 * (1 - t1)
		seg.FaceCamera = true
		seg.LightEmission = 0.15
		seg.LightInfluence = 0.4
		seg.Color = ColorSequence.new(Color3.fromRGB(210, 225, 240))
		seg.Transparency = NumberSequence.new(0.12)
		seg.CurveSize0 = 0
		seg.CurveSize1 = 0
		seg.Segments = LINE_CHAIN_BEAM_SEGMENTS
		seg.Parent = lineFolder
	end

	local tipWorld = tipAtt.WorldPosition
	local heightAboveWater = tipWorld.Y - Config.LAKE_WATER_SURFACE_Y
	local launch = applyCastArcBias(getLaunchDirection(hrp), heightAboveWater)
	local speed = 80
	local pos = tipWorld
	hook.CFrame = CFrame.new(pos)
	bait.CFrame = hook.CFrame * CFrame.new(0, -0.2, 0)
	local vel = launch * speed
	local t = 0
	local bobPhase = 0
	local gravity = Workspace.Gravity
	-- 0 = casting line, 1 = settled; smoothed toward target each frame, then smoothstep for gradual curve blend.
	local settleAlpha = 0

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local excludeList: { Instance } = { character, hook, bait }
	local rodFolder = getPlayerRodFolder()
	if rodFolder then
		table.insert(excludeList, rodFolder)
	end
	table.insert(excludeList, lineFolder)
	rayParams.FilterDescendantsInstances = excludeList

	local conn: RBXScriptConnection?
	local ended = false

	local function finish()
		if ended then
			return
		end
		ended = true
		activeSim = nil
		if conn then
			conn:Disconnect()
		end
		if lineFolder and lineFolder.Parent then
			lineFolder:Destroy()
		end
		if hook and hook.Parent then
			hook:Destroy()
		end
		if bait and bait.Parent then
			bait:Destroy()
		end
	end

	activeSim = finish

	conn = RunService.Heartbeat:Connect(function(dt: number)
		if ended or not hook.Parent then
			finish()
			return
		end
		dt = math.clamp(dt, 0, 0.05)
		t += dt
		bobPhase += dt * 5

		vel += Vector3.new(0, -gravity * dt, 0)

		local wet = inLakeWaterColumn(pos)
		if wet then
			local surface = Config.LAKE_WATER_SURFACE_Y
			local sub = surface - pos.Y
			local buoy = math.clamp(sub * 42, -35, 80)
			vel += Vector3.new(0, buoy * dt, 0)
			vel = Vector3.new(vel.X * (1 - 1.8 * dt), vel.Y, vel.Z * (1 - 1.8 * dt))
			if pos.Y < surface - 0.05 then
				pos = Vector3.new(pos.X, surface - 0.05 + math.sin(bobPhase) * 0.12, pos.Z)
				vel = Vector3.new(vel.X * 0.92, math.sin(bobPhase * 1.3) * 0.8, vel.Z * 0.92)
			end
		end

		local step = vel * dt
		local newPos = pos + step
		local cast = Workspace:Raycast(pos, step + step.Unit * 0.25, rayParams)
		if cast and cast.Instance and not wet and cast.Material ~= Enum.Material.Water then
			newPos = cast.Position - step.Unit * 0.08
			vel = vel * Vector3.new(0.35, -0.25, 0.35)
		end

		pos = newPos
		hook.CFrame = CFrame.new(pos)
		bait.CFrame = hook.CFrame * CFrame.new(0, -0.2, 0)

		local tipPos = tipAtt.WorldPosition
		local speed = vel.Magnitude
		local targetSettle = 0
		if wet and speed < 15 and t > 0.28 then
			targetSettle = 1
		elseif speed < 3.5 and t > 0.5 then
			targetSettle = 1
		end
		if speed > 28 or (t < 0.2 and speed > 14) then
			targetSettle = 0
		end
		-- Lower = slower approach to settled curve (exponential smoothing).
		settleAlpha += (targetSettle - settleAlpha) * math.min(1, dt * 0.65)
		local curveBlend = smoothstep01(settleAlpha)

		alignBeamAttachmentsForGravitySag(shaft, tipAtt, hook, hookAtt, tipPos, pos)

		local span = (pos - tipPos).Magnitude
		local verticalDrop = math.max(0, tipPos.Y - pos.Y)
		-- Extra sag when the hook hangs well below the tip (common when casting from height).
		local dropBonus = math.clamp(verticalDrop / 16, 0, 4)
		local highRodBonus = math.clamp((tipPos.Y - Config.LAKE_WATER_SURFACE_Y) / 28, 0, 2.5)
		local sagBase = math.clamp(span * 0.052 * (1 + dropBonus * 0.5 + highRodBonus * 0.22), 0.4, 9)
		local sagCast = sagBase * (1.12 + 0.14 * math.clamp(highRodBonus / 2.5, 0, 1))
		local sagSettle = sagBase * 0.8
		local sag = sagCast * (1 - curveBlend) + sagSettle * curveBlend
		-- Fixed RightVector (gravity in sag plane): negative = bow up, positive = bow down — scalar blend only, no in-plane rotation.
		local bowSign = -1 + 2 * curveBlend
		local curve0 = sag * (1.2 + dropBonus * 0.12 + highRodBonus * 0.08) * bowSign
		local curve1 = sag * (0.88 + dropBonus * 0.1 + highRodBonus * 0.06) * bowSign
		local p0 = tipPos
		local p1 = p0 + tipAtt.WorldCFrame.RightVector * curve0
		local p3 = pos
		local p2 = p3 - hookAtt.WorldCFrame.RightVector * curve1
		for i = 1, #chainNodes do
			local ti = i / LINE_CHAIN_SUBDIV
			chainNodes[i].CFrame = CFrame.new(cubicBezier(p0, p1, p2, p3, ti))
		end
	end)
	return true
end

local FishingVisual = {}

-- If line is out, reels in (no server cast). Otherwise starts a cast; returns true when a new cast begins (caller should FireServer).
function FishingVisual.performCastOrReel(): boolean
	if activeSim then
		activeSim()
		return false
	end
	return playCast()
end

function FishingVisual.playCast()
	task.defer(function()
		playCast()
	end)
end

function FishingVisual.init()
	player.CharacterRemoving:Connect(function()
		destroyRodVisual()
		if activeSim then
			activeSim()
			activeSim = nil
		end
	end)
end

return FishingVisual
