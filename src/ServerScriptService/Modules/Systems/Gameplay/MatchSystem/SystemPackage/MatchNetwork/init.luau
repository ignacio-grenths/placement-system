--!strict

local Module = {
	-- The server writes the match's state here as attributes for clients to
	-- read: Phase (MatchTypes.Phase), StartTime (server time the match clock
	-- starts), Winner (a team, or "" until the match ends), HeroPool (JSON
	-- array of MatchTypes.PoolHero), Picks (JSON array of MatchTypes.Pick,
	-- empty outside the Selecting phase), and SelectEndTime (server time
	-- hero selection ends, or 0 while players are still loading).
	MatchState = script.MatchState,
	-- Client to server: (hero id), choose that hero while selecting.
	PickHero = script.PickHero,
	-- Client to server: (), lock in the chosen hero.
	LockIn = script.LockIn,
	-- Client to server: (), the client has finished loading. The hero
	-- selection countdown waits for it.
	Loaded = script.Loaded,
}

return Module
