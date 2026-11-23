--!strict

export type RankRules = {
	MaxBasicRank: number,
	MaxUltimateRank: number,
	-- The hero level each R rank needs: index 1 is the first rank.
	UltimateLevels: { number },
}

local Module = {}

--[[
	Returns the level a total of experience reaches, the experience gained
	since that level, and the experience the next level needs (0 at the top
	level). xpPerLevel lists what each level needs, level 1 to 2 first.
]]
function Module.getLevel(xpPerLevel: { number }, totalXp: number): (number, number, number)
	local level = 1
	local remaining = totalXp
	for _, needed in xpPerLevel do
		if remaining < needed then
			return level, remaining, needed
		end
		remaining -= needed
		level += 1
	end
	return level, 0, 0
end

--[[
	Returns whether the ability in a slot can take another rank at a level.
	R ranks up only at its set levels. A basic ability can't be ranked past
	half the hero's level, rounded up, so no ability is maxed by level 4.
]]
function Module.canRankUp(
	slot: string,
	ranks: { [string]: number? },
	level: number,
	rules: RankRules
): boolean
	local rank = ranks[slot] or 0
	if slot == "R" then
		local requiredLevel = rules.UltimateLevels[rank + 1]
		return rank < rules.MaxUltimateRank and requiredLevel ~= nil and level >= requiredLevel
	end
	return rank < rules.MaxBasicRank and rank < math.ceil(level / 2)
end

--[[
	Returns the experience each of the heroes sharing a reward gets. Each
	hero past the first adds bonusPerExtra of the reward to the pool, so a
	duo lane is not left a level behind the solo lanes.
]]
function Module.getXpShare(xp: number, sharers: number, bonusPerExtra: number): number
	if sharers <= 0 then
		return 0
	end
	return xp * (1 + bonusPerExtra * (sharers - 1)) / sharers
end

--[[
	Returns the points a hero has left to spend: one per level, less the
	ranks already taken.
]]
function Module.getUnspentPoints(ranks: { [string]: number? }, level: number): number
	local spent = 0
	for _, rank in ranks do
		spent += rank or 0
	end
	return math.max(level - spent, 0)
end

--[[
	Picks the slot an automatic rank-up takes: R whenever it can, otherwise
	the first basic ability in skillOrder that can. Nil when none can.
]]
function Module.chooseAutoRank(
	skillOrder: { string },
	ranks: { [string]: number? },
	level: number,
	rules: RankRules
): string?
	if Module.canRankUp("R", ranks, level, rules) then
		return "R"
	end
	for _, slot in skillOrder do
		if Module.canRankUp(slot, ranks, level, rules) then
			return slot
		end
	end
	return nil
end

return Module
