--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: typeof(require(ReplicatedStorage.Shared.Config))
local PlayerData = require(script.Parent.PlayerData) :: typeof(require(script.Parent.PlayerData))

local ShopService = {}

function ShopService.sellAll(player: Player): (boolean, string?, number?)
	local state = PlayerData.get(player)
	if not state then
		return false, "No data", nil
	end
	local hook = Config.EquipmentById[state.equipment.hook]
	local mult = hook and hook.sellValueMult or 1
	local total = 0
	for _, entry in state.inventory do
		local fish = Config.FishById[entry.fishId]
		if fish then
			local vb = entry.valueBonus
			local piece = fish.sellPrice * mult
			if typeof(vb) == "number" and vb > 1 then
				piece *= vb
			end
			total += math.floor(piece + 0.5)
		end
	end
	state.money += total
	table.clear(state.inventory)
	return true, nil, total
end

function ShopService.purchase(player: Player, itemId: string): (boolean, string?)
	local state = PlayerData.get(player)
	if not state then
		return false, "No data"
	end
	local item = Config.EquipmentById[itemId]
	if not item then
		return false, "Unknown item"
	end
	if item.price <= 0 then
		return false, "Not for sale"
	end
	if state.money < item.price then
		return false, "Not enough money"
	end
	local kind = item.kind
	local currentId = state.equipment[kind]
	local current = Config.EquipmentById[currentId]
	if current and item.tier < current.tier then
		return false, "You already own better gear"
	end
	if currentId == itemId then
		return false, "Already owned"
	end
	state.money -= item.price
	state.equipment[kind] = itemId
	return true, nil
end

return ShopService
