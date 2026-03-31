--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Progression = require(Shared:WaitForChild("Progression"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CastFishing = Remotes:WaitForChild("CastFishing") :: RemoteEvent
local SellFish = Remotes:WaitForChild("SellFish") :: RemoteEvent
local PurchaseItem = Remotes:WaitForChild("PurchaseItem") :: RemoteEvent
local StateSync = Remotes:WaitForChild("StateSync") :: RemoteEvent
local OpenShop = Remotes:WaitForChild("OpenShop") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local palette = {
	bg = Color3.fromRGB(20, 36, 52),
	panel = Color3.fromRGB(28, 48, 68),
	accent = Color3.fromRGB(72, 186, 210),
	muted = Color3.fromRGB(140, 170, 190),
	text = Color3.fromRGB(235, 245, 250),
	good = Color3.fromRGB(110, 220, 160),
	warn = Color3.fromRGB(255, 200, 120),
}

local function corner(r: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	return c
end

local function stroke(t: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = t
	s.Color = Color3.fromRGB(45, 70, 92)
	s.Transparency = 0.3
	return s
end

local UI = {}

local refs: {
	money: TextLabel,
	level: TextLabel,
	xpFill: Frame,
	xpLabel: TextLabel,
	castBtn: TextButton,
	cooldownLabel: TextLabel,
	statusLabel: TextLabel,
	invList: ScrollingFrame,
	shopFrame: Frame,
	shopScroll: ScrollingFrame,
	castPanel: Frame,
	invPanel: Frame,
}?

local lastCooldownEnd = 0
local lastCooldownDuration = 3

local function formatMoney(n: number): string
	return "$" .. tostring(n)
end

local function setXpBar(totalXP: number)
	local r = refs
	if not r then
		return
	end
	local level, xpIn, need = Progression.getLevelProgress(totalXP)
	r.level.Text = "Level " .. tostring(level)
	r.xpLabel.Text = string.format("%d / %d XP", xpIn, need)
	local p = if need > 0 then xpIn / need else 1
	r.xpFill.Size = UDim2.new(math.clamp(p, 0, 1), 0, 1, 0)
end

local function fishName(id: string): string
	local f = Config.FishById[id]
	return f and f.name or id
end

local function renderInventory(inv: any)
	local r = refs
	if not r then
		return
	end
	for _, c in r.invList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if typeof(inv) ~= "table" then
		return
	end
	local layout = r.invList:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.Parent = r.invList
	end
	for _, entry in inv do
		if typeof(entry) == "table" and typeof(entry.fishId) == "string" then
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -12, 0, 28)
			row.BackgroundColor3 = palette.panel
			row.BorderSizePixel = 0
			row.Parent = r.invList
			corner(6).Parent = row
			local bonus = ""
			if typeof(entry.valueBonus) == "number" and entry.valueBonus > 1 then
				bonus = "  (Gen-A+)"
			end
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.new(1, -16, 1, 0)
			t.Position = UDim2.new(0, 8, 0, 0)
			t.Font = Enum.Font.GothamMedium
			t.TextSize = 14
			t.TextColor3 = palette.text
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.Text = fishName(entry.fishId) .. bonus
			t.Parent = row
		end
	end
	task.defer(function()
		if layout.Parent then
			r.invList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
		end
	end)
end

local function renderShop(equipment: any)
	local r = refs
	if not r then
		return
	end
	for _, c in r.shopScroll:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local layout = r.shopScroll:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = r.shopScroll
	end

	local order = 0
	local function header(text: string)
		order += 1
		local h = Instance.new("TextLabel")
		h.BackgroundTransparency = 1
		h.Size = UDim2.new(1, -12, 0, 22)
		h.Font = Enum.Font.GothamBold
		h.TextSize = 16
		h.TextColor3 = palette.accent
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.Text = text
		h.LayoutOrder = order
		h.Parent = r.shopScroll
	end

	local function rowItem(item: any, ownedId: string?)
		order += 1
		local owned = ownedId == item.id
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 52)
		row.BackgroundColor3 = palette.panel
		row.BorderSizePixel = 0
		row.LayoutOrder = order
		row.Parent = r.shopScroll
		corner(8).Parent = row
		stroke(1).Parent = row

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.new(0, 10, 0, 6)
		title.Size = UDim2.new(0.65, 0, 0, 20)
		title.Font = Enum.Font.GothamMedium
		title.TextSize = 15
		title.TextColor3 = palette.text
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = item.name
		title.Parent = row

		local meta = Instance.new("TextLabel")
		meta.BackgroundTransparency = 1
		meta.Position = UDim2.new(0, 10, 0, 26)
		meta.Size = UDim2.new(0.65, 0, 0, 18)
		meta.Font = Enum.Font.Gotham
		meta.TextSize = 12
		meta.TextColor3 = palette.muted
		meta.TextXAlignment = Enum.TextXAlignment.Left
		meta.Text = string.format(
			"Rarity +%.2f  Gen-A +%.1f%%  Sell x%.2f",
			item.rarityWeightBonus,
			item.genABonus * 100,
			item.sellValueMult
		)
		meta.Parent = row

		local price = Instance.new("TextLabel")
		price.BackgroundTransparency = 1
		price.Position = UDim2.new(0.62, 0, 0, 8)
		price.Size = UDim2.new(0.35, -8, 0, 20)
		price.Font = Enum.Font.GothamBold
		price.TextSize = 15
		price.TextColor3 = palette.good
		price.TextXAlignment = Enum.TextXAlignment.Right
		price.Text = item.price <= 0 and "—" or formatMoney(item.price)
		price.Parent = row

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.32, -8, 0, 32)
		btn.Position = UDim2.new(0.66, 0, 0, 14)
		btn.BackgroundColor3 = owned and palette.muted or palette.accent
		btn.BackgroundTransparency = owned and 0.5 or 0.1
		btn.Text = owned and "Equipped" or "Buy"
		btn.TextColor3 = palette.bg
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 14
		btn.AutoButtonColor = not owned
		btn.Parent = row
		corner(6).Parent = btn

		if not owned and item.price > 0 then
			btn.MouseButton1Click:Connect(function()
				PurchaseItem:FireServer(item.id)
			end)
		end
	end

	local kindOrder = { "pole", "bait", "line", "hook" }
	local titles: { [string]: string } = {
		pole = "Fishing poles",
		bait = "Bait",
		line = "Line",
		hook = "Hooks",
	}
	for _, kind in kindOrder do
		header(titles[kind] or kind)
		local ownedId: string? = if typeof(equipment) == "table" then equipment[kind] else nil
		local list = Config.getEquipmentForKind(kind :: any)
		for _, item in list do
			if item.price >= 0 then
				rowItem(item, ownedId)
			end
		end
	end

	task.defer(function()
		r.shopScroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
	end)
end

local function applyState(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local r = refs
	if not r then
		return
	end
	if typeof(payload.money) == "number" then
		r.money.Text = formatMoney(payload.money)
	end
	if typeof(payload.totalXP) == "number" then
		setXpBar(payload.totalXP)
	end
	renderInventory(payload.inventory)
	renderShop(payload.equipment)
end

function UI.mount()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ReadyOrKnotUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui

	-- Top HUD card: half the width of a full-bleed bar with the same total L+R margin budget, centered.
	local topPadL = 56
	local topPadR = 20
	local topMarginTotal = topPadL + topPadR
	local top = Instance.new("Frame")
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Size = UDim2.new(0.5, -topMarginTotal / 2, 0, 64)
	top.Position = UDim2.new(0.5, 0, 0, 16)
	top.BackgroundColor3 = palette.bg
	top.BackgroundTransparency = 0.15
	top.BorderSizePixel = 0
	top.Parent = root
	corner(12).Parent = top
	stroke(1).Parent = top

	local hudRowY = 11
	local money = Instance.new("TextLabel")
	money.BackgroundTransparency = 1
	money.AnchorPoint = Vector2.new(1, 0)
	money.Size = UDim2.new(0, 59, 0, 16)
	money.Position = UDim2.new(1, -12, 0, hudRowY)
	money.Font = Enum.Font.GothamBold
	money.TextSize = 12
	money.TextColor3 = palette.good
	money.TextXAlignment = Enum.TextXAlignment.Right
	money.Text = formatMoney(0)
	money.Parent = top

	local level = Instance.new("TextLabel")
	level.BackgroundTransparency = 1
	level.AnchorPoint = Vector2.new(0.5, 0)
	level.Size = UDim2.new(0, 48, 0, 16)
	level.Position = UDim2.new(0.5, 0, 0, hudRowY)
	level.Font = Enum.Font.GothamMedium
	level.TextSize = 12
	level.TextColor3 = palette.text
	level.TextXAlignment = Enum.TextXAlignment.Center
	level.Text = "Level 1"
	level.Parent = top

	local xpRowY = 31
	local xpBack = Instance.new("Frame")
	xpBack.BackgroundColor3 = palette.panel
	xpBack.BorderSizePixel = 0
	xpBack.Size = UDim2.new(1, -24, 0, 10)
	xpBack.Position = UDim2.new(0, 12, 0, xpRowY)
	xpBack.Parent = top
	corner(5).Parent = xpBack

	local xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.BackgroundColor3 = palette.accent
	xpFill.BorderSizePixel = 0
	xpFill.Size = UDim2.new(0, 0, 1, 0)
	xpFill.Parent = xpBack
	corner(5).Parent = xpFill

	local xpLabel = Instance.new("TextLabel")
	xpLabel.BackgroundTransparency = 1
	xpLabel.Size = UDim2.new(1, 0, 0, 13)
	xpLabel.Position = UDim2.new(0, 0, 0, 44)
	xpLabel.Font = Enum.Font.Gotham
	xpLabel.TextSize = 11
	xpLabel.TextColor3 = palette.muted
	xpLabel.Text = "0 / 100 XP"
	xpLabel.Parent = top

	local castW, castH = 252, 134
	local mid = Instance.new("Frame")
	mid.Name = "CastPanel"
	mid.Visible = false
	mid.AnchorPoint = Vector2.new(1, 0.5)
	mid.Size = UDim2.new(0, castW, 0, castH)
	mid.Position = UDim2.new(1, -24, 0.5, 0)
	mid.BackgroundColor3 = palette.panel
	mid.BackgroundTransparency = 0.06
	mid.BorderSizePixel = 0
	mid.Parent = root
	corner(12).Parent = mid
	local midStroke = stroke(1)
	midStroke.Transparency = 0.35
	midStroke.Parent = mid

	local midShade = Instance.new("UIGradient")
	midShade.Rotation = 90
	midShade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 58, 78)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 38, 54)),
	})
	midShade.Parent = mid

	local castTitle = Instance.new("TextLabel")
	castTitle.Name = "SectionTitle"
	castTitle.BackgroundTransparency = 1
	castTitle.Size = UDim2.new(1, -28, 0, 16)
	castTitle.Position = UDim2.new(0, 14, 0, 12)
	castTitle.Font = Enum.Font.GothamBold
	castTitle.TextSize = 13
	castTitle.TextXAlignment = Enum.TextXAlignment.Left
	castTitle.TextColor3 = palette.muted
	castTitle.Text = "FISHING"
	castTitle.Parent = mid

	local castBtn = Instance.new("TextButton")
	castBtn.Size = UDim2.new(1, -28, 0, 34)
	castBtn.Position = UDim2.new(0, 14, 0, 32)
	castBtn.BackgroundColor3 = palette.accent
	castBtn.AutoButtonColor = false
	local castKeyLabel = (function()
		local s = tostring(Config.CAST_LINE_KEYCODE)
		return (string.match(s, "%.([^%.]+)$")) or s
	end)()
	castBtn.Text = "Cast line  [" .. castKeyLabel .. "]"
	castBtn.TextColor3 = palette.bg
	castBtn.Font = Enum.Font.GothamBold
	castBtn.TextSize = 16
	castBtn.Parent = mid
	corner(8).Parent = castBtn
	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = palette.accent:Lerp(Color3.fromRGB(255, 255, 255), 0.4)
	btnStroke.Thickness = 1
	btnStroke.Transparency = 0.45
	btnStroke.Parent = castBtn

	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Size = UDim2.new(1, -28, 0, 14)
	cooldownLabel.Position = UDim2.new(0, 14, 0, 70)
	cooldownLabel.Font = Enum.Font.GothamMedium
	cooldownLabel.TextSize = 12
	cooldownLabel.TextColor3 = palette.muted
	cooldownLabel.Text = ""
	cooldownLabel.Parent = mid

	local statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Size = UDim2.new(1, -28, 0, 48)
	statusLabel.Position = UDim2.new(0, 14, 0, 84)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 13
	statusLabel.TextColor3 = palette.text
	statusLabel.TextWrapped = true
	statusLabel.Text = "Sell catches in your bag, upgrade gear at the shop."
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.LineHeight = 1.15
	statusLabel.Parent = mid

	local castBtnBase = palette.accent
	castBtn.MouseEnter:Connect(function()
		castBtn.BackgroundColor3 = castBtnBase:Lerp(Color3.fromRGB(255, 255, 255), 0.1)
	end)
	castBtn.MouseLeave:Connect(function()
		castBtn.BackgroundColor3 = castBtnBase
	end)
	local function tryCastFromKeybind()
		if not mid.Visible then
			return
		end
		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		CastFishing:FireServer()
	end

	castBtn.MouseButton1Click:Connect(function()
		CastFishing:FireServer()
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end
		if input.KeyCode == Config.CAST_LINE_KEYCODE then
			tryCastFromKeybind()
			return
		end
		if
			input.UserInputType == Enum.UserInputType.Gamepad1
			and input.KeyCode == Enum.KeyCode.ButtonX
		then
			tryCastFromKeybind()
		end
	end)

	local bagExpandedH = 260
	local bagCollapsedH = 52
	local bagListCollapsed = true

	local invPanel = Instance.new("Frame")
	invPanel.Name = "CatchBag"
	invPanel.Visible = true
	invPanel.AnchorPoint = Vector2.new(0, 1)
	invPanel.Size = UDim2.new(0, 360, 0, bagCollapsedH)
	invPanel.Position = UDim2.new(0, 8, 1, -8)
	invPanel.BackgroundColor3 = palette.bg
	invPanel.BackgroundTransparency = 0.12
	invPanel.BorderSizePixel = 0
	invPanel.Parent = root
	corner(12).Parent = invPanel
	stroke(1).Parent = invPanel

	-- Parent list first so header row (added after) is on top and gets clicks; ScrollingFrame was last before and blocked the minimize button.
	local invList = Instance.new("ScrollingFrame")
	invList.Name = "List"
	invList.Size = UDim2.new(1, -24, 1, -52)
	invList.Position = UDim2.new(0, 12, 0, 44)
	invList.BackgroundTransparency = 1
	invList.BorderSizePixel = 0
	invList.ScrollBarThickness = 6
	invList.CanvasSize = UDim2.new(0, 0, 0, 0)
	invList.ZIndex = 0
	invList.Parent = invPanel
	local invLayout = Instance.new("UIListLayout")
	invLayout.Padding = UDim.new(0, 6)
	invLayout.SortOrder = Enum.SortOrder.LayoutOrder
	invLayout.Parent = invList

	local invTitle = Instance.new("TextLabel")
	invTitle.BackgroundTransparency = 1
	invTitle.Size = UDim2.new(1, -176, 0, 26)
	invTitle.Position = UDim2.new(0, 14, 0, 8)
	invTitle.ZIndex = 1
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextSize = 18
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.TextColor3 = palette.text
	invTitle.Text = "Catch bag"
	invTitle.Parent = invPanel

	local collapseBagBtn = Instance.new("TextButton")
	collapseBagBtn.Name = "CollapseBag"
	collapseBagBtn.Size = UDim2.new(0, 32, 0, 32)
	collapseBagBtn.Position = UDim2.new(1, -152, 0, 9)
	collapseBagBtn.ZIndex = 2
	collapseBagBtn.BackgroundColor3 = palette.panel
	collapseBagBtn.BorderSizePixel = 0
	collapseBagBtn.Text = "−"
	collapseBagBtn.TextColor3 = palette.muted
	collapseBagBtn.Font = Enum.Font.GothamBold
	collapseBagBtn.TextSize = 20
	collapseBagBtn.AutoButtonColor = false
	collapseBagBtn.Active = true
	collapseBagBtn.Selectable = true
	collapseBagBtn.Parent = invPanel
	corner(8).Parent = collapseBagBtn
	stroke(1).Parent = collapseBagBtn

	local sellBtn = Instance.new("TextButton")
	sellBtn.Size = UDim2.new(0, 100, 0, 34)
	sellBtn.Position = UDim2.new(1, -110, 0, 8)
	sellBtn.ZIndex = 2
	sellBtn.BackgroundColor3 = palette.good
	sellBtn.BackgroundTransparency = 0.2
	sellBtn.Text = "Sell all"
	sellBtn.TextColor3 = palette.bg
	sellBtn.Font = Enum.Font.GothamBold
	sellBtn.TextSize = 15
	sellBtn.Parent = invPanel
	corner(8).Parent = sellBtn
	sellBtn.MouseButton1Click:Connect(function()
		SellFish:FireServer()
	end)

	local function applyBagListCollapse()
		invList.Visible = not bagListCollapsed
		invPanel.Size = UDim2.new(0, 360, 0, bagListCollapsed and bagCollapsedH or bagExpandedH)
		collapseBagBtn.Text = bagListCollapsed and "+" or "−"
		collapseBagBtn.TextColor3 = bagListCollapsed and palette.accent or palette.muted
	end

	collapseBagBtn.MouseButton1Click:Connect(function()
		bagListCollapsed = not bagListCollapsed
		applyBagListCollapse()
	end)

	applyBagListCollapse()

	local shopFrame = Instance.new("Frame")
	shopFrame.Size = UDim2.new(0, 420, 0, 420)
	shopFrame.Position = UDim2.new(0.5, -210, 0.5, -210)
	shopFrame.BackgroundColor3 = palette.bg
	shopFrame.BackgroundTransparency = 0.08
	shopFrame.Visible = false
	shopFrame.BorderSizePixel = 0
	shopFrame.Parent = root
	corner(14).Parent = shopFrame
	stroke(1).Parent = shopFrame

	local shopTitle = Instance.new("TextLabel")
	shopTitle.BackgroundTransparency = 1
	shopTitle.Size = UDim2.new(1, -50, 0, 28)
	shopTitle.Position = UDim2.new(0, 16, 0, 10)
	shopTitle.Font = Enum.Font.GothamBold
	shopTitle.TextSize = 20
	shopTitle.TextXAlignment = Enum.TextXAlignment.Left
	shopTitle.TextColor3 = palette.accent
	shopTitle.Text = "Dock shop"
	shopTitle.Parent = shopFrame

	local closeShop = Instance.new("TextButton")
	closeShop.Size = UDim2.new(0, 32, 0, 32)
	closeShop.Position = UDim2.new(1, -40, 0, 8)
	closeShop.BackgroundColor3 = palette.panel
	closeShop.Text = "X"
	closeShop.TextColor3 = palette.text
	closeShop.Font = Enum.Font.GothamBold
	closeShop.TextSize = 16
	closeShop.Parent = shopFrame
	corner(8).Parent = closeShop
	closeShop.MouseButton1Click:Connect(function()
		shopFrame.Visible = false
	end)

	local shopScroll = Instance.new("ScrollingFrame")
	shopScroll.Name = "ShopScroll"
	shopScroll.Size = UDim2.new(1, -24, 1, -52)
	shopScroll.Position = UDim2.new(0, 12, 0, 44)
	shopScroll.BackgroundTransparency = 1
	shopScroll.BorderSizePixel = 0
	shopScroll.ScrollBarThickness = 6
	shopScroll.Parent = shopFrame

	refs = {
		money = money,
		level = level,
		xpFill = xpFill,
		xpLabel = xpLabel,
		castBtn = castBtn,
		cooldownLabel = cooldownLabel,
		statusLabel = statusLabel,
		invList = invList,
		shopFrame = shopFrame,
		shopScroll = shopScroll,
		castPanel = mid,
		invPanel = invPanel,
	}

	local lakeX = tonumber(Config.LAKE_CENTER_X) or 0
	local lakeZ = tonumber(Config.LAKE_CENTER_Z) or 0
	local proxStuds = tonumber(Config.FISHING_UI_PROXIMITY_STUDS) or 500
	local proxSq = proxStuds * proxStuds

	local cachedHrp: BasePart? = nil

	local function horizontalDistSq(pos: Vector3): number
		-- World Z must use lakeZ — Vector2 only has .X/.Y (no .Z); the old lakeXZ.Z was always wrong/nil.
		local dx = pos.X - lakeX
		local dz = pos.Z - lakeZ
		return dx * dx + dz * dz
	end

	local function setFishingUiNearLake(near: boolean)
		local r2 = refs
		if not r2 then
			return
		end
		r2.castPanel.Visible = near
		-- Catch bag + shop button (and open shop window) are not gated by lake proximity.
	end

	local function getWorldPositionForProximity(): Vector3?
		if cachedHrp and cachedHrp.Parent then
			return cachedHrp.Position
		end
		local char = player.Character
		if not char then
			local cam = Workspace.CurrentCamera
			if cam then
				return cam.CFrame.Position
			end
			return nil
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			cachedHrp = hrp
			return hrp.Position
		end
		local torso = char:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			return torso.Position
		end
		local upper = char:FindFirstChild("UpperTorso")
		if upper and upper:IsA("BasePart") then
			return upper.Position
		end
		local head = char:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head.Position
		end
		if char:IsA("Model") then
			local pp = char.PrimaryPart
			if pp then
				return pp.Position
			end
		end
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "HumanoidRootPart" then
				cachedHrp = d
				return d.Position
			end
		end
		if char:IsA("Model") then
			local ok, pos = pcall(function()
				return char:GetPivot().Position
			end)
			if ok then
				return pos
			end
		end
		local cam = Workspace.CurrentCamera
		if cam then
			return cam.CFrame.Position
		end
		return nil
	end

	local function updateFishingProximity()
		local pos = getWorldPositionForProximity()
		if not pos then
			setFishingUiNearLake(false)
			return
		end
		setFishingUiNearLake(horizontalDistSq(pos) <= proxSq)
	end

	local function bindCharacterHrp(char: Model)
		task.defer(function()
			local hrp = char:WaitForChild("HumanoidRootPart", 20)
			if hrp and hrp:IsA("BasePart") and player.Character == char then
				cachedHrp = hrp
			end
			updateFishingProximity()
		end)
	end

	RunService.Heartbeat:Connect(updateFishingProximity)

	player.CharacterRemoving:Connect(function()
		cachedHrp = nil
	end)

	player.CharacterAdded:Connect(function(char)
		cachedHrp = nil
		if char:IsA("Model") then
			bindCharacterHrp(char)
		else
			task.defer(updateFishingProximity)
		end
	end)

	local existing = player.Character
	if existing and existing:IsA("Model") then
		bindCharacterHrp(existing)
	else
		task.defer(updateFishingProximity)
	end

	StateSync.OnClientEvent:Connect(function(payload)
		updateFishingProximity()
		applyState(payload)
	end)

	OpenShop.OnClientEvent:Connect(function()
		local r2 = refs
		if r2 then
			r2.shopFrame.Visible = true
		end
	end)

	CastFishing.OnClientEvent:Connect(function(msg: any)
		if typeof(msg) ~= "table" then
			return
		end
		local r2 = refs
		if not r2 then
			return
		end
		if msg.ok then
			local c = msg.catch
			if typeof(c) == "table" then
				lastCooldownDuration = (typeof(c.cooldown) == "number" and c.cooldown) or 3
				lastCooldownEnd = os.clock() + lastCooldownDuration
				local line = "Caught " .. tostring(c.fishName) .. " (tier " .. tostring(c.tier) .. "). +" .. tostring(c.xpGained) .. " XP."
				if c.genATierUp then
					line ..= " Gen-A upgraded the catch!"
				elseif c.genAMaxTierBonus then
					line ..= " Gen-A jackpot on a legendary catch!"
				end
				r2.statusLabel.Text = line
				r2.statusLabel.TextColor3 = palette.good
			end
		else
			local rem = msg.remaining
			if typeof(rem) == "number" then
				r2.cooldownLabel.Text = string.format("Wait %.1fs", rem)
			end
			r2.statusLabel.Text = (msg.err and tostring(msg.err)) or "Can't cast yet."
			r2.statusLabel.TextColor3 = palette.warn
		end
	end)

	SellFish.OnClientEvent:Connect(function(msg: any)
		local r2 = refs
		if not r2 then
			return
		end
		if typeof(msg) == "table" and msg.ok and typeof(msg.earned) == "number" then
			r2.statusLabel.Text = "Sold catch for " .. formatMoney(msg.earned) .. "."
			r2.statusLabel.TextColor3 = palette.good
		end
	end)

	PurchaseItem.OnClientEvent:Connect(function(msg: any)
		local r2 = refs
		if not r2 then
			return
		end
		if typeof(msg) == "table" then
			if msg.ok then
				r2.statusLabel.Text = "Purchase complete."
				r2.statusLabel.TextColor3 = palette.good
			elseif msg.err then
				r2.statusLabel.Text = tostring(msg.err)
				r2.statusLabel.TextColor3 = palette.warn
			end
		end
	end)

	task.spawn(function()
		while gui.Parent do
			local r2 = refs
			if r2 then
				local left = lastCooldownEnd - os.clock()
				if left > 0 then
					r2.cooldownLabel.Text = string.format("Reel ready in %.1fs", left)
					r2.castBtn.AutoButtonColor = false
					r2.castBtn.BackgroundTransparency = 0.5
				else
					r2.cooldownLabel.Text = ""
					r2.castBtn.AutoButtonColor = true
					r2.castBtn.BackgroundTransparency = 0.1
				end
			end
			task.wait(0.1)
		end
	end)

	return gui
end

return UI
