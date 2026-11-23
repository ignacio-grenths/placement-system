--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const HeroStatus = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/HeroStatus"
)

-- Every hero, so each resource kind has a case, picked by rule from the
-- catalog.
local function getHeroIds(): { string }
	local heroIds = {}
	for heroId in HeroCatalog.Heroes do
		table.insert(heroIds, heroId)
	end
	table.sort(heroIds)
	return heroIds
end

const CONTROLS = {
	Hero = UILabs.Ordered(
		UILabs.ControlGroup({
			Hero = UILabs.Ordered(UILabs.Choose(getHeroIds()), 1),
			IsDead = UILabs.Ordered(false, 2),
		}),
		1
	),
	Health = UILabs.Ordered(
		UILabs.ControlGroup({
			-- Share of max health left.
			Health = UILabs.Ordered(UILabs.Slider(0.7, 0, 1, 0.05), 1),
			-- Shield as a share of max health. 0 shows no shield.
			Shield = UILabs.Ordered(UILabs.Slider(0, 0, 0.6, 0.05), 2),
		}),
		2
	),
	Resource = UILabs.Ordered(
		UILabs.ControlGroup({
			-- Share of the resource left.
			Resource = UILabs.Ordered(UILabs.Slider(0.5, 0, 1, 0.05), 1),
		}),
		3
	),
}

type StoryProps = {
	controls: {
		Hero: { Hero: () -> string, IsDead: () -> boolean },
		Health: { Health: () -> number, Shield: () -> number },
		Resource: { Resource: () -> number },
	},
	target: Frame,
}

local function story(props: StoryProps)
	local controls = props.controls
	local function getEntry()
		return HeroCatalog.Heroes[controls.Hero.Hero()]
	end

	return HeroStatus({
		HeroName = function()
			return getEntry().DisplayName
		end,
		Health = function()
			return getEntry().Stats.MaxHealth * controls.Health.Health()
		end,
		MaxHealth = function()
			return getEntry().Stats.MaxHealth
		end,
		Shield = function()
			return getEntry().Stats.MaxHealth * controls.Health.Shield()
		end,
		Resource = function()
			return getEntry().MaxResource * controls.Resource.Resource()
		end,
		MaxResource = function()
			return getEntry().MaxResource
		end,
		ResourceKind = function()
			return getEntry().Resource
		end,
		IsDead = controls.Hero.IsDead,
	})
end

return {
	summary = "The local hero's name, health with shield, and resource bar, for every hero and resource kind.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
