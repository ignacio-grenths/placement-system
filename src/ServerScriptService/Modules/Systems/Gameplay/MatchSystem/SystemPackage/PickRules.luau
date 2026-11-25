--!strict

const MatchTypes = require("./MatchTypes")

type Pick = MatchTypes.Pick
type PoolHero = MatchTypes.PoolHero
type Role = MatchTypes.Role

-- The hero and role a pick plays once selection ends.
export type Assignment = {
	HeroId: string,
	Role: Role,
}

local Module = {}

--[[
	Returns the role a hero plays, or nil when the pool lacks the hero.
]]
function Module.findRole(pool: { PoolHero }, heroId: string): Role?
	for _, hero in pool do
		if hero.HeroId == heroId then
			return hero.Role
		end
	end
	return nil
end

--[[
	Returns whether the pick's player may take the hero: it is in the pool,
	and no teammate has locked in a hero of its role. A teammate who only
	hovers a hero holds nothing.
]]
function Module.isHeroOpen(picks: { Pick }, pool: { PoolHero }, pick: Pick, heroId: string): boolean
	local role = Module.findRole(pool, heroId)
	if not role then
		return false
	end
	for _, other in picks do
		if
			other ~= pick
			and other.IsLockedIn
			and other.Team == pick.Team
			and Module.findRole(pool, other.HeroId) == role
		then
			return false
		end
	end
	return true
end

--[[
	Returns whether every pick's player has finished loading, keyed by user
	id.
]]
function Module.isEveryoneLoaded(picks: { Pick }, loadedUserIds: { [number]: boolean? }): boolean
	for _, pick in picks do
		if not loadedUserIds[pick.UserId] then
			return false
		end
	end
	return true
end

--[[
	Gives every pick a hero once selection ends, with one player per role on
	each team. Locked heroes come first, then hovered heroes in join order
	while their role is open, and everyone left gets the first pool hero
	whose role is still open on their team. Returns one assignment per pick,
	in pick order. The pool must not be empty.
]]
function Module.resolve(picks: { Pick }, pool: { PoolHero }): { Assignment }
	local byIndex: { [number]: Assignment } = {}
	local isRoleTaken: { [string]: boolean? } = {}

	local function isOpen(index: number, role: Role): boolean
		return not isRoleTaken[`{picks[index].Team}/{role}`]
	end

	local function assign(index: number, heroId: string, role: Role)
		byIndex[index] = { HeroId = heroId, Role = role }
		isRoleTaken[`{picks[index].Team}/{role}`] = true
	end

	local function assignChosen(state: "Locked" | "Hovered")
		for index, pick in picks do
			-- Annotated because luau-lsp widens the narrowed role to string.
			local role: Role? = Module.findRole(pool, pick.HeroId)
			if
				not byIndex[index]
				and pick.IsLockedIn == (state == "Locked")
				and role
				and isOpen(index, role)
			then
				assign(index, pick.HeroId, role)
			end
		end
	end

	assignChosen("Locked")
	assignChosen("Hovered")
	for index in picks do
		if not byIndex[index] then
			local fallback = pool[1]
			for _, hero in pool do
				if isOpen(index, hero.Role) then
					fallback = hero
					break
				end
			end
			assign(index, fallback.HeroId, fallback.Role)
		end
	end

	local assignments: { Assignment } = {}
	for index in picks do
		table.insert(assignments, byIndex[index])
	end
	return assignments
end

return Module
