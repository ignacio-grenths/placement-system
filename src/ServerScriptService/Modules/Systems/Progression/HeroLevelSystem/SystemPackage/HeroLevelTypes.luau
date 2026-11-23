--!strict

-- What a hero's player is told about its progress.
export type LevelState = {
	Level: number,
	MaxLevel: number,
	-- Experience gained since this level, and what the next level needs
	-- (0 at the top level).
	XpIntoLevel: number,
	XpForNext: number,
	UnspentPoints: number,
	-- Ranks of Q, W, E, and R.
	Ranks: { [string]: number },
	-- The slots that can take a point right now.
	CanRankUp: { [string]: boolean },
	IsAutoRanking: boolean,
}

return {}
