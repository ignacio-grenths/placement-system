--!strict

export type Team = "Blue" | "Red"
export type Phase = "Waiting" | "Playing" | "Ended"

export type Participant = {
	Player: Player,
	Team: Team,
	HeroId: string,
}

return {}
