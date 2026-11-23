--!strict

const Players = game:GetService("Players")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")
const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const HeroLevelNetwork = require("./HeroLevelNetwork")
const HeroLevelRules = require("./HeroLevelRules")

const SLOTS = { "Q", "W", "E", "R" }
-- Rank-up requests a client may send per second; a fast clicker sends a few.
const REQUESTS_PER_SECOND = 8

const HeroLevelTypes = require("./HeroLevelTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type LevelState = HeroLevelTypes.LevelState
type RankRules = HeroLevelRules.RankRules
type Unit = UnitTypes.Unit

type Progress = {
	Unit: Unit,
	TotalXp: number,
	Level: number,
	Ranks: { [string]: number },
	SkillOrder: { string },
	IsAutoRanking: boolean,
}

local Module = {}

-- (hero, new level)
Module.LevelChanged = Signal.new() :: Signal.Signal<Unit, number>
-- (hero, slot, new rank)
Module.RankChanged = Signal.new() :: Signal.Signal<Unit, string, number>

local xpPerLevel: { number } = {}
local rankRules: RankRules = {
	MaxBasicRank = 4,
	MaxUltimateRank = 3,
	UltimateLevels = { 6, 10, 14 },
}
local progressByUnit: { [Unit]: Progress? } = {}
local lastRequestTimes: { [Player]: number? } = {}

local function getMaxLevel(): number
	return #xpPerLevel + 1
end

local function publish(progress: Progress)
	local player = progress.Unit.OwnerPlayer
	if not player then
		return
	end

	local _, xpIntoLevel, xpForNext = HeroLevelRules.getLevel(xpPerLevel, progress.TotalXp)
	local canRankUp = {}
	local hasPoints = HeroLevelRules.getUnspentPoints(progress.Ranks, progress.Level) > 0
	for _, slot in SLOTS do
		canRankUp[slot] = hasPoints
			and HeroLevelRules.canRankUp(slot, progress.Ranks, progress.Level, rankRules)
	end

	local state: LevelState = {
		Level = progress.Level,
		MaxLevel = getMaxLevel(),
		XpIntoLevel = xpIntoLevel,
		XpForNext = xpForNext,
		UnspentPoints = HeroLevelRules.getUnspentPoints(progress.Ranks, progress.Level),
		Ranks = table.clone(progress.Ranks),
		CanRankUp = canRankUp,
		IsAutoRanking = progress.IsAutoRanking,
	}
	HeroLevelNetwork.LevelStateChanged:FireClient(player, state)
end

local function applyRank(progress: Progress, slot: string)
	local rank = (progress.Ranks[slot] or 0) + 1
	progress.Ranks[slot] = rank
	Module.RankChanged:Fire(progress.Unit, slot, rank)
end

local function spendAutoPoints(progress: Progress)
	while HeroLevelRules.getUnspentPoints(progress.Ranks, progress.Level) > 0 do
		local slot = HeroLevelRules.chooseAutoRank(
			progress.SkillOrder,
			progress.Ranks,
			progress.Level,
			rankRules
		)
		if not slot then
			return
		end
		applyRank(progress, slot)
	end
end

local function findProgress(player: Player): Progress?
	local hero = UnitServerService:FindOwnedHero(player)
	return if hero then progressByUnit[hero] else nil
end

local function isRequestAllowed(player: Player): boolean
	local now = SimClock.now()
	local last = lastRequestTimes[player]
	if last and now - last < 1 / REQUESTS_PER_SECOND then
		return false
	end
	lastRequestTimes[player] = now
	return true
end

local function onRankUpRequest(player: Player, slot: unknown)
	if typeof(slot) ~= "string" or not table.find(SLOTS, slot) or not isRequestAllowed(player) then
		return
	end
	local progress = findProgress(player)
	if progress then
		Module:SpendPoint(progress.Unit, slot)
	end
end

local function onAutoRankRequest(player: Player, isOn: unknown)
	if typeof(isOn) ~= "boolean" or not isRequestAllowed(player) then
		return
	end
	local progress = findProgress(player)
	if progress then
		Module:SetAutoRanking(progress.Unit, isOn)
	end
end

local function onPlayerRemoving(player: Player)
	lastRequestTimes[player] = nil
end

--[[
	Sets the experience each level needs, level 1 to 2 first. The top level
	is one past the end of the list.
]]
function Module:SetXpCurve(curve: { number })
	xpPerLevel = table.clone(curve)
end

function Module:SetRankRules(rules: RankRules)
	rankRules = rules
end

--[[
	Starts tracking a hero at level 1 with no ranks. skillOrder is the basic
	abilities' order for automatic ranks.
]]
function Module:Track(hero: Unit, skillOrder: { string })
	local progress: Progress = {
		Unit = hero,
		TotalXp = 0,
		Level = 1,
		Ranks = { Q = 0, W = 0, E = 0, R = 0 },
		SkillOrder = table.clone(skillOrder),
		IsAutoRanking = false,
	}
	progressByUnit[hero] = progress
	publish(progress)
end

function Module:Untrack(hero: Unit)
	progressByUnit[hero] = nil
end

function Module:GetLevel(hero: Unit): number
	local progress = progressByUnit[hero]
	return if progress then progress.Level else 1
end

function Module:GrantXp(hero: Unit, amount: number)
	local progress = progressByUnit[hero]
	if not progress or amount <= 0 then
		return
	end

	local previousLevel = progress.Level
	progress.TotalXp += amount
	progress.Level = HeroLevelRules.getLevel(xpPerLevel, progress.TotalXp)
	if progress.Level ~= previousLevel then
		Module.LevelChanged:Fire(hero, progress.Level)
		if progress.IsAutoRanking then
			spendAutoPoints(progress)
		end
	end
	publish(progress)
end

--[[
	Spends a point on the ability in a slot. Returns false when the hero has
	no point to spend or the ability can't rank up yet.
]]
function Module:SpendPoint(hero: Unit, slot: string): boolean
	local progress = progressByUnit[hero]
	if
		not progress
		or HeroLevelRules.getUnspentPoints(progress.Ranks, progress.Level) <= 0
		or not HeroLevelRules.canRankUp(slot, progress.Ranks, progress.Level, rankRules)
	then
		return false
	end

	applyRank(progress, slot)
	publish(progress)
	return true
end

function Module:SetAutoRanking(hero: Unit, isOn: boolean)
	local progress = progressByUnit[hero]
	if not progress then
		return
	end
	progress.IsAutoRanking = isOn
	if isOn then
		spendAutoPoints(progress)
	end
	publish(progress)
end

function Module:Init()
	HeroLevelNetwork.RankUpRequest.OnServerEvent:Connect(onRankUpRequest)
	HeroLevelNetwork.AutoRankRequest.OnServerEvent:Connect(onAutoRankRequest)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	UnitServerService.UnitRemoved:Connect(function(unit)
		progressByUnit[unit] = nil
	end)
end

return Module
