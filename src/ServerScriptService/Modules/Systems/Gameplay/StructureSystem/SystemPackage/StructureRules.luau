--!strict

const exhaustiveMatch = require("@game/ServerScriptService/Modules/Utilities/exhaustiveMatch")

export type Tier = "Outer" | "Inner" | "Gate" | "Core"

export type TargetCandidate = {
	Id: number,
	IsHero: boolean,
	-- True for a hero who just hit an allied hero.
	IsAggressor: boolean,
	Distance: number,
}

local Module = {}

local function getPriority(candidate: TargetCandidate): number
	if candidate.IsAggressor then
		return 1
	elseif not candidate.IsHero then
		return 2
	else
		return 3
	end
end

local function isBetter(candidate: TargetCandidate, best: TargetCandidate): boolean
	local candidatePriority = getPriority(candidate)
	local bestPriority = getPriority(best)
	if candidatePriority ~= bestPriority then
		return candidatePriority < bestPriority
	end
	return candidate.Distance < best.Distance
end

--[[
	Returns whether a structure can take damage, given which of its team's
	structures are down. Each lane falls outer tower, inner tower, then gate,
	and the core opens while any gate is down.
]]
function Module.isExposed(
	tier: Tier,
	lane: string?,
	isDown: (lane: string, tier: Tier) -> boolean,
	lanes: { string }
): boolean
	if tier == "Outer" then
		return true
	elseif tier == "Inner" then
		return lane ~= nil and isDown(lane, "Outer")
	elseif tier == "Gate" then
		return lane ~= nil and isDown(lane, "Inner")
	elseif tier == "Core" then
		for _, laneName in lanes do
			if isDown(laneName, "Gate") then
				return true
			end
		end
		return false
	else
		return exhaustiveMatch(tier)
	end
end

--[[
	Picks a tower's target: a hero who just hit an allied hero first, then
	aliens, then other heroes, nearest first within each. The current target
	is kept unless a higher-priority one is in range.
]]
function Module.chooseTowerTarget(
	candidates: { TargetCandidate },
	currentTargetId: number?
): number?
	local best: TargetCandidate? = nil
	local current: TargetCandidate? = nil
	for _, candidate in candidates do
		if candidate.Id == currentTargetId then
			current = candidate
		end
		if not best or isBetter(candidate, best) then
			best = candidate
		end
	end

	if current and best and getPriority(current) <= getPriority(best) then
		return current.Id
	end
	return if best then best.Id else nil
end

return Module
