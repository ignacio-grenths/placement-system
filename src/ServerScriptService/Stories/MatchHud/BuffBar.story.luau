--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const BuffBar = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/BuffBar"
)
const JungleCatalog = require("@game/ServerScriptService/Modules/Data/JungleCatalog")

const CONTROLS = {
	Camps = UILabs.Ordered(
		UILabs.ControlGroup({
			HasFocus = UILabs.Ordered(true, 1),
			-- Seconds left on Focus; Burn's works the same.
			FocusSeconds = UILabs.Ordered(UILabs.Slider(62, 0, 90, 1), 2),
			HasBurn = UILabs.Ordered(true, 3),
			BurnSeconds = UILabs.Ordered(UILabs.Slider(8, 0, 90, 1), 4),
		}),
		1
	),
	Bosses = UILabs.Ordered(
		UILabs.ControlGroup({
			-- Skyrays the team has slain; 0 shows no tile.
			SkyrayStacks = UILabs.Ordered(UILabs.Slider(2, 0, 5, 1), 1),
			HasHiveCall = UILabs.Ordered(false, 2),
			HiveCallSeconds = UILabs.Ordered(UILabs.Slider(140, 0, 180, 1), 3),
		}),
		2
	),
}

type StoryProps = {
	controls: {
		Camps: {
			HasFocus: () -> boolean,
			FocusSeconds: () -> number,
			HasBurn: () -> boolean,
			BurnSeconds: () -> number,
		},
		Bosses: {
			SkyrayStacks: () -> number,
			HasHiveCall: () -> boolean,
			HiveCallSeconds: () -> number,
		},
	},
	target: Frame,
}

local function view(buffId: string, secondsLeft: number?, stacks: number): BuffBar.BuffView
	local info = JungleCatalog.BuffInfo[buffId]
	return {
		Name = if info then info.Name else buffId,
		Color = if info then info.Color else Color3.new(1, 1, 1),
		SecondsLeft = secondsLeft,
		Stacks = stacks,
	}
end

local function story(props: StoryProps)
	local camps = props.controls.Camps
	local bosses = props.controls.Bosses

	return BuffBar({
		Buffs = function()
			local buffs = {}
			if camps.HasFocus() then
				table.insert(buffs, view("Focus", camps.FocusSeconds(), 1))
			end
			if camps.HasBurn() then
				table.insert(buffs, view("Burn", camps.BurnSeconds(), 1))
			end
			if bosses.SkyrayStacks() > 0 then
				table.insert(buffs, view("Skyray", nil, bosses.SkyrayStacks()))
			end
			if bosses.HasHiveCall() then
				table.insert(buffs, view("HiveCall", bosses.HiveCallSeconds(), 1))
			end
			return buffs
		end,
	})
end

return {
	summary = "The local hero's jungle buffs, each with its time left or Skyray stacks.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
