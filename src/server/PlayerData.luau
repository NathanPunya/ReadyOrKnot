--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Progression = require(Shared:WaitForChild("Progression"))

local STORE_KEY = "ReadyOrKnot_Player_v1"
local store = DataStoreService:GetDataStore(STORE_KEY)

export type InventoryEntry = {
	fishId: string,
	-- When Gen-A hits on max-tier fish, extra sell value multiplier (e.g. 1.25)
	valueBonus: number?,
}

export type EquipmentState = {
	pole: string,
	bait: string,
	line: string,
	hook: string,
}

export type PlayerState = {
	money: number,
	totalXP: number,
	inventory: { InventoryEntry },
	equipment: EquipmentState,
}

local PlayerData = {}

local session: { [Player]: PlayerState } = {}

local function deepCopyEquipment(): EquipmentState
	local d = Config.DefaultEquipment
	return {
		pole = d.pole,
		bait = d.bait,
		line = d.line,
		hook = d.hook,
	}
end

local function defaultState(): PlayerState
	return {
		money = Config.StartingMoney,
		totalXP = 0,
		inventory = {},
		equipment = deepCopyEquipment(),
	}
end

local function sanitizeInventory(inv: any): { InventoryEntry }
	local out: { InventoryEntry } = {}
	if typeof(inv) ~= "table" then
		return out
	end
	for _, entry in inv do
		if typeof(entry) == "table" and typeof(entry.fishId) == "string" and Config.FishById[entry.fishId] then
			local vb = entry.valueBonus
			if typeof(vb) == "number" and vb > 1 then
				table.insert(out, { fishId = entry.fishId, valueBonus = vb })
			else
				table.insert(out, { fishId = entry.fishId })
			end
		end
	end
	return out
end

local function sanitizeEquipment(eq: any): EquipmentState
	local d = defaultState().equipment
	if typeof(eq) ~= "table" then
		return d
	end
	local function id(kind: string, fallback: string): string
		local v = eq[kind]
		if typeof(v) == "string" and Config.EquipmentById[v] and Config.EquipmentById[v].kind == kind then
			return v
		end
		return fallback
	end
	return {
		pole = id("pole", d.pole),
		bait = id("bait", d.bait),
		line = id("line", d.line),
		hook = id("hook", d.hook),
	}
end

function PlayerData.load(player: Player): PlayerState
	local key = "u" .. tostring(player.UserId)
	local loaded: any = nil
	local ok, err = pcall(function()
		loaded = store:GetAsync(key)
	end)
	if not ok then
		warn("[ReadyOrKnot] DataStore load failed:", err)
	end
	local state = defaultState()
	if typeof(loaded) == "table" then
		if typeof(loaded.money) == "number" then
			state.money = math.max(0, math.floor(loaded.money))
		end
		if typeof(loaded.totalXP) == "number" then
			state.totalXP = math.max(0, math.floor(loaded.totalXP))
		end
		state.inventory = sanitizeInventory(loaded.inventory)
		state.equipment = sanitizeEquipment(loaded.equipment)
	end
	session[player] = state
	return state
end

function PlayerData.save(player: Player)
	local st = session[player]
	if not st then
		return
	end
	local key = "u" .. tostring(player.UserId)
	local payload = {
		money = st.money,
		totalXP = st.totalXP,
		inventory = st.inventory,
		equipment = st.equipment,
	}
	local ok, err = pcall(function()
		store:SetAsync(key, payload)
	end)
	if not ok then
		warn("[ReadyOrKnot] DataStore save failed:", err)
	end
end

function PlayerData.get(player: Player): PlayerState?
	return session[player]
end

function PlayerData.syncPayload(state: PlayerState): { [string]: any }
	local level, xpIn, xpNeed = Progression.getLevelProgress(state.totalXP)
	return {
		money = state.money,
		totalXP = state.totalXP,
		level = level,
		xpInLevel = xpIn,
		xpForNext = xpNeed,
		inventory = state.inventory,
		equipment = state.equipment,
	}
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData.save(player)
	session[player] = nil
end)

game:BindToClose(function()
	for _, plr in Players:GetPlayers() do
		PlayerData.save(plr)
	end
end)

task.spawn(function()
	while true do
		task.wait(45)
		for _, plr in Players:GetPlayers() do
			PlayerData.save(plr)
		end
	end
end)

return PlayerData
