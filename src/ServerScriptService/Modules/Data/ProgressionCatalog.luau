--!strict

export type UnitReward = {
	-- Paid to the hero who lands the killing blow.
	Gold: number,
	-- Shared among enemy heroes near the death.
	Xp: number,
}

local Module = {}

Module.MaxLevel = 15

-- Experience to go from each level to the next: index 1 is level 1 to 2.
-- Tuned so a hero in lane reaches 15 near the 18-minute mark.
Module.XpPerLevel = { 280, 380, 480, 580, 680, 780, 880, 980, 1080, 1180, 1280, 1380, 1480, 1580 }

-- Studs from a death within which enemy heroes share its experience.
Module.XpShareRadius = 30

-- Seconds dead at level 1, plus this many per level after.
Module.BaseRespawnSeconds = 6
Module.RespawnSecondsPerLevel = 2

Module.StartingGold = 500
-- Paid to every hero each second once the match clock passes PassiveGoldStart.
Module.PassiveGoldPerSecond = 2
Module.PassiveGoldStart = 60

-- A hero kill pays the killer this much gold and spreads this much
-- experience, plus HeroKillXpPerLevel for each of the victim's levels.
Module.HeroKillGold = 300
Module.HeroKillXp = 100
Module.HeroKillXpPerLevel = 25

-- Gold paid to every hero of the team that takes down an enemy structure.
Module.StructureTeamGold = 150

-- By unit type id. Units missing here give nothing.
Module.UnitRewards = {
	Zib = { Gold = 21, Xp = 75 },
	Blip = { Gold = 14, Xp = 40 },
	GrubTank = { Gold = 60, Xp = 110 },
	MegaZib = { Gold = 60, Xp = 110 },
} :: { [string]: UnitReward? }

-- Ability ranks: Q, W, and E go to 4, R to 3, and R can rank up only at
-- these levels.
Module.MaxBasicRank = 4
Module.MaxUltimateRank = 3
Module.UltimateLevels = { 6, 10, 14 }

return Module
