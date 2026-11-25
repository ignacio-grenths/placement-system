--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const cleanup = Vide.cleanup
const effect = Vide.effect

const LoadingView = require("@game/ReplicatedFirst/LoadingScreen/LoadingView")

const CONTROLS = {
	Status = UILabs.Ordered("Building the valley", 1),
	-- Fill of the bar, from 0 to 1.
	Progress = UILabs.Ordered(UILabs.Slider(0.6, 0, 1, 0.05), 2),
	Tip = UILabs.Ordered("Press B to recall to your fountain, where you heal and shop.", 3),
}

type StoryProps = {
	controls: {
		Status: () -> string,
		Progress: () -> number,
		Tip: () -> string,
	},
	target: Frame,
}

local function story(props: StoryProps)
	local controls = props.controls
	local view = LoadingView.new(props.target)
	cleanup(function()
		view:Destroy()
	end)

	effect(function()
		view:SetStatus(controls.Status())
	end)
	effect(function()
		view:SetProgress(controls.Progress())
	end)
	effect(function()
		view:SetTip(controls.Tip())
	end)
end

return {
	summary = "The screen shown while the game loads, before hero select.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
