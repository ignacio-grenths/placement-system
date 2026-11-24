--!strict

local Module = {
	-- The server writes the match's state here as attributes for clients to
	-- read: Phase (MatchTypes.Phase), StartTime (server time the match clock
	-- starts), Winner (a team, or "" until the match ends), HeroPool (JSON
	-- array of MatchTypes.PoolHero), Picks (JSON array of MatchTypes.Pick,
	-- empty outside the Selecting phase), and SelectEndTime (server time
	-- hero selection ends).
	MatchState = script.MatchState,
	-- Client to server: (hero id), choose that hero while selecting.
	PickHero = script.PickHero,
	-- Client to server: (), lock in the chosen hero.
	LockIn = script.LockIn,
}

return Module
