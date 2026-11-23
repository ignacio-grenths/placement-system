--!strict

const RunService = game:GetService("RunService")

const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const VisionRules = require("./VisionRules")

-- Seconds between two updates of what each team sees.
const STEP_INTERVAL = 0.1

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Brush = VisionRules.Brush
type Team = UnitTypes.Team
type Unit = UnitTypes.Unit
type UnitKind = UnitTypes.UnitKind
type Viewer = VisionRules.Viewer

-- The teams that have sight. Neutral monsters fight whoever is near them.
const SIGHTED_TEAMS: { Team } = { "Blue", "Red" }

local Module = {}

local brushes: { Brush } = {}
local sightByKind: { [UnitKind]: number? } = {}
local alwaysSeenKinds: { [UnitKind]: boolean? } = {}
local damageRevealSeconds = 0
-- By team: the other teams' units it sees, rebuilt every step.
local seenUnits: { [Team]: { [Unit]: boolean? } } = { Blue = {}, Red = {} }
local viewersByTeam: { [Team]: { Viewer } } = { Blue = {}, Red = {} }
-- By unit, then by team: the os.clock() time a reveal ends.
local reveals: { [Unit]: { [Team]: number? }? } = {}
local playerTeams: { [Player]: Team? } = {}
local stepTimer = 0

local function isRevealed(unit: Unit, team: Team, now: number): boolean
	local byTeam = reveals[unit]
	local endsAt = if byTeam then byTeam[team] else nil
	return endsAt ~= nil and now < endsAt
end

local function rebuild()
	local now = os.clock()
	local units = UnitServerService:GetUnits()
	local unitBrushes: { [Unit]: number? } = {}
	table.clear(playerTeams)
	for _, team in SIGHTED_TEAMS do
		table.clear(viewersByTeam[team :: Team])
	end

	for _, unit in units do
		if unit.IsRemoved then
			continue
		end
		local brush = VisionRules.findBrush(brushes, unit.Position)
		unitBrushes[unit] = brush
		if unit.Kind == "Hero" and unit.OwnerPlayer then
			playerTeams[unit.OwnerPlayer] = unit.Team
		end

		local viewers = viewersByTeam[unit.Team]
		local sight = sightByKind[unit.Kind]
		if viewers and sight and not unit.IsDead then
			table.insert(viewers, { Position = unit.Position, Sight = sight, Brush = brush })
		end
	end

	for _, sightedTeam in SIGHTED_TEAMS do
		-- Annotated because luau-lsp types a loop over string literals as string.
		local team: Team = sightedTeam :: Team
		local seen = seenUnits[team]
		local viewers = viewersByTeam[team]
		table.clear(seen)
		for _, unit in units do
			if unit.IsRemoved or unit.Team == team then
				continue
			end
			if
				alwaysSeenKinds[unit.Kind]
				or isRevealed(unit, team, now)
				or VisionRules.canSee(viewers, unit.Position, unitBrushes[unit])
			then
				seen[unit] = true
			end
		end
	end
end

local function onHeartbeat(frameTime: number)
	stepTimer += frameTime
	if stepTimer < STEP_INTERVAL then
		return
	end
	stepTimer = 0
	debug.profilebegin("VisionServerService:Rebuild")
	rebuild()
	debug.profileend()
end

-- A hero that hits an enemy hero is seen by that hero's team for a moment,
-- so nobody fights back blind against a hidden attacker.
local function onUnitDamaged(target: Unit, source: Unit?)
	if
		damageRevealSeconds > 0
		and source
		and source.Kind == "Hero"
		and target.Kind == "Hero"
		and source.Team ~= target.Team
	then
		Module:Reveal(source, target.Team, damageRevealSeconds)
	end
end

local function onUnitRemoved(unit: Unit)
	reveals[unit] = nil
end

--[[
	Sets the brush patches. A unit in brush is seen only by enemies in the
	same patch, or by a reveal.
]]
function Module:SetBrushes(newBrushes: { Brush })
	brushes = table.clone(newBrushes)
end

--[[
	Sets how far units of a kind see, in studs. A kind without a sight gives
	its team no vision.
]]
function Module:SetSight(kind: UnitKind, studs: number)
	assert(studs > 0, "A sight range must be positive")
	sightByKind[kind] = studs
end

--[[
	Makes every unit of a kind visible to everyone, wherever it stands, like
	towers on a map that everybody knows.
]]
function Module:SetAlwaysSeen(kind: UnitKind)
	alwaysSeenKinds[kind] = true
end

--[[
	Sets the seconds a hero stays seen by the team of an enemy hero it
	damages. Zero turns it off.
]]
function Module:SetDamageReveal(seconds: number)
	damageRevealSeconds = math.max(seconds, 0)
end

--[[
	Shows a unit to a team for a while, wherever it is.
]]
function Module:Reveal(unit: Unit, team: Team, seconds: number)
	local byTeam: { [Team]: number? } = reveals[unit] or {}
	reveals[unit] = byTeam
	local endsAt = os.clock() + seconds
	byTeam[team] = math.max(byTeam[team] or 0, endsAt)

	local seen = seenUnits[team]
	if seen and unit.Team ~= team then
		seen[unit] = true
	end
end

function Module:IsVisibleTo(unit: Unit, team: Team): boolean
	local seen = seenUnits[team]
	return seen == nil or unit.Team == team or seen[unit] == true
end

function Module:IsPointVisibleTo(position: Vector3, team: Team): boolean
	local viewers = viewersByTeam[team]
	if not viewers then
		return true
	end
	return VisionRules.canSee(viewers, position, VisionRules.findBrush(brushes, position))
end

--[[
	Returns the team of the player's hero, or nil while the player has none.
]]
function Module:GetPlayerTeam(player: Player): Team?
	return playerTeams[player]
end

function Module:Init()
	UnitServerService.UnitDamaged:Connect(onUnitDamaged)
	UnitServerService.UnitRemoved:Connect(onUnitRemoved)
end

function Module:Start()
	RunService.Heartbeat:Connect(onHeartbeat)
end

return Module
