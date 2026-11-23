--!strict

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const HeroServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/HeroSystem/SystemPackage/HeroServerService"
)

const AbilityServerService = require("../SystemPackage/AbilityServerService")

-- Summoner spells fill these slots in the order the hero lists them.
const SPELL_SLOTS = { "D", "F" }
const RECALL_ABILITY_ID = "Recall"

const AbilityTypes = require("../SystemPackage/AbilityTypes")
const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Slot = AbilityTypes.Slot
type Unit = UnitTypes.Unit

local Module = {}

local function onHeroSpawned(hero: Unit, heroId: string)
	local entry = HeroCatalog.Heroes[heroId]
	if not entry then
		return
	end

	local loadout: { [Slot]: string? } = {}
	for slot, abilityId in entry.Abilities do
		loadout[slot :: Slot] = abilityId
	end
	for index, spell in entry.SummonerSpells do
		local slot = SPELL_SLOTS[index]
		if slot then
			loadout[slot :: Slot] = `Spell.{spell}`
		end
	end
	local recallSlot: Slot = "B"
	loadout[recallSlot] = RECALL_ABILITY_ID

	AbilityServerService:SetupCaster(hero, loadout, {
		Kind = entry.Resource,
		RegenPerSecond = entry.ResourceRegen,
		RegenDelay = entry.ResourceRegenDelay,
		RestoreOnHeroHit = entry.ResourceOnHeroHit,
	})
end

local function onHeroRemoved(hero: Unit)
	AbilityServerService:RemoveCaster(hero)
end

function Module:Init()
	HeroServerService.HeroSpawned:Connect(onHeroSpawned)
	HeroServerService.HeroRemoved:Connect(onHeroRemoved)
end

return Module
