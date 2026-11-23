--!strict

local Module = {
	-- Server to the hero's owner: a HeroLevelTypes.LevelState.
	LevelStateChanged = script.LevelStateChanged,
	-- Client to server: (slot), spend a point on that ability.
	RankUpRequest = script.RankUpRequest,
	-- Client to server: (is on), whether points are spent automatically.
	AutoRankRequest = script.AutoRankRequest,
}

return Module
