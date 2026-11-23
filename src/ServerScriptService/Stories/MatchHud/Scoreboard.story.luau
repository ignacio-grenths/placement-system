--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const Scoreboard = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/Scoreboard"
)

const SAMPLE_NAMES = { "Akira", "Mika", "Sora", "Ren", "Yuki" }
const LONG_NAME = "ThisPlayerHasAVeryLongDisplayName"

const CONTROLS = {
	Players = UILabs.Ordered(
		UILabs.ControlGroup({
			BluePlayers = UILabs.Ordered(UILabs.Slider(5, 0, 5, 1), 1),
			RedPlayers = UILabs.Ordered(UILabs.Slider(3, 0, 5, 1), 2),
			-- Gives the first Blue player a name too long for the row.
			HasLongName = UILabs.Ordered(false, 3),
		}),
		1
	),
}

type StoryProps = {
	controls: {
		Players: {
			BluePlayers: () -> number,
			RedPlayers: () -> number,
			HasLongName: () -> boolean,
		},
	},
	target: Frame,
}

local function getHeroNames(): { string }
	local names = {}
	for _, hero in HeroCatalog.Heroes do
		table.insert(names, hero.DisplayName)
	end
	table.sort(names)
	return names
end

local function story(props: StoryProps)
	local controls = props.controls.Players
	local heroNames = getHeroNames()

	local function rows(): { Scoreboard.ScoreRow }
		local list = {}
		for _, team in { "Blue", "Red" } do
			local count = if team == "Blue" then controls.BluePlayers() else controls.RedPlayers()
			for index = 1, count do
				local isFirstBlue = team == "Blue" and index == 1
				table.insert(list, {
					Team = team,
					PlayerName = if isFirstBlue and controls.HasLongName()
						then LONG_NAME
						else SAMPLE_NAMES[index],
					HeroName = heroNames[(index - 1) % #heroNames + 1],
					Kills = index * 2,
					Deaths = index,
					IsLocalPlayer = isFirstBlue,
				})
			end
		end
		return list
	end

	return Scoreboard({
		Rows = rows,
		IsOpen = function()
			return true
		end,
	})
end

return {
	summary = "Both teams' heroes, kills, and deaths, with empty and full teams and a long player name.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
