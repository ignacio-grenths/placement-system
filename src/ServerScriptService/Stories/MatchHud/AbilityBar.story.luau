--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const AbilityBar = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/AbilityBar"
)
const AbilityCatalog = require("@game/ServerScriptService/Modules/Data/AbilityCatalog")
const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")

const SLOT_ORDER = { "Q", "W", "E", "R", "D", "F", "B" }
const MAIN_SLOTS = { Q = true, W = true, E = true, R = true }
const SPELL_SLOTS = { "D", "F" }

-- Heroes whose kits exist, picked by rule so a renamed hero still shows.
local function getHeroesWithKits(): { string }
	local heroIds = {}
	for heroId, hero in HeroCatalog.Heroes do
		if next(hero.Abilities) then
			table.insert(heroIds, heroId)
		end
	end
	table.sort(heroIds)
	return heroIds
end

const CONTROLS = {
	Hero = UILabs.Ordered(
		UILabs.ControlGroup({
			Hero = UILabs.Ordered(UILabs.Choose(getHeroesWithKits()), 1),
			-- Energy or mana the hero has left.
			Resource = UILabs.Ordered(UILabs.Slider(200, 0, 400, 10), 2),
		}),
		1
	),
	Cooldowns = UILabs.Ordered(
		UILabs.ControlGroup({
			-- Seconds left on Q. 0 means ready.
			QRemaining = UILabs.Ordered(UILabs.Slider(0, 0, 10, 0.1), 1),
			-- Seconds left on R. 0 means ready.
			RRemaining = UILabs.Ordered(UILabs.Slider(30, 0, 70, 1), 2),
			-- Share of a recall done. 0 means not recalling.
			Recall = UILabs.Ordered(UILabs.Slider(0, 0, 1, 0.05), 3),
		}),
		2
	),
	Layout = UILabs.Ordered(
		UILabs.ControlGroup({
			IsTouch = UILabs.Ordered(false, 1),
			-- Shows the slots empty, as before the loadout arrives.
			IsLoadoutEmpty = UILabs.Ordered(false, 2),
		}),
		3
	),
}

type StoryProps = {
	controls: {
		Hero: {
			Hero: () -> string,
			Resource: () -> number,
		},
		Cooldowns: {
			QRemaining: () -> number,
			RRemaining: () -> number,
			Recall: () -> number,
		},
		Layout: {
			IsTouch: () -> boolean,
			IsLoadoutEmpty: () -> boolean,
		},
	},
	target: Frame,
}

local function getAbilityId(heroId: string, slot: string): string?
	local hero = HeroCatalog.Heroes[heroId]
	if not hero then
		return nil
	end
	if slot == "B" then
		return "Recall"
	end
	local spellIndex = table.find(SPELL_SLOTS, slot)
	if spellIndex then
		local spell = hero.SummonerSpells[spellIndex]
		return if spell then `Spell.{spell}` else nil
	end
	return hero.Abilities[slot]
end

local function story(props: StoryProps)
	local controls = props.controls

	local function abilities(): { AbilityBar.AbilityView }
		local heroId = controls.Hero.Hero()
		local resource = controls.Hero.Resource()
		local isEmpty = controls.Layout.IsLoadoutEmpty()
		local cooldowns = {
			Q = { Remaining = controls.Cooldowns.QRemaining(), Duration = 10 },
			R = { Remaining = controls.Cooldowns.RRemaining(), Duration = 70 },
		}

		local views = {}
		for _, slot in SLOT_ORDER do
			local abilityId = if isEmpty then nil else getAbilityId(heroId, slot)
			local entry = if abilityId then AbilityCatalog.Abilities[abilityId] else nil
			local cooldown = cooldowns[slot]
			table.insert(views, {
				Slot = slot,
				KeyLabel = slot,
				Name = if entry then entry.Name else "",
				IsMain = MAIN_SLOTS[slot] == true,
				Cost = if entry then entry.Cost else 0,
				CanAfford = not entry or resource >= entry.Cost,
				CooldownRemaining = if cooldown then cooldown.Remaining else 0,
				CooldownDuration = if cooldown then cooldown.Duration else 0,
				IsEmpty = entry == nil,
			})
		end
		return views
	end

	local function channel(): AbilityBar.ChannelView?
		local progress = controls.Cooldowns.Recall()
		return if progress > 0 then { Name = "Recall", Progress = progress } else nil
	end

	return AbilityBar({
		Abilities = abilities,
		Channel = channel,
		IsTouch = controls.Layout.IsTouch,
		OnCast = function(slot: string, aim: Vector2?)
			print(`Cast {slot}`, aim)
		end,
	})
end

return {
	summary = "The ability, summoner spell, and recall buttons for each hero with a kit, with cooldowns, costs, a recall in progress, and the touch layout.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
