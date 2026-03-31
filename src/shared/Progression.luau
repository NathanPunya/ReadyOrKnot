--!strict

local Progression = {}

function Progression.xpToAdvanceFromLevel(level: number): number
	return 100 * level
end

-- Returns current level (>=1), XP counted toward that level bar, XP needed to reach next level.
function Progression.getLevelProgress(totalXP: number): (number, number, number)
	local level = 1
	local xp = totalXP
	while true do
		local need = Progression.xpToAdvanceFromLevel(level)
		if xp < need then
			return level, xp, need
		end
		xp -= need
		level += 1
	end
end

return Progression
