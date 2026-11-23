--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const ScoreStrip = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/ScoreStrip"
)

const CONTROLS = {
	-- Seconds on the match clock. Negative shows the countdown to the start.
	Elapsed = UILabs.Ordered(UILabs.Slider(754, -5, 3600, 1), 1),
	BlueKills = UILabs.Ordered(UILabs.Slider(7, 0, 99, 1), 2),
	RedKills = UILabs.Ordered(UILabs.Slider(12, 0, 99, 1), 3),
}

type StoryProps = {
	controls: {
		Elapsed: () -> number,
		BlueKills: () -> number,
		RedKills: () -> number,
	},
	target: Frame,
}

local function story(props: StoryProps)
	return ScoreStrip({
		Elapsed = props.controls.Elapsed,
		BlueKills = props.controls.BlueKills,
		RedKills = props.controls.RedKills,
		OnScoresPressed = function()
			print("Scores pressed")
		end,
	})
end

return {
	summary = "The match clock between each team's hero kills, with the Scores button.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
