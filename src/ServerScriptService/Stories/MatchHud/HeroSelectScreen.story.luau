--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const AbilityCatalog = require("@game/ServerScriptService/Modules/Data/AbilityCatalog")
const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const HeroSelectScreen = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/HeroSelectScreen"
)

const effect = Vide.effect
const source = Vide.source

const ROLES = { "Top", "Jungle", "Mid", "Bot", "Support" }
const SLOTS = { "Q", "W", "E", "R" }
const NONE = "None"
const LONG_NAME = "SuperLongDisplayName_2026"

local function getHeroIds(): { string }
	local heroIds = {}
	for heroId in HeroCatalog.Heroes do
		table.insert(heroIds, heroId)
	end
	table.sort(heroIds)
	return heroIds
end

const HERO_IDS = getHeroIds()

local function withNone(choices: { string }): { string }
	local result = { NONE }
	for _, choice in choices do
		table.insert(result, choice)
	end
	return result
end

const CONTROLS = {
	Picks = UILabs.Ordered(
		UILabs.ControlGroup({
			-- The local player's current hero.
			Selected = UILabs.Ordered(UILabs.Choose(withNone(HERO_IDS)), 1),
			IsLockedIn = UILabs.Ordered(false, 2),
			-- Players on the local team, the local player included.
			Teammates = UILabs.Ordered(UILabs.Slider(3, 1, 5, 1), 3),
			-- A teammate has locked in a hero of this role, so its heroes show as taken.
			TakenRole = UILabs.Ordered(UILabs.Choose(withNone(ROLES)), 4),
			Team = UILabs.Ordered(UILabs.Choose({ "Blue", "Red" }), 5),
			LongNames = UILabs.Ordered(false, 6),
		}),
		1
	),
	Timer = UILabs.Ordered(
		UILabs.ControlGroup({
			SecondsLeft = UILabs.Ordered(UILabs.Slider(23, 0, 30, 1), 1),
		}),
		2
	),
	Layout = UILabs.Ordered(
		UILabs.ControlGroup({
			IsCompact = UILabs.Ordered(false, 1),
			-- Room the panel may take, in UI units; a 667 by 375 phone has
			-- about 667 by 317.
			MaxWidth = UILabs.Ordered(UILabs.Slider(1920, 400, 1920, 1), 2),
			MaxHeight = UILabs.Ordered(UILabs.Slider(1022, 250, 1080, 1), 3),
		}),
		3
	),
}

type StoryProps = {
	controls: {
		Picks: {
			Selected: () -> string,
			IsLockedIn: () -> boolean,
			Teammates: () -> number,
			TakenRole: () -> string,
			Team: () -> string,
			LongNames: () -> boolean,
		},
		Timer: {
			SecondsLeft: () -> number,
		},
		Layout: {
			IsCompact: () -> boolean,
			MaxWidth: () -> number,
			MaxHeight: () -> number,
		},
	},
	target: Frame,
}

local function firstHeroOf(role: string): string
	for _, heroId in HERO_IDS do
		if HeroCatalog.Heroes[heroId].Role == role then
			return heroId
		end
	end
	return HERO_IDS[1]
end

local function story(props: StoryProps)
	local picks = props.controls.Picks

	-- Tapping a card or Lock In changes these, as the server would; the
	-- controls set them again.
	local selected = source(nil :: string?)
	local isLockedIn = source(false)
	effect(function()
		local choice = picks.Selected()
		selected(if choice == NONE then nil else choice)
	end)
	effect(function()
		isLockedIn(picks.IsLockedIn())
	end)

	local function heroes(): { HeroSelectScreen.HeroCardView }
		local views = {}
		for _, heroId in HERO_IDS do
			local hero = HeroCatalog.Heroes[heroId]
			local abilities = {}
			for _, slot in SLOTS do
				local ability = AbilityCatalog.Abilities[hero.Abilities[slot]]
				table.insert(abilities, `{slot} {if ability then ability.Name else "?"}`)
			end
			table.insert(views, {
				Id = heroId,
				Name = hero.DisplayName,
				Title = hero.Title,
				Role = hero.Role :: string,
				ResourceName = if hero.Resource == "None"
					then "Cooldowns only"
					else hero.Resource :: string,
				Abilities = abilities,
				Color = hero.Color,
				Blocked = if hero.Role == picks.TakenRole() then "Taken" else nil,
			})
		end
		return views
	end

	local function teammates(): { HeroSelectScreen.TeammateView }
		local result = {}
		local selectedHero = selected()
		table.insert(result, {
			Name = if picks.LongNames() then LONG_NAME else "You",
			HeroName = if selectedHero then HeroCatalog.Heroes[selectedHero].DisplayName else "",
			IsLockedIn = isLockedIn(),
			IsLocalPlayer = true,
		})
		for index = 2, picks.Teammates() do
			local takenRole = picks.TakenRole()
			local isTaker = index == 2 and takenRole ~= NONE
			table.insert(result, {
				Name = if picks.LongNames() then `{LONG_NAME}{index}` else `Player{index}`,
				HeroName = if isTaker
					then HeroCatalog.Heroes[firstHeroOf(takenRole)].DisplayName
					else "",
				IsLockedIn = isTaker,
				IsLocalPlayer = false,
			})
		end
		return result
	end

	return HeroSelectScreen({
		IsOpen = function()
			return true
		end,
		Roles = ROLES,
		Heroes = heroes,
		Team = picks.Team,
		Teammates = teammates,
		TeamSize = 5,
		SelectedHeroId = selected,
		IsLockedIn = isLockedIn,
		SecondsLeft = props.controls.Timer.SecondsLeft,
		IsCompact = props.controls.Layout.IsCompact,
		MaxSize = function()
			return Vector2.new(props.controls.Layout.MaxWidth(), props.controls.Layout.MaxHeight())
		end,
		UiScale = function()
			return 1
		end,
		OnPick = function(heroId: string)
			selected(heroId)
		end,
		OnLockIn = function()
			isLockedIn(true)
		end,
	})
end

return {
	summary = "Hero selection before a match: roster, heroes by role, and Lock In.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
