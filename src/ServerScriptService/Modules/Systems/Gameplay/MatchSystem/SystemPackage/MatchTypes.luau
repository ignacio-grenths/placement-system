--!strict

export type Team = "Blue" | "Red"
export type Phase = "Waiting" | "Playing" | "Ended"
export type Role = "Top" | "Jungle" | "Mid" | "Bot" | "Support"

-- One slot on a team, held by a player or, when no player holds it, a bot.
export type Participant = {
	-- Nil for a bot.
	Player: Player?,
	Name: string,
	Team: Team,
	Role: Role,
	HeroId: string,
	-- The participant's hero unit, once it has spawned.
	HeroUnitId: number?,
	Kills: number,
	Deaths: number,
}

-- One row of the scoreboard clients read from the MatchState attribute.
export type ScoreEntry = {
	-- 0 for a bot.
	UserId: number,
	Name: string,
	Team: Team,
	HeroId: string,
	Kills: number,
	Deaths: number,
}

return {}
