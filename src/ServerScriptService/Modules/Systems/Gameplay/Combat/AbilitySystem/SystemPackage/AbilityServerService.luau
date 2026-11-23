--!strict

const Players = game:GetService("Players")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")
const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityNetwork = require("./AbilityNetwork")
const AbilityRules = require("./AbilityRules")

-- Casts a client may request per second on average, and in one burst.
const CASTS_PER_SECOND = 10
const CAST_BURST = 15
-- Unit ids travel as unsigned 16-bit values.
const MAX_UNIT_ID = 65535
const SLOTS = { "Q", "W", "E", "R", "D", "F", "T", "B" }

const AbilityTypes = require("./AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type AbilityHandler = AbilityTypes.AbilityHandler
type AbilityInfo = AbilityTypes.AbilityInfo
type Aim = AbilityTypes.Aim
type CastContext = AbilityTypes.CastContext
type DamageKind = UnitTypes.DamageKind
type Effect = AbilityTypes.Effect
type Order = UnitTypes.Order
type ResourceProfile = AbilityTypes.ResourceProfile
type Slot = AbilityTypes.Slot
type TargetFilter = AbilityTypes.TargetFilter
type Targeting = AbilityTypes.Targeting
type Unit = UnitTypes.Unit

export type AbilityDefinition = {
	Name: string,
	Description: string,
	Cooldown: number,
	Cost: number,
	Targeting: Targeting,
	Range: number,
	TargetFilter: TargetFilter?,
	Values: RankedValues,
}

export type ChannelOptions = {
	-- Shown to the caster's player while the channel runs.
	Name: string,
	-- Seconds.
	Duration: number,
	-- Any new order (a move, a stop) ends the channel early.
	CancelOnOrder: boolean?,
	-- Damage from an enemy ends the channel early.
	CancelOnDamage: boolean?,
	-- The caster can't move during the channel.
	IsRooted: boolean?,
	OnComplete: () -> (),
}

export type SkillshotOptions = {
	Origin: Vector3,
	-- Flat and of length 1.
	Direction: Vector3,
	-- Studs per second.
	Speed: number,
	Range: number,
	Width: number,
	Color: Color3,
	Filter: TargetFilter,
	-- When false, the shot stops at the first unit it hits.
	Pierces: boolean?,
	OnHit: (Unit) -> (),
}

type RankedValues = AbilityTypes.RankedValues

type RegisteredAbility = {
	Info: AbilityInfo,
	Values: RankedValues,
	Handler: AbilityHandler,
}

type Channel = {
	Options: ChannelOptions,
	EndsAt: number,
	-- The order the channel started with. Any other order cancels it.
	Order: Order,
}

type CasterState = {
	Loadout: { [Slot]: string? },
	-- A slot with no rank here casts at rank 1, like summoner spells. A slot
	-- at rank 0 is not learned yet.
	Ranks: { [Slot]: number? },
	CooldownEnds: { [Slot]: number? },
	-- Seconds each slot's last cooldown ran from its start, for clients.
	CooldownLengths: { [Slot]: number? },
	Profile: ResourceProfile,
	LastSpendTime: number,
	Channel: Channel?,
}

type Skillshot = {
	Caster: Unit,
	Options: SkillshotOptions,
	Position: Vector3,
	Traveled: number,
	HitIds: { [number]: boolean? },
}

type Bucket = {
	Tokens: number,
	LastTime: number,
}

local Module = {}

-- (caster, slot, the cooldown it started in seconds) after every cast.
Module.AbilityCast = Signal.new() :: Signal.Signal<Unit, Slot, number>

local abilities: { [string]: RegisteredAbility? } = {}
local casters: { [Unit]: CasterState? } = {}
local skillshots: { Skillshot } = {}
local buckets: { [Player]: Bucket? } = {}

local function takeToken(player: Player): boolean
	-- Requests arrive in real time, whatever speed the simulation runs at.
	local now = os.clock()
	local bucket: Bucket = buckets[player] or { Tokens = CAST_BURST, LastTime = now }
	buckets[player] = bucket

	bucket.Tokens = math.min(bucket.Tokens + (now - bucket.LastTime) * CASTS_PER_SECOND, CAST_BURST)
	bucket.LastTime = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

-- Clients read times in server time, while this service keeps SimClock time.
local function toServerTime(clockTime: number): number
	return SimClock.serverTime() + (clockTime - SimClock.now())
end

local function getFacingDirection(unit: Unit): Vector3
	return Vector3.new(-math.sin(unit.Facing), 0, -math.cos(unit.Facing))
end

local function endChannel(unit: Unit, state: CasterState)
	state.Channel = nil
	unit.IsChanneling = false
	if unit.OwnerPlayer then
		AbilityNetwork.ChannelChanged:FireClient(unit.OwnerPlayer, "", 0)
	end
end

local function resolveAim(unit: Unit, info: AbilityInfo, aim: Aim?): (Vector3?, Vector3?, Unit?)
	local facing = getFacingDirection(unit)
	if info.Targeting == "Self" then
		return unit.Position, facing, nil
	elseif info.Targeting == "Unit" then
		local targetId = if aim then aim.TargetId else nil
		local target = if targetId then UnitServerService:GetUnit(targetId) else nil
		local filter: TargetFilter = info.TargetFilter or "EnemyUnit"
		if
			not target
			or target.IsDead
			or not target.IsTargetable
			or not UnitServerService:IsVisibleTo(target, unit.Team)
			or not AbilityRules.matchesFilter(unit.Team, target.Team, target.Kind, filter)
		then
			return nil, nil, nil
		end
		local gap = (target.Position - unit.Position).Magnitude
			- unit.Stats.Radius
			- target.Stats.Radius
		if gap > info.Range then
			return nil, nil, nil
		end
		local _, direction =
			AbilityRules.clampAim(unit.Position, target.Position, math.huge, facing)
		return target.Position, direction, target
	else
		local requested = if aim then aim.Point else unit.Position + facing * info.Range
		local aimPoint, direction =
			AbilityRules.clampAim(unit.Position, requested, info.Range, facing)
		return aimPoint, direction, nil
	end
end

local function stepResources(dt: number, now: number)
	for unit, state in casters do
		if not state or unit.IsDead then
			continue
		end
		local regenerated = AbilityRules.regenerate(
			state.Profile,
			unit.Resource,
			unit.MaxResource,
			dt,
			now - state.LastSpendTime
		)
		if regenerated ~= unit.Resource then
			UnitServerService:SetResource(unit, regenerated)
		end
	end
end

local function stepChannels(now: number)
	for unit, state in casters do
		local channel = if state then state.Channel else nil
		if not state or not channel then
			continue
		end

		local isInterrupted = unit.IsDead
			or unit.IsRemoved
			or now < unit.StunnedUntil
			or (channel.Options.CancelOnOrder == true and unit.Order ~= channel.Order)
		if isInterrupted then
			endChannel(unit, state)
		elseif now >= channel.EndsAt then
			endChannel(unit, state)
			task.spawn(channel.Options.OnComplete)
		end
	end
end

local function stepSkillshots(dt: number)
	for index = #skillshots, 1, -1 do
		local shot = skillshots[index]
		local options = shot.Options
		local stepLength = math.min(options.Speed * dt, options.Range - shot.Traveled)
		shot.Position += options.Direction * stepLength
		shot.Traveled += stepLength
		local isFinished = shot.Traveled >= options.Range

		local hits = UnitServerService:FindInRadius(
			shot.Position,
			options.Width / 2,
			function(other)
				return not shot.HitIds[other.Id]
					and other.IsTargetable
					and AbilityRules.matchesFilter(
						shot.Caster.Team,
						other.Team,
						other.Kind,
						options.Filter
					)
			end
		)
		for _, hit in hits do
			shot.HitIds[hit.Id] = true
			task.spawn(options.OnHit, hit)
			if not options.Pierces then
				isFinished = true
				break
			end
		end

		if isFinished then
			skillshots[index] = skillshots[#skillshots]
			skillshots[#skillshots] = nil
		end
	end
end

local function step(frameTime: number)
	local now = SimClock.now()
	stepResources(frameTime, now)
	stepChannels(now)
	stepSkillshots(frameTime)
end

local function onCastRequest(
	player: Player,
	slot: unknown,
	x: unknown,
	z: unknown,
	targetId: unknown
)
	if typeof(slot) ~= "string" or not table.find(SLOTS, slot) then
		return
	end
	-- x ~= x catches NaN, and the huge checks catch infinity.
	if
		typeof(x) ~= "number"
		or typeof(z) ~= "number"
		or x ~= x
		or z ~= z
		or math.abs(x) == math.huge
		or math.abs(z) == math.huge
	then
		return
	end
	local checkedTargetId: number? = nil
	if targetId ~= nil then
		if
			typeof(targetId) ~= "number"
			or targetId ~= math.floor(targetId)
			or targetId < 1
			or targetId > MAX_UNIT_ID
		then
			return
		end
		checkedTargetId = targetId
	end
	if not takeToken(player) then
		return
	end

	local hero = UnitServerService:FindOwnedHero(player)
	if hero then
		Module:Cast(hero, slot :: Slot, {
			Point = Vector3.new(x, 0, z),
			TargetId = checkedTargetId,
		})
	end
end

local function onUnitDamaged(target: Unit, source: Unit?, _dealt: number, kind: DamageKind)
	local targetState = casters[target]
	local channel = if targetState then targetState.Channel else nil
	if
		targetState
		and channel
		and channel.Options.CancelOnDamage
		and source
		and source.Team ~= target.Team
	then
		endChannel(target, targetState)
	end

	-- Stamina heroes get some back for landing basic attacks on heroes.
	if source and kind == "Attack" and target.Kind == "Hero" then
		local sourceState = casters[source]
		if sourceState and sourceState.Profile.RestoreOnHeroHit > 0 then
			UnitServerService:RestoreResource(source, sourceState.Profile.RestoreOnHeroHit)
		end
	end
end

local function onUnitRemoved(unit: Unit)
	casters[unit] = nil
end

local function onPlayerRemoving(player: Player)
	buckets[player] = nil
end

--[[
	Makes an ability castable by id. The handler runs on each valid cast and
	reads its tuning numbers from context.Values.
]]
function Module:RegisterAbility(
	abilityId: string,
	definition: AbilityDefinition,
	handler: AbilityHandler
)
	abilities[abilityId] = {
		Info = {
			Id = abilityId,
			Name = definition.Name,
			Description = definition.Description,
			Cooldown = definition.Cooldown,
			Cost = definition.Cost,
			Targeting = definition.Targeting,
			Range = definition.Range,
			TargetFilter = definition.TargetFilter,
		},
		Values = definition.Values,
		Handler = handler,
	}
end

--[[
	Gives a unit its abilities by slot and the resource that pays for them,
	and tells the unit's player what is in each slot.
]]
function Module:SetupCaster(unit: Unit, loadout: { [Slot]: string? }, profile: ResourceProfile)
	casters[unit] = {
		Loadout = table.clone(loadout),
		Ranks = {},
		CooldownEnds = {},
		CooldownLengths = {},
		Profile = profile,
		LastSpendTime = 0,
		Channel = nil,
	}

	local player = unit.OwnerPlayer
	if player then
		local infos: { [Slot]: AbilityInfo? } = {}
		for slot, abilityId in loadout do
			local ability = if abilityId then abilities[abilityId] else nil
			if ability then
				infos[slot :: Slot] = ability.Info
			else
				warn(`No ability is registered as {abilityId} for slot {slot}`)
			end
		end
		AbilityNetwork.LoadoutChanged:FireClient(player, infos)
	end
end

function Module:RemoveCaster(unit: Unit)
	casters[unit] = nil
end

--[[
	Returns what the ability in a unit's slot is, or nil for an empty slot.
	Bots read it to know how to aim.
]]
function Module:GetAbilityInfo(unit: Unit, slot: Slot): AbilityInfo?
	local state = casters[unit]
	local abilityId = if state then state.Loadout[slot] else nil
	local ability = if abilityId then abilities[abilityId] else nil
	return if ability then ability.Info else nil
end

--[[
	Sets the rank a slot's ability casts at. Rank 0 means not learned, and the
	slot refuses to cast.
]]
function Module:SetRank(unit: Unit, slot: Slot, rank: number)
	local state = casters[unit]
	if state then
		state.Ranks[slot] = rank
	end
end

--[[
	Casts the ability in a slot. Returns false and a reason when it can't be
	cast, in which case nothing is spent.
]]
function Module:Cast(unit: Unit, slot: Slot, aim: Aim?): (boolean, string?)
	local state = casters[unit]
	if not state then
		return false, "NotACaster"
	end
	local now = SimClock.now()
	if unit.IsDead or unit.IsRemoved or now < unit.StunnedUntil or unit.Dash then
		return false, "Disabled"
	end

	local abilityId = state.Loadout[slot]
	local ability = if abilityId then abilities[abilityId] else nil
	if not ability then
		return false, "EmptySlot"
	end
	local rank = state.Ranks[slot] or 1
	if rank < 1 then
		return false, "NotLearned"
	end
	local cooldownEnd = state.CooldownEnds[slot]
	if cooldownEnd and now < cooldownEnd then
		return false, "OnCooldown"
	end
	local cost = AbilityRules.getCost(state.Profile, ability.Info.Cost)
	if unit.Resource < cost then
		return false, "NotEnoughResource"
	end

	local aimPoint, direction, target = resolveAim(unit, ability.Info, aim)
	if not aimPoint or not direction then
		return false, "InvalidTarget"
	end

	-- Any cast ends a channel in progress, a recall included.
	if state.Channel then
		endChannel(unit, state)
	end

	local context: CastContext = {
		Caster = unit,
		Info = ability.Info,
		Values = AbilityRules.resolveValues(ability.Values, rank),
		AimPoint = aimPoint,
		Direction = direction,
		Target = target,
	}
	local didRun, result = pcall(ability.Handler, context)
	if not didRun then
		warn(`Ability {ability.Info.Id} failed: {result}`)
		return false, "HandlerError"
	end
	if result == false then
		return false, "Refused"
	end

	if ability.Info.Targeting ~= "Self" then
		unit.Facing = math.atan2(-direction.X, -direction.Z)
	end
	if cost > 0 then
		UnitServerService:SetResource(unit, unit.Resource - cost)
		state.LastSpendTime = now
	end
	local cooldown = ability.Info.Cooldown * 100 / (100 + (unit.Stats.AbilityHaste or 0))
	if cooldown > 0 then
		state.CooldownEnds[slot] = now + cooldown
		state.CooldownLengths[slot] = cooldown
		if unit.OwnerPlayer then
			AbilityNetwork.CooldownStarted:FireClient(
				unit.OwnerPlayer,
				slot,
				cooldown,
				toServerTime(now + cooldown)
			)
		end
	end
	Module.AbilityCast:Fire(unit, slot, cooldown)
	return true, nil
end

--[[
	Takes seconds off the cooldown a slot is on, if any, and tells the
	caster's player.
]]
function Module:ReduceCooldown(unit: Unit, slot: Slot, seconds: number)
	local state = casters[unit]
	local endsAt = if state then state.CooldownEnds[slot] else nil
	if not state or not endsAt then
		return
	end
	local now = SimClock.now()
	local reduced = math.max(endsAt - seconds, now)
	state.CooldownEnds[slot] = reduced
	if unit.OwnerPlayer then
		AbilityNetwork.CooldownStarted:FireClient(
			unit.OwnerPlayer,
			slot,
			state.CooldownLengths[slot] or seconds,
			toServerTime(reduced)
		)
	end
end

--[[
	Starts a channel on a caster: OnComplete runs after Duration seconds unless
	the caster dies, is stunned, or breaks it as the options say. The caster
	stops in place when the channel starts.
]]
function Module:StartChannel(unit: Unit, options: ChannelOptions)
	local state = casters[unit]
	if not state then
		return
	end

	UnitServerService:IssueOrder(unit, { Kind = "Idle" })
	if options.IsRooted then
		UnitServerService:Root(unit, options.Duration, { IsSelfApplied = true })
	end
	local endsAt = SimClock.now() + options.Duration
	state.Channel = {
		Options = options,
		EndsAt = endsAt,
		Order = unit.Order,
	}
	unit.IsChanneling = true
	if unit.OwnerPlayer then
		AbilityNetwork.ChannelChanged:FireClient(
			unit.OwnerPlayer,
			options.Name,
			toServerTime(endsAt)
		)
	end
end

function Module:CancelChannel(unit: Unit)
	local state = casters[unit]
	if state and state.Channel then
		endChannel(unit, state)
	end
end

--[[
	Fires a shot along a line that hits units passing the filter, and shows
	it to every client.
]]
function Module:FireSkillshot(caster: Unit, options: SkillshotOptions)
	table.insert(skillshots, {
		Caster = caster,
		Options = options,
		Position = options.Origin,
		Traveled = 0,
		HitIds = {},
	})
	Module:PlayEffect({
		Kind = "Projectile",
		Origin = options.Origin,
		Direction = options.Direction,
		Speed = options.Speed,
		Range = options.Range,
		Width = options.Width,
		Color = options.Color,
	})
end

local function getEffectPoints(effect: Effect): { Vector3 }
	if effect.Kind == "Projectile" then
		local reach = effect.Direction.Unit * effect.Range
		return { effect.Origin, effect.Origin + reach / 2, effect.Origin + reach }
	elseif effect.Kind == "Ring" then
		return { effect.Position }
	else
		return { effect.From, effect.To }
	end
end

--[[
	Shows a visual effect to every client that can see part of it. It
	changes nothing in the game.
]]
function Module:PlayEffect(effect: Effect)
	local points = getEffectPoints(effect)
	for _, player in Players:GetPlayers() do
		-- Annotated because luau-lsp widens the narrowed team to string.
		local team: UnitTypes.Team? = UnitServerService:GetViewerTeam(player)
		local isSeen = team == nil
		if team then
			for _, point in points do
				if UnitServerService:IsPointVisibleTo(point, team) then
					isSeen = true
					break
				end
			end
		end
		if isSeen then
			AbilityNetwork.Effect:FireClient(player, effect)
		end
	end
end

function Module:Init()
	AbilityNetwork.CastRequest.OnServerEvent:Connect(onCastRequest)
	UnitServerService.UnitDamaged:Connect(onUnitDamaged)
	UnitServerService.UnitRemoved:Connect(onUnitRemoved)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function Module:Start()
	SimClock.onStep(step)
end

return Module
