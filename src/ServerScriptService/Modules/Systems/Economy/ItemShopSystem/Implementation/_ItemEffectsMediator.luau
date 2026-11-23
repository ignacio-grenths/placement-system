--!strict

const RunService = game:GetService("RunService")

const AbilityServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityServerService"
)
const GoldServerService = require(
	"@game/ServerScriptService/Modules/Systems/Economy/GoldSystem/SystemPackage/GoldServerService"
)
const ItemCatalog = require("@game/ServerScriptService/Modules/Data/ItemCatalog")
const ProgressionCatalog = require("@game/ServerScriptService/Modules/Data/ProgressionCatalog")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const ItemShopServerService = require("../SystemPackage/ItemShopServerService")

-- Seconds between two checks of who earns Tracker's Cloak's extra speed.
const CLOAK_INTERVAL = 0.25
const RECALL_SLOT = "B"

const AbilityTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityTypes"
)
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type DamageKind = UnitTypes.DamageKind
type Slot = AbilityTypes.Slot
type Unit = UnitTypes.Unit

type Spellstrike = {
	Slot: Slot,
	-- Seconds of cooldown the cast started.
	Cooldown: number,
	-- os.clock() time the empowered attack is no longer waiting.
	ExpiresAt: number,
}

type Wrecking = {
	Hero: Unit,
	ExpiresAt: number,
}

const EFFECTS = ItemCatalog.Effects

local Module = {}

-- os.clock() times, by hero: the last fight it was in, and when its
-- Starfall Pendant can catch it again.
local lastCombatTimes: { [Unit]: number? } = {}
local pendantReadyAt: { [Unit]: number? } = {}
-- os.clock() time each ally can get a Last Stand doubled shield again.
local lastStandReadyAt: { [Unit]: number? } = {}
local spellstrikes: { [Unit]: Spellstrike? } = {}
-- Structures a Wrecking Crew hero hit lately, and who hit them.
local wreckedStructures: { [Unit]: Wrecking? } = {}
local cloakTimer = 0

local function holds(hero: Unit, itemId: string): boolean
	local player = hero.OwnerPlayer
	return player ~= nil and table.find(ItemShopServerService:GetInventory(player), itemId) ~= nil
end

local function hasPair(hero: Unit, pairId: string): boolean
	local player = hero.OwnerPlayer
	return player ~= nil and ItemShopServerService:GetActivePair(player) == pairId
end

local function getHealthShare(unit: Unit): number
	return unit.Health / math.max(unit.Stats.MaxHealth, 1)
end

local function onTookHit(target: Unit, source: Unit, dealt: number, kind: DamageKind)
	if kind == "Attack" and source.Kind ~= "Structure" and holds(target, "BeetleCarapace") then
		UnitServerService:ApplyDamage(source, dealt * EFFECTS.CarapaceReflectShare, target, "True")
	end

	local now = os.clock()
	if
		target.Health > 0
		and getHealthShare(target) < EFFECTS.PendantThreshold
		and now >= (pendantReadyAt[target] or 0)
		and holds(target, "StarfallPendant")
	then
		pendantReadyAt[target] = now + EFFECTS.PendantCooldown
		UnitServerService:AddShield(target, EFFECTS.PendantShield, EFFECTS.PendantShieldSeconds)
	end
end

local function onLandedHit(target: Unit, source: Unit, dealt: number, kind: DamageKind)
	if kind == "Ability" and target.Kind == "Hero" and holds(source, "VoidShard") then
		UnitServerService:CutHealing(target, EFFECTS.VoidShardHealingCutSeconds)
	end
	if kind ~= "Attack" then
		return
	end

	local now = os.clock()
	if target.Kind == "Structure" then
		if holds(source, "GrubHammer") then
			local extra = dealt * EFFECTS.HammerStructureShare
			UnitServerService:ApplyDamage(target, extra, source, "True")
		end
		if hasPair(source, "WreckingCrew") then
			wreckedStructures[target] = {
				Hero = source,
				ExpiresAt = now + EFFECTS.WreckingSeconds,
			}
		end
	end

	local strike = spellstrikes[source]
	if strike and now < strike.ExpiresAt then
		spellstrikes[source] = nil
		local damage = EFFECTS.SpellstrikeDamage
			+ source.Stats.AttackDamage * EFFECTS.SpellstrikeAttackShare
		UnitServerService:ApplyDamage(target, damage, source, "Ability")
		local refund = strike.Cooldown * EFFECTS.SpellstrikeRefundShare
		AbilityServerService:ReduceCooldown(source, strike.Slot, refund)
	end
