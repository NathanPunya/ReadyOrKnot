--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- init.server.luau turns the parent folder into this Script; modules are *children* of script, not script.Parent.
-- Terrain runs first so it always generates even if another module fails to load later.
local TerrainSetup = require(script:WaitForChild("TerrainSetup"))
local WorldBuild = require(script:WaitForChild("WorldBuild"))
local LakeDecor = require(script:WaitForChild("LakeDecor"))

local lakeInfo: any = nil
local terrainOk, terrainErr = pcall(function()
	lakeInfo = TerrainSetup.build()
end)
if terrainOk then
	print("[ReadyOrKnot] Terrain generated (visible after Play; Edit mode won't run this).")
	if lakeInfo then
		local openShop = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OpenShop") :: RemoteEvent
		WorldBuild.build(lakeInfo, openShop)
		LakeDecor.build(lakeInfo)
	end
else
	warn("[ReadyOrKnot] Terrain failed:", terrainErr)
end

local PlayerData = require(script:WaitForChild("PlayerData"))
local FishingService = require(script:WaitForChild("FishingService"))
local ShopService = require(script:WaitForChild("ShopService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CastFishing = Remotes:WaitForChild("CastFishing") :: RemoteEvent
local SellFish = Remotes:WaitForChild("SellFish") :: RemoteEvent
local PurchaseItem = Remotes:WaitForChild("PurchaseItem") :: RemoteEvent
local StateSync = Remotes:WaitForChild("StateSync") :: RemoteEvent

local function pushState(player: Player)
	local st = PlayerData.get(player)
	if st then
		StateSync:FireClient(player, PlayerData.syncPayload(st))
	end
end

Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
	pushState(player)
end)

for _, player in Players:GetPlayers() do
	PlayerData.load(player)
	pushState(player)
end

CastFishing.OnServerEvent:Connect(function(player: Player)
	local ok, err, payload = FishingService.tryCast(player)
	if ok then
		local st = PlayerData.get(player)
		if st then
			StateSync:FireClient(player, PlayerData.syncPayload(st))
		end
		CastFishing:FireClient(player, { ok = true, catch = payload })
	else
		CastFishing:FireClient(player, { ok = false, err = err, remaining = payload and payload.remaining })
	end
end)

SellFish.OnServerEvent:Connect(function(player: Player)
	local ok, err, earned = ShopService.sellAll(player)
	if ok then
		local st = PlayerData.get(player)
		if st then
			StateSync:FireClient(player, PlayerData.syncPayload(st))
		end
		SellFish:FireClient(player, { ok = true, earned = earned })
	else
		SellFish:FireClient(player, { ok = false, err = err })
	end
end)

PurchaseItem.OnServerEvent:Connect(function(player: Player, itemId: any)
	if typeof(itemId) ~= "string" then
		PurchaseItem:FireClient(player, { ok = false, err = "Bad request" })
		return
	end
	local ok, err = ShopService.purchase(player, itemId)
	local st = PlayerData.get(player)
	if st then
		StateSync:FireClient(player, PlayerData.syncPayload(st))
	end
	PurchaseItem:FireClient(player, { ok = ok, err = err })
end)
