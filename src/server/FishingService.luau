--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: typeof(require(ReplicatedStorage.Shared.Config))
local PlayerData = require(script.Parent.PlayerData) :: typeof(require(script.Parent.PlayerData))

local tierBaseWeights = { 32, 26, 20, 14, 8 }

local FishingService = {}

local lastCastAt: { [Player]: number } = {}
local rngByPlayer: { [Player]: Random } = {}

local function getRng(player: Player): Random
	local r = rngByPlayer[player]
	if not r then
		r = Random.new()
		rngByPlayer[player] = r
	end
	return r
end

Players.PlayerRemoving:Connect(function(p)
	lastCastAt[p] = nil
	rngByPlayer[p] = nil
end)

local function getEquipBonus(state: any): (number, number, number)
	local e = state.equipment
	local pole = Config.EquipmentById[e.pole]
	local bait = Config.EquipmentById[e.bait]
	local line = Config.EquipmentById[e.line]
	local hook = Config.EquipmentById[e.hook]
	if not pole or not bait or not line or not hook then
		return 0, 0, 1
	end
	local rarity = pole.rarityWeightBonus + bait.rarityWeightBonus + line.rarityWeightBonus + hook.rarityWeightBonus
	local genA = pole.genABonus + bait.genABonus + line.genABonus + hook.genABonus
	local cd = pole.cooldownMult * bait.cooldownMult * line.cooldownMult * hook.cooldownMult
	return rarity, genA, cd
end

local function rollFishTier(rng: Random, rarityBonus: number): number
	local weights = {}
	local sum = 0
	for tier = 1, 5 do
		local w = tierBaseWeights[tier] * (1 + rarityBonus * (tier / 5))
		weights[tier] = w
		sum += w
	end
	local roll = rng:NextNumber() * sum
	local acc = 0
	for tier = 1, 5 do
		acc += weights[tier]
		if roll <= acc then
			return tier
		end
	end
	return 5
end

local function randomFishInTier(rng: Random, tier: number): Config.FishDef
	local list = Config.FishByTier[tier]
	local pick = list[rng:NextInteger(1, #list)]
	return pick
end

function FishingService.tryCast(player: Player): (boolean, string?, { [string]: any }?)
	local state = PlayerData.get(player)
	if not state then
		return false, "No data", nil
	end
	local rarityBonus, genABonus, cdMult = getEquipBonus(state)
	local cooldown = math.max(Config.MIN_CAST_COOLDOWN, Config.BASE_CAST_COOLDOWN * cdMult)
	local now = os.clock()
	local last = lastCastAt[player] or 0
	if now - last < cooldown then
		return false, "Cooldown", { remaining = cooldown - (now - last) }
	end

	local rng = getRng(player)
	local tier = rollFishTier(rng, rarityBonus)
	local fish = randomFishInTier(rng, tier)

	local genAChance = math.clamp(Config.GEN_A_BASE_CHANCE + genABonus, 0, 0.28)
	local genAProc = rng:NextNumber() < genAChance
	local finalFish = fish
	local genATierUp = false
	local maxTierBonus = false

	if genAProc then
		if fish.tier < 5 then
			local newTier = fish.tier + 1
			finalFish = randomFishInTier(rng, newTier)
			genATierUp = true
		else
			maxTierBonus = true
		end
	end

	local xpGain = finalFish.xp
	state.totalXP += xpGain

	local entry: PlayerData.InventoryEntry = { fishId = finalFish.id }
	if maxTierBonus then
		entry.valueBonus = 1.25
	end

	table.insert(state.inventory, entry)
	lastCastAt[player] = now

	return true, nil, {
		fishId = finalFish.id,
		fishName = finalFish.name,
		tier = finalFish.tier,
		xpGained = xpGain,
		genATierUp = genATierUp,
		genAMaxTierBonus = maxTierBonus,
		cooldown = cooldown,
	}
end

return FishingService
