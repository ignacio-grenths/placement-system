--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const show = Vide.show

const HudTheme = require("./HudTheme")

const DIM_COLOR = Color3.new(0, 0, 0)
const DIM_TRANSPARENCY = 0.4
const RESULT_TEXT_SIZE = 72
const VICTORY_COLOR = Color3.fromRGB(255, 215, 90)
const DEFEAT_COLOR = Color3.fromRGB(230, 90, 90)
const BUTTON_SIZE = Vector2.new(220, 56)
const GAP = 20

export type EndScreenProps = {
	-- "Victory" or "Defeat" once the match is over, nil while it runs.
	Result: () -> string?,
	-- One line under the result, such as which core fell.
	Detail: () -> string,
	OnContinue: () -> (),
}

--[[
	Covers the screen when a core falls and says who won, with one button
	that closes it.
]]
local function endScreen(props: EndScreenProps)
	return show(function()
		return props.Result() ~= nil
	end, function()
		return create("Frame")({
			Name = "EndScreen",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = DIM_COLOR,
			BackgroundTransparency = DIM_TRANSPARENCY,
			ZIndex = 10,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, GAP),
			}),
			create("TextLabel")({
				Name = "Result",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				Font = HudTheme.Font,
				Text = function()
					return props.Result() or ""
				end,
				TextSize = RESULT_TEXT_SIZE,
				TextColor3 = function()
					return if props.Result() == "Victory" then VICTORY_COLOR else DEFEAT_COLOR
				end,
				TextStrokeTransparency = 0.3,
			}),
			create("TextLabel")({
				Name = "Detail",
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				Font = HudTheme.BodyFont,
				Text = props.Detail,
				TextSize = HudTheme.TitleTextSize,
				TextColor3 = HudTheme.TextColor,
			}),
			create("TextButton")({
				Name = "Continue",
				LayoutOrder = 3,
				Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
				BackgroundColor3 = HudTheme.PanelColor,
				Font = HudTheme.Font,
				Text = "Continue",
				TextSize = HudTheme.TitleTextSize,
				TextColor3 = HudTheme.TextColor,
				Activated = props.OnContinue,

				create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
				create("UIStroke")({
					Color = HudTheme.StrokeColor,
					Thickness = 2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			}),
		})
	end)
end

return endScreen
