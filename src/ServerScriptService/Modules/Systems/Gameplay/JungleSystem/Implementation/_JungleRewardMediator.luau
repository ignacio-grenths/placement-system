--!strict

const RunService = game:GetService("RunService")

const AbilityServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityServerService"
)
const HeroServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/HeroSystem/SystemPackage/HeroServerService"
)
const JungleCatalog = require("@game/ServerScriptService/Modules/Data/JungleCatalog")
const MinionWaveServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MinionWaveSystem/SystemPackage/MinionWaveServerService"
)
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const JungleNetwork = require("../SystemPackage/JungleNetwork")
const JungleServerService = require("../SystemPackage/JungleServerService")

-- Seconds between two ticks of a burn.
const BURN_TICK = 0.5
const BUFF_RING_RADIUS = 4
const BUFF_RING_SECONDS = 0.8
const BOSS_KINDS = { Skyray = true, HiveQueen = true }

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type BuffState = JungleNetwork.BuffState
type DamageKind = UnitTypes.DamageKind
type Unit = UnitTypes.Unit

type Burn = {
	Source: Unit,
	-- os.clock() time the burn stops.
	EndsAt: number,
}

local Module = {}

-- os.clock() time each hero's Focus and Burn buffs end.
local focusHolders: { [Unit]: number? } = {}
local burnHolders: { [Unit]: number? } = {}
local burns: { [Unit]: Burn } = {}
-- By team: how many Skyrays it has slain, and when its Hive Call ends.
local skyrayStacks: { [string]: number? } = {}
local hiveCallEndsAt: { [string]: number? } = {}
local burnTimer = 0

local function showBuff(unit: Unit, buffId: string)
	local info = JungleCatalog.BuffInfo[buffId]
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = unit.Position,
		Radius = BUFF_RING_RADIUS,
		Color = if info then info.Color else Color3.new(1, 1, 1),
		Duration = BUFF_RING_SECONDS,
	})
end

--[[
	Tells a player's client every buff their hero holds, so the HUD can show
	them. Bot heroes have no one to tell.
]]
local function sendBuffs(hero: Unit)
	local player = hero.OwnerPlayer
	if not player then
		return
	end

	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local buffs: { BuffState } = {}
	local function addTimed(id: string, endsAt: number?)
		if endsAt and endsAt > now then
			table.insert(buffs, { Id = id, ExpiresAt = serverNow + endsAt - now, Stacks = 1 })
		end
	end
	addTimed("Focus", focusHolders[hero])
	addTimed("Burn", burnHolders[hero])
	addTimed("HiveCall", hiveCallEndsAt[hero.Team])
	local stacks = skyrayStacks[hero.Team] or 0
	if stacks > 0 then
		table.insert(buffs, { Id = "Skyray", ExpiresAt = 0, Stacks = stacks })
	end
	JungleNetwork.BuffsChanged:FireClient(player, buffs)
end

local function getTeamHeroes(team: string): { Unit }
	local heroes = {}
	for _, unit in UnitServerService:GetUnits() do
		if unit.Kind == "Hero" and unit.Team == team and not unit.IsRemoved then
			table.insert(heroes, unit)
		end
	end
	return heroes
end

local function addSkyrayStack(hero: Unit, stack: number)
	local bonus = JungleCatalog.Skyray
	UnitServerService:AddModifier(
		hero,
		`Jungle.Skyray{stack}.AttackDamage`,
		{ Stat = "AttackDamage", Add = bonus.AttackDamage },
		math.huge
	)
	UnitServerService:AddModifier(
		hero,
		`Jungle.Skyray{stack}.AbilityPower`,
		{ Stat = "AbilityPower", Add = bonus.AbilityPower },
		math.huge
	)
end

local function empowerMinion(minion: Unit, duration: number)
	local hiveCall = JungleCatalog.HiveCall
	UnitServerService:AddModifier(
		minion,
		"Jungle.HiveCall.AttackDamage",
		{ Stat = "AttackDamage", Multiply = hiveCall.AttackDamageMultiplier },
		duration
	)
	UnitServerService:AddModifier(
		minion,
		"Jungle.HiveCall.Armor",
		{ Stat = "Armor", Add = hiveCall.Armor },
		duration
	)
end

local function grantFocus(hero: Unit)
	local focus = JungleCatalog.Focus
	UnitServerService:AddModifier(
		hero,
		"Jungle.Focus",
		{ Stat = "AbilityHaste", Add = focus.AbilityHaste },
		focus.Duration
	)
	focusHolders[hero] = os.clock() + focus.Duration
	showBuff(hero, "Focus")
	sendBuffs(hero)
