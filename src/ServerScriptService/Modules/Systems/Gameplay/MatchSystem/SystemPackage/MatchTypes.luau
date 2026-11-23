--!strict

export type Team = "Blue" | "Red"
export type Phase = "Waiting" | "Playing" | "Ended"

export type Participant = {
	Player: Player,
	Team: Team,
	HeroId: string,
	Kills: number,
	Deaths: number,
}

-- One row of the scoreboard clients read from the MatchState attribute.
export type ScoreEntry = {
	UserId: number,
	Name: string,
	Team: Team,
	HeroId: string,
	Kills: number,
	Deaths: number,
}

return {}
