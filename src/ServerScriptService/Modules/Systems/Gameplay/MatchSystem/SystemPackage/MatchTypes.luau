--!strict

export type Team = "Blue" | "Red"
export type Phase = "Waiting" | "Selecting" | "Playing" | "Ended"
export type Role = "Top" | "Jungle" | "Mid" | "Bot" | "Support"

-- A hero players may pick, and the role it plays.
export type PoolHero = {
	HeroId: string,
	Role: Role,
}

-- A player's choice during hero selection, as clients read it from the
-- MatchState attribute.
export type Pick = {
	UserId: number,
	Name: string,
	Team: Team,
	-- "" until the player chooses a hero.
	HeroId: string,
	IsLockedIn: boolean,
}

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
