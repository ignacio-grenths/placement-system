--!strict

-- Every third wave brings a siege minion.
const SIEGE_WAVE_PERIOD = 3
const MELEE_PER_WAVE = 3
const ARCHERS_PER_WAVE = 2
const CASTERS_PER_WAVE = 1

export type MinionRole = "Melee" | "Archer" | "Caster" | "Siege" | "Super"

export type Schedule = {
	-- Seconds after the match clock starts.
	FirstWaveTime: number,
	-- Seconds between waves.
	Interval: number,
}

local Module = {}

--[[
	Returns how many waves have left their bases by the given match time, in
	seconds since the match clock started.
]]
function Module.getWaveCount(schedule: Schedule, elapsed: number): number
	if elapsed < schedule.FirstWaveTime then
		return 0
	end
	return (elapsed - schedule.FirstWaveTime) // schedule.Interval + 1
end

--[[
	Returns one lane's wave in walking order: a super minion first while the
	enemy gate in that lane is down, then melee, the siege minion on every
	third wave, then archers and casters.
]]
function Module.getComposition(waveNumber: number, isEnemyGateDown: boolean): { MinionRole }
	local roles: { MinionRole } = {}
	if isEnemyGateDown then
		table.insert(roles, "Super")
	end
	for _ = 1, MELEE_PER_WAVE do
		table.insert(roles, "Melee")
	end
	if waveNumber % SIEGE_WAVE_PERIOD == 0 then
		table.insert(roles, "Siege")
	end
	for _ = 1, ARCHERS_PER_WAVE do
		table.insert(roles, "Archer")
	end
	for _ = 1, CASTERS_PER_WAVE do
		table.insert(roles, "Caster")
	end
	return roles
end

return Module