end

local function grantBurn(hero: Unit)
	burnHolders[hero] = os.clock() + JungleCatalog.Burn.Duration
	showBuff(hero, "Burn")
	sendBuffs(hero)
end

local function grantSkyray(team: string)
	local stack = (skyrayStacks[team] or 0) + 1
	skyrayStacks[team] = stack
	for _, hero in getTeamHeroes(team) do
		addSkyrayStack(hero, stack)
		showBuff(hero, "Skyray")
		sendBuffs(hero)
	end
end

local function startHiveCall(team: string)
	local duration = JungleCatalog.HiveCall.Duration
	hiveCallEndsAt[team] = os.clock() + duration
	for _, unit in UnitServerService:GetUnits() do
		if unit.Kind == "Minion" and unit.Team == team and not unit.IsRemoved then
			empowerMinion(unit, duration)
		end
	end
	for _, hero in getTeamHeroes(team) do
		showBuff(hero, "HiveCall")
		sendBuffs(hero)
	end
end

local function onCampCleared(_key: string, kind: string, killer: Unit?)
	if not killer then
		return
	end
	if BOSS_KINDS[kind] then
		JungleNetwork.BossSlain:FireAllClients(kind, killer.Team)
	end

	-- A buff goes to the hero who landed the last hit; the bosses reward the
	-- whole team, even when a clone or a burn finished them.
	local isHeroKill = killer.Kind == "Hero"
	if kind == "CrystalGolem" and isHeroKill then
		grantFocus(killer)
	elseif kind == "EmberBeetle" and isHeroKill then
		grantBurn(killer)
	elseif kind == "Skyray" then
		grantSkyray(killer.Team)
	elseif kind == "HiveQueen" then
		startHiveCall(killer.Team)
	end
end

local function onUnitDamaged(target: Unit, source: Unit?, _dealt: number, kind: DamageKind)
	if kind ~= "Attack" or not source or target.Kind == "Structure" then
		return
	end
	local endsAt = burnHolders[source]
	if not endsAt then
		return
	end
	local now = os.clock()
	if now >= endsAt then
		burnHolders[source] = nil
		return
	end

	local burn = JungleCatalog.Burn
	UnitServerService:AddModifier(
		target,
		"Jungle.BurnSlow",
		{ Stat = "MoveSpeed", Multiply = burn.SlowMultiplier },
		burn.SlowSeconds
	)
	burns[target] = {
		Source = source,
		EndsAt = now + burn.BurnSeconds,
	}
end

local function onUnitDied(unit: Unit)
	-- Buffs end with their holder, as every timed modifier does.
	burns[unit] = nil
	if unit.Kind == "Hero" then
		focusHolders[unit] = nil
		burnHolders[unit] = nil
		sendBuffs(unit)
	end
end

local function onMinionSpawned(minion: Unit)
	local endsAt = hiveCallEndsAt[minion.Team]
	if not endsAt then
		return
	end
	local remaining = endsAt - os.clock()
	if remaining > 0 then
		empowerMinion(minion, remaining)
	else
		hiveCallEndsAt[minion.Team] = nil
	end
end

local function onHeroSpawned(hero: Unit)
	-- A hero who joins after a Skyray fell still gets its team's stacks.
	for stack = 1, skyrayStacks[hero.Team] or 0 do
		addSkyrayStack(hero, stack)
	end
	sendBuffs(hero)
end

local function stepBurns(frameTime: number)
	burnTimer += frameTime
	if burnTimer < BURN_TICK then
		return
	end
	burnTimer -= BURN_TICK

	local now = os.clock()
	local damage = JungleCatalog.Burn.DamagePerSecond * BURN_TICK
	for unit, burn in burns do
		if unit.IsDead or unit.IsRemoved or now >= burn.EndsAt then
			burns[unit] = nil
			continue
		end
		local source = if burn.Source.IsRemoved then nil else burn.Source
		UnitServerService:ApplyDamage(unit, damage, source, "True")
	end
end

function Module:Init()
	JungleServerService.CampCleared:Connect(onCampCleared)
	UnitServerService.UnitDamaged:Connect(onUnitDamaged)
	UnitServerService.UnitDied:Connect(onUnitDied)
	MinionWaveServerService.MinionSpawned:Connect(onMinionSpawned)
	HeroServerService.HeroSpawned:Connect(onHeroSpawned)
end

function Module:Start()
	RunService.Heartbeat:Connect(stepBurns)
end

return Module
