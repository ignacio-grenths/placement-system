--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const Announcement = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/Announcement"
)
const HudTheme = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/HudTheme"
)

const CONTROLS = {
	IsShown = UILabs.Ordered(true, 1),
	Text = UILabs.Ordered("Your team took the Skyray!", 2),
	-- The team whose color edges the banner.
	Team = UILabs.Ordered(UILabs.Choose({ "Blue", "Red" }), 3),
}

type StoryProps = {
	controls: {
		IsShown: () -> boolean,
		Text: () -> string,
		Team: () -> string,
	},
	target: Frame,
}

local function story(props: StoryProps)
	local controls = props.controls

	return Announcement({
		Message = function()
			if not controls.IsShown() then
				return nil
			end
			return {
				Text = controls.Text(),
				Color = HudTheme.TeamColors[controls.Team()] or HudTheme.StrokeColor,
			}
		end,
	})
end

return {
	summary = "The banner that announces river bosses and new buffs.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
