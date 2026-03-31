--!strict

local Players = game:GetService("Players")
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

	local top = Instance.new("Frame")
	top.Size = UDim2.new(1, -40, 0, 108)
	top.Position = UDim2.new(0, 20, 0, 16)
	top.BackgroundColor3 = palette.bg
	top.BackgroundTransparency = 0.15
	top.BorderSizePixel = 0
	top.Parent = root
	corner(12).Parent = top
	stroke(1).Parent = top

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(0.5, 0, 0, 28)
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = palette.accent
	title.Text = Config.GAME_NAME
	title.Parent = top

	local money = Instance.new("TextLabel")
	money.BackgroundTransparency = 1
	money.Size = UDim2.new(0.45, -20, 0, 24)
	money.Position = UDim2.new(0.55, 0, 0, 12)
	money.Font = Enum.Font.GothamBold
	money.TextSize = 20
	money.TextColor3 = palette.good
	money.TextXAlignment = Enum.TextXAlignment.Right
	money.Text = formatMoney(0)
	money.Parent = top

	local level = Instance.new("TextLabel")
	level.BackgroundTransparency = 1
	level.Size = UDim2.new(0.35, 0, 0, 20)
	level.Position = UDim2.new(0, 16, 0, 44)
	level.Font = Enum.Font.GothamMedium
	level.TextSize = 16
	level.TextColor3 = palette.text
	level.TextXAlignment = Enum.TextXAlignment.Left
	level.Text = "Level 1"
	level.Parent = top

	local xpBack = Instance.new("Frame")
	xpBack.BackgroundColor3 = palette.panel
	xpBack.BorderSizePixel = 0
	xpBack.Size = UDim2.new(1, -32, 0, 14)
	xpBack.Position = UDim2.new(0, 16, 0, 72)
	xpBack.Parent = top
	corner(7).Parent = xpBack

	local xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.BackgroundColor3 = palette.accent
	xpFill.BorderSizePixel = 0
	xpFill.Size = UDim2.new(0, 0, 1, 0)
	xpFill.Parent = xpBack
	corner(7).Parent = xpFill

	local xpLabel = Instance.new("TextLabel")
	xpLabel.BackgroundTransparency = 1
	xpLabel.Size = UDim2.new(1, 0, 0, 18)
	xpLabel.Position = UDim2.new(0, 0, 0, 88)
	xpLabel.Font = Enum.Font.Gotham
	xpLabel.TextSize = 13
	xpLabel.TextColor3 = palette.muted
	xpLabel.Text = "0 / 100 XP"
	xpLabel.Parent = top

	local mid = Instance.new("Frame")
	mid.Size = UDim2.new(0, 320, 0, 200)
	mid.Position = UDim2.new(0.5, -160, 0.42, -100)
	mid.BackgroundColor3 = palette.bg
	mid.BackgroundTransparency = 0.1
	mid.BorderSizePixel = 0
	mid.Parent = root
	corner(14).Parent = mid
	stroke(1).Parent = mid

	local castBtn = Instance.new("TextButton")
	castBtn.Size = UDim2.new(1, -32, 0, 52)
	castBtn.Position = UDim2.new(0, 16, 0, 20)
	castBtn.BackgroundColor3 = palette.accent
	castBtn.Text = "Cast line"
	castBtn.TextColor3 = palette.bg
	castBtn.Font = Enum.Font.GothamBold
	castBtn.TextSize = 18
	castBtn.Parent = mid
	corner(10).Parent = castBtn

	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Size = UDim2.new(1, -32, 0, 20)
	cooldownLabel.Position = UDim2.new(0, 16, 0, 78)
	cooldownLabel.Font = Enum.Font.Gotham
	cooldownLabel.TextSize = 14
	cooldownLabel.TextColor3 = palette.muted
	cooldownLabel.Text = ""
	cooldownLabel.Parent = mid

	local statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Size = UDim2.new(1, -32, 0, 72)
	statusLabel.Position = UDim2.new(0, 16, 0, 108)
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 15
	statusLabel.TextColor3 = palette.text
	statusLabel.TextWrapped = true
	statusLabel.Text = "Catch fish, sell them, upgrade your kit."
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.Parent = mid

	castBtn.MouseButton1Click:Connect(function()
		CastFishing:FireServer()
	end)

	local invPanel = Instance.new("Frame")
	invPanel.Size = UDim2.new(0, 360, 0, 260)
	invPanel.Position = UDim2.new(0, 20, 1, -280)
	invPanel.BackgroundColor3 = palette.bg
	invPanel.BackgroundTransparency = 0.12
	invPanel.BorderSizePixel = 0
	invPanel.Parent = root
	corner(12).Parent = invPanel
	stroke(1).Parent = invPanel

	local invTitle = Instance.new("TextLabel")
	invTitle.BackgroundTransparency = 1
	invTitle.Size = UDim2.new(1, -120, 0, 26)
	invTitle.Position = UDim2.new(0, 14, 0, 8)
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextSize = 18
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.TextColor3 = palette.text
	invTitle.Text = "Catch bag"
	invTitle.Parent = invPanel

	local sellBtn = Instance.new("TextButton")
	sellBtn.Size = UDim2.new(0, 100, 0, 34)
	sellBtn.Position = UDim2.new(1, -110, 0, 8)
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

	local invList = Instance.new("ScrollingFrame")
	invList.Name = "List"
	invList.Size = UDim2.new(1, -24, 1, -52)
	invList.Position = UDim2.new(0, 12, 0, 44)
	invList.BackgroundTransparency = 1
	invList.BorderSizePixel = 0
	invList.ScrollBarThickness = 6
	invList.CanvasSize = UDim2.new(0, 0, 0, 0)
	invList.Parent = invPanel
	local invLayout = Instance.new("UIListLayout")
	invLayout.Padding = UDim.new(0, 6)
	invLayout.SortOrder = Enum.SortOrder.LayoutOrder
	invLayout.Parent = invList

	local shopToggle = Instance.new("TextButton")
	shopToggle.Size = UDim2.new(0, 120, 0, 40)
	shopToggle.Position = UDim2.new(1, -140, 0, 20)
	shopToggle.BackgroundColor3 = palette.panel
	shopToggle.Text = "Shop"
	shopToggle.TextColor3 = palette.text
	shopToggle.Font = Enum.Font.GothamBold
	shopToggle.TextSize = 16
	shopToggle.Parent = root
	corner(8).Parent = shopToggle
	stroke(1).Parent = shopToggle

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

	shopToggle.MouseButton1Click:Connect(function()
		shopFrame.Visible = not shopFrame.Visible
	end)

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
	}

	StateSync.OnClientEvent:Connect(function(payload)
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
