--!strict

local Module = {
	-- The server writes the match's state here as attributes for clients to
	-- read: Phase (MatchTypes.Phase), StartTime (server time the match clock
	-- starts), and Winner (a team, or "" until the match ends).
	MatchState = script.MatchState,
}

return Module
