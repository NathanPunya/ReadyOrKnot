--!strict

export type FishDef = {
	id: string,
	name: string,
	tier: number,
	sellPrice: number,
	xp: number,
}

export type EquipKind = "pole" | "bait" | "line" | "hook"

export type EquipDef = {
	id: string,
	name: string,
	kind: EquipKind,
	tier: number,
	-- Rarity: higher = better odds for high-tier fish (additive weight scale)
	rarityWeightBonus: number,
	-- Multiplier on base cast cooldown (lower = faster casts)
	cooldownMult: number,
	-- Added to Gen-A chance (e.g. 0.02 = +2%)
	genABonus: number,
	-- Multiplier applied when selling fish
	sellValueMult: number,
	price: number,
}

local Config = {}

Config.GAME_NAME = "Ready Or Knot"

-- Lake hub on XZ; `TerrainSetup` reads these (single source of truth). Y is not used for the fishing UI gate.
Config.LAKE_CENTER_X = 168
Config.LAKE_CENTER_Z = 102
-- Cast / catch / shop: horizontal radius from that XZ point (studs), not water voxels — `horizontalDistSq <= radius^2`.
Config.FISHING_UI_PROXIMITY_STUDS = 180

-- Client: cast keybind + fishing visuals (Gamepad1 `ButtonX` in UI).
Config.CAST_LINE_KEYCODE = Enum.KeyCode.F

-- Client line / water buoyancy — keep in sync with `TerrainSetup` lake water column (surface Y and radius).
Config.LAKE_WATER_SURFACE_Y = 15
Config.LAKE_WATER_RADIUS = 150

Config.GEN_A_BASE_CHANCE = 0.03

Config.BASE_CAST_COOLDOWN = 3

Config.MIN_CAST_COOLDOWN = 1.2

Config.Fish = {} :: { FishDef }

Config.FishById = {} :: { [string]: FishDef }

Config.FishByTier = {} :: { [number]: { FishDef } }

Config.Equipment = {} :: { EquipDef }

Config.EquipmentById = {} :: { [string]: EquipDef }

Config.StartingMoney = 40

Config.DefaultEquipment = {
	pole = "pole_starter",
	bait = "bait_none",
	line = "line_basic",
	hook = "hook_standard",
}

local fishRows: { FishDef } = {
	{ id = "sprat", name = "Sprat", tier = 1, sellPrice = 4, xp = 3 },
	{ id = "minnow", name = "Minnow", tier = 1, sellPrice = 6, xp = 4 },
	{ id = "perch", name = "Yellow Perch", tier = 2, sellPrice = 14, xp = 8 },
	{ id = "bass", name = "Smallmouth Bass", tier = 2, sellPrice = 18, xp = 10 },
	{ id = "walleye", name = "Walleye", tier = 3, sellPrice = 35, xp = 18 },
	{ id = "pike", name = "Northern Pike", tier = 3, sellPrice = 42, xp = 22 },
	{ id = "salmon", name = "Silver Salmon", tier = 4, sellPrice = 85, xp = 40 },
	{ id = "tuna", name = "Bluefin Tuna", tier = 4, sellPrice = 110, xp = 48 },
	{ id = "marlin", name = "Blue Marlin", tier = 5, sellPrice = 220, xp = 85 },
	{ id = "shark", name = "Mako Shark", tier = 5, sellPrice = 280, xp = 100 },
}

for _, row in fishRows do
	table.insert(Config.Fish, row)
	Config.FishById[row.id] = row
	if not Config.FishByTier[row.tier] then
		Config.FishByTier[row.tier] = {}
	end
	table.insert(Config.FishByTier[row.tier], row)
end

