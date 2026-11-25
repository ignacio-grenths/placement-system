--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create

const HudTheme = require("./HudTheme")

const HEIGHT = 40
const CLOCK_WIDTH = 86
const KILLS_WIDTH = 44
const BUTTON_WIDTH = 96
const GAP = 8

export type ScoreStripProps = {
	-- Seconds since the match clock started. Negative while it counts down.
	Elapsed: () -> number,
	BlueKills: () -> number,
	RedKills: () -> number,
	OnScoresPressed: () -> (),
}

local function formatClock(elapsed: number): string
	local seconds = math.floor(math.abs(elapsed))
	local clock = string.format("%d:%02d", seconds // 60, seconds % 60)
	return if elapsed < 0 then `-{clock}` else clock
end

local function killCount(kills: () -> number, color: Color3, layoutOrder: number): TextLabel
	return create("TextLabel")({
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(KILLS_WIDTH, HEIGHT),
		Font = HudTheme.Font,
		Text = function()
			return tostring(kills())
		end,
		TextSize = HudTheme.TitleTextSize,
		TextColor3 = color,
	})
end

--[[
	The match clock between each team's hero kills, with a button that opens
	the scoreboard for players without a Tab key.
]]
local function scoreStrip(props: ScoreStripProps): Frame
	return create("Frame")({
		Name = "ScoreStrip",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, GAP),
		}),

		create("Frame")({
			Name = "Score",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(KILLS_WIDTH * 2 + CLOCK_WIDTH, HEIGHT),
			BackgroundColor3 = HudTheme.PanelColor,
			BackgroundTransparency = HudTheme.PanelTransparency,

			create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
			create("UIStroke")({
				Color = HudTheme.StrokeColor,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			killCount(props.BlueKills, HudTheme.BlueTeamColor, 1),
			create("TextLabel")({
				Name = "Clock",
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(CLOCK_WIDTH, HEIGHT),
				Font = HudTheme.Font,
				Text = function()
					return formatClock(props.Elapsed())
				end,
				TextSize = HudTheme.BodyTextSize,
				TextColor3 = HudTheme.TextColor,
			}),
			killCount(props.RedKills, HudTheme.RedTeamColor, 3),
		}),

		create("TextButton")({
			Name = "ScoresButton",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(BUTTON_WIDTH, math.max(HEIGHT, HudTheme.ButtonHeight)),
			BackgroundColor3 = HudTheme.PanelColor,
			BackgroundTransparency = HudTheme.PanelTransparency,
			Font = HudTheme.Font,
			Text = "Scores",
			TextSize = HudTheme.SmallTextSize,
			TextColor3 = HudTheme.TextColor,
			Activated = props.OnScoresPressed,

			create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
			create("UIStroke")({
				Color = HudTheme.StrokeColor,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
	})
end

return scoreStrip