end

--[[
	Wrecking Crew: aliens near the hero who hit a tower deal more damage to
	that tower for a few seconds.
]]
local function onAlienHitStructure(target: Unit, source: Unit, dealt: number)
	local wrecking = wreckedStructures[target]
	if
		wrecking
		and wrecking.Hero.Team == source.Team
		and os.clock() < wrecking.ExpiresAt
		and not wrecking.Hero.IsDead
		and (wrecking.Hero.Position - source.Position).Magnitude <= EFFECTS.WreckingRadius
	then
		UnitServerService:ApplyDamage(target, dealt * EFFECTS.WreckingShare, source, "True")
	end
end

local function onUnitDamaged(target: Unit, source: Unit?, dealt: number, kind: DamageKind)
	if not source or source.Team == target.Team then
		return
	end
	local now = os.clock()
	if target.Kind == "Hero" then
		lastCombatTimes[target] = now
		onTookHit(target, source, dealt, kind)
	end
	if source.Kind == "Hero" then
		lastCombatTimes[source] = now
		onLandedHit(target, source, dealt, kind)
	elseif source.Kind == "Minion" and target.Kind == "Structure" and kind == "Attack" then
		onAlienHitStructure(target, source, dealt)
	end
end

local function onUnitDied(unit: Unit, killer: Unit?)
	spellstrikes[unit] = nil
	wreckedStructures[unit] = nil
	-- Bounty Hunter: hero takedowns pay more, on top of the usual bounty.
	local player = if killer then killer.OwnerPlayer else nil
	if unit.Kind == "Hero" and killer and player and hasPair(killer, "BountyHunter") then
		local bonus = ProgressionCatalog.HeroKillGold * (EFFECTS.BountyGoldMultiplier - 1)
		GoldServerService:AddGold(player, bonus)
	end
end

local function onUnitRemoved(unit: Unit)
	lastCombatTimes[unit] = nil
	pendantReadyAt[unit] = nil
	lastStandReadyAt[unit] = nil
	spellstrikes[unit] = nil
	wreckedStructures[unit] = nil
end

local function onAbilityCast(unit: Unit, slot: Slot, cooldown: number)
	if slot ~= RECALL_SLOT and hasPair(unit, "Spellstrike") then
		spellstrikes[unit] = {
			Slot = slot,
			Cooldown = cooldown,
			ExpiresAt = os.clock() + EFFECTS.SpellstrikeSeconds,
		}
	end
end

--[[
	Last Stand: a shield cast on a hurt ally is doubled, once every so often
	per ally.
]]
local function modifyShield(unit: Unit, strength: number, caster: Unit?): number
	if not caster or caster == unit or unit.Kind ~= "Hero" or not hasPair(caster, "LastStand") then
		return strength
	end
	local now = os.clock()
	if
		getHealthShare(unit) >= EFFECTS.LastStandThreshold
		or now < (lastStandReadyAt[unit] or 0)
	then
		return strength
	end
	lastStandReadyAt[unit] = now + EFFECTS.LastStandCooldown
	return strength * 2
end

local function onHeartbeat(frameTime: number)
	cloakTimer += frameTime
	if cloakTimer < CLOAK_INTERVAL then
		return
	end
	cloakTimer = 0

	-- Tracker's Cloak: extra speed for a hero who hasn't fought lately.
	local now = os.clock()
	for _, unit in UnitServerService:GetUnits() do
		if
			unit.Kind == "Hero"
			and unit.OwnerPlayer
			and not unit.IsDead
			and not unit.IsRemoved
			and now - (lastCombatTimes[unit] or 0) >= EFFECTS.CloakIdleSeconds
			and holds(unit, "TrackersCloak")
		then
			UnitServerService:AddModifier(unit, "Item.TrackersCloak.Idle", {
				Stat = "MoveSpeed",
				Add = EFFECTS.CloakMoveSpeed,
			}, CLOAK_INTERVAL * 2)
		end
	end
end

function Module:Init()
	UnitServerService.UnitDamaged:Connect(onUnitDamaged)
	UnitServerService.UnitDied:Connect(onUnitDied)
	UnitServerService.UnitRemoved:Connect(onUnitRemoved)
	UnitServerService:SetShieldModifier(modifyShield)
	AbilityServerService.AbilityCast:Connect(onAbilityCast)
end

function Module:Start()
	RunService.Heartbeat:Connect(onHeartbeat)
end

return Module