local equipRows: { EquipDef } = {
	{
		id = "pole_starter",
		name = "Starter Rod",
		kind = "pole",
		tier = 1,
		rarityWeightBonus = 0,
		cooldownMult = 1,
		genABonus = 0,
		sellValueMult = 1,
		price = 0,
	},
	{
		id = "pole_bronze",
		name = "Bronze Rod",
		kind = "pole",
		tier = 2,
		rarityWeightBonus = 0.35,
		cooldownMult = 0.98,
		genABonus = 0.005,
		sellValueMult = 1,
		price = 120,
	},
	{
		id = "pole_steel",
		name = "Steel Rod",
		kind = "pole",
		tier = 3,
		rarityWeightBonus = 0.7,
		cooldownMult = 0.95,
		genABonus = 0.01,
		sellValueMult = 1,
		price = 320,
	},
	{
		id = "pole_carbon",
		name = "Carbon Rod",
		kind = "pole",
		tier = 4,
		rarityWeightBonus = 1.05,
		cooldownMult = 0.92,
		genABonus = 0.015,
		sellValueMult = 1,
		price = 750,
	},
	{
		id = "pole_mythic",
		name = "Mythic Rod",
		kind = "pole",
		tier = 5,
		rarityWeightBonus = 1.5,
		cooldownMult = 0.88,
		genABonus = 0.02,
		sellValueMult = 1,
		price = 1800,
	},
	{
		id = "bait_none",
		name = "No Bait",
		kind = "bait",
		tier = 1,
		rarityWeightBonus = 0,
		cooldownMult = 1,
		genABonus = 0,
		sellValueMult = 1,
		price = 0,
	},
	{
		id = "bait_worms",
		name = "Nightcrawlers",
		kind = "bait",
		tier = 2,
		rarityWeightBonus = 0.2,
		cooldownMult = 0.94,
		genABonus = 0.004,
		sellValueMult = 1,
		price = 45,
	},
	{
		id = "bait_minnows",
		name = "Live Minnows",
		kind = "bait",
		tier = 3,
		rarityWeightBonus = 0.45,
		cooldownMult = 0.9,
		genABonus = 0.008,
		sellValueMult = 1,
		price = 140,
	},
	{
		id = "bait_deluxe",
		name = "Deluxe Lure Pack",
		kind = "bait",
		tier = 4,
		rarityWeightBonus = 0.75,
		cooldownMult = 0.85,
		genABonus = 0.012,
		sellValueMult = 1,
		price = 420,
	},
	{
		id = "line_basic",
		name = "Basic Mono",
		kind = "line",
		tier = 1,
		rarityWeightBonus = 0,
		cooldownMult = 1,
		genABonus = 0,
		sellValueMult = 1,
		price = 0,
	},
	{
		id = "line_braided",
		name = "Braided Line",
		kind = "line",
		tier = 2,
		rarityWeightBonus = 0.1,
		cooldownMult = 1,
		genABonus = 0.012,
		sellValueMult = 1,
		price = 95,
	},
	{
		id = "line_fluoro",
		name = "Fluorocarbon",
		kind = "line",
		tier = 3,
		rarityWeightBonus = 0.18,
		cooldownMult = 1,
		genABonus = 0.022,
		sellValueMult = 1,
		price = 260,
	},
	{
		id = "hook_standard",
		name = "Standard Hook",
		kind = "hook",
		tier = 1,
		rarityWeightBonus = 0,
		cooldownMult = 1,
		genABonus = 0,
		sellValueMult = 1,
		price = 0,
	},
	{
		id = "hook_barbed",
		name = "Barbed Hook",
		kind = "hook",
		tier = 2,
		rarityWeightBonus = 0.05,
		cooldownMult = 1,
		genABonus = 0.003,
		sellValueMult = 1.06,
		price = 70,
	},
	{
		id = "hook_circle",
		name = "Circle Hook",
		kind = "hook",
		tier = 3,
		rarityWeightBonus = 0.1,
		cooldownMult = 1,
		genABonus = 0.006,
		sellValueMult = 1.12,
		price = 200,
	},
}

for _, row in equipRows do
	table.insert(Config.Equipment, row)
	Config.EquipmentById[row.id] = row
end

function Config.getEquipmentForKind(kind: EquipKind): { EquipDef }
	local out = {}
	for _, e in Config.Equipment do
		if e.kind == kind then
			table.insert(out, e)
		end
	end
	table.sort(out, function(a, b)
		return a.tier < b.tier
	end)
	return out
end

return Config
