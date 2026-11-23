--!strict

-- One buff a hero holds, as its owner's client is told.
export type BuffState = {
	-- A JungleCatalog.BuffInfo key, such as "Focus".
	Id: string,
	-- Server time (workspace:GetServerTimeNow()) it ends, or 0 if it lasts.
	ExpiresAt: number,
	Stacks: number,
}

local Module = {
	-- Server to a hero's owner: { BuffState }, every buff the hero holds.
	BuffsChanged = script.BuffsChanged,
	-- Server to every client: (boss kind, team that slew it).
	BossSlain = script.BossSlain,
}

return Module
