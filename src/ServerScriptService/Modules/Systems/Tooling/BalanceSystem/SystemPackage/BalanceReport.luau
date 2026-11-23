--!strict

-- How one hero did in one match.
export type HeroLine = {
	Team: string,
	Role: string,
	Hero: string,
	Kills: number,
	Deaths: number,
	Level: number,
	-- Damage dealt to enemy heroes.
	HeroDamage: number,
}

export type MatchReport = {
	-- "Blue", "Red", or "None" for a match that ran out of time.
	Winner: string,
	Minutes: number,
	Heroes: { HeroLine },
	-- By team: enemy structures it destroyed, and river bosses it slew.
	Structures: { [string]: number },
	Bosses: { [string]: number },
}

-- One hero's averages across every match it played that had a winner.
export type HeroSummary = {
	Hero: string,
	Games: number,
	Wins: number,
	WinRate: number,
	Kills: number,
	Deaths: number,
	Level: number,
	HeroDamage: number,
}

export type Summary = {
	-- Matches with a winner; timed-out matches are only counted.
	Matches: number,
	TimedOut: number,
	BlueWinRate: number,
	AverageMinutes: number,
	-- Best win rate first.
	Heroes: { HeroSummary },
}

local Module = {}

--[[
	Sums up a batch of balance-run matches: how often each side wins, how
	long matches last, and each hero's win rate and average line. A hero
	that appears twice in one match counts as two games.
]]
function Module.summarize(reports: { MatchReport }): Summary
	local decided = 0
	local timedOut = 0
	local blueWins = 0
	local totalMinutes = 0
	local byHero: { [string]: HeroSummary } = {}

	for _, report in reports do
		if report.Winner ~= "Blue" and report.Winner ~= "Red" then
			timedOut += 1
			continue
		end
		decided += 1
		totalMinutes += report.Minutes
		if report.Winner == "Blue" then
			blueWins += 1
		end

		for _, line in report.Heroes do
			local summary = byHero[line.Hero]
			if not summary then
				summary = {
					Hero = line.Hero,
					Games = 0,
					Wins = 0,
					WinRate = 0,
					Kills = 0,
					Deaths = 0,
					Level = 0,
					HeroDamage = 0,
				}
				byHero[line.Hero] = summary
			end
			summary.Games += 1
			summary.Wins += if line.Team == report.Winner then 1 else 0
			summary.Kills += line.Kills
			summary.Deaths += line.Deaths
			summary.Level += line.Level
			summary.HeroDamage += line.HeroDamage
		end
	end

	local heroes: { HeroSummary } = {}
	for _, summary in byHero do
		local games = summary.Games
		summary.WinRate = summary.Wins / games
		summary.Kills /= games
		summary.Deaths /= games
		summary.Level /= games
		summary.HeroDamage /= games
		table.insert(heroes, summary)
	end
	table.sort(heroes, function(first, second)
		if first.WinRate ~= second.WinRate then
			return first.WinRate > second.WinRate
		end
		return first.Hero < second.Hero
	end)

	return {
		Matches = decided,
		TimedOut = timedOut,
		BlueWinRate = if decided > 0 then blueWins / decided else 0,
		AverageMinutes = if decided > 0 then totalMinutes / decided else 0,
		Heroes = heroes,
	}
end

return Module
