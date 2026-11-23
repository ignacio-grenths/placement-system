--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const EndScreen = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/EndScreen"
)

const effect = Vide.effect
const source = Vide.source

const CONTROLS = {
	Result = UILabs.Ordered(UILabs.Choose({ "Victory", "Defeat" }), 1),
}

type StoryProps = {
	controls: {
		Result: () -> string,
	},
	target: Frame,
}

local function story(props: StoryProps)
	-- Continue hides the screen, as it does in game; changing the result
	-- control shows it again.
	local isDismissed = source(false)
	effect(function()
		props.controls.Result()
		isDismissed(false)
	end)

	return EndScreen({
		Result = function()
			return if isDismissed() then nil else props.controls.Result()
		end,
		Detail = function()
			return if props.controls.Result() == "Victory"
				then "The Red core has fallen"
				else "The Blue core has fallen"
		end,
		OnContinue = function()
			isDismissed(true)
		end,
	})
end

return {
	summary = "The victory and defeat screen, with Continue closing it.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
