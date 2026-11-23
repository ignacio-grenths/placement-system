--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const derive = Vide.derive
const indexes = Vide.indexes
const show = Vide.show

const HudTheme = require("./HudTheme")

const COLUMN_WIDTH = 300
const ROW_HEIGHT = 36
const GAP = 16
const HIGHLIGHT_COLOR = Color3.fromRGB(44, 52, 72)

export type ScoreRow = {
	Team: string,
	PlayerName: string,
	HeroName: string,
	Kills: number,
	Deaths: number,
	IsLocalPlayer: boolean,
}

export type ScoreboardProps = {
	Rows: () -> { ScoreRow },
	IsOpen: () -> boolean,
}

local function scoreLine(row: () -> ScoreRow, layoutOrder: number): Frame
	return create("Frame")({
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = HIGHLIGHT_COLOR,
		BackgroundTransparency = function()
			return if row().IsLocalPlayer then 0 else 1
		end,

		create("UICorner")({ CornerRadius = UDim.new(0, 6) }),
		create("UIPadding")({
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		create("TextLabel")({
			Name = "Names",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.7, 1),
			Font = HudTheme.BodyFont,
			Text = function()
				return `{row().HeroName}  {row().PlayerName}`
			end,
			TextSize = HudTheme.SmallTextSize,
			TextColor3 = HudTheme.TextColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		create("TextLabel")({
			Name = "KillsAndDeaths",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.3, 1),
			Font = HudTheme.Font,
			Text = function()
				return `{row().Kills} / {row().Deaths}`
			end,
			TextSize = HudTheme.SmallTextSize,
			TextColor3 = HudTheme.TextColor,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

local function teamColumn(team: string, rows: () -> { ScoreRow }, layoutOrder: number): Frame
	local teamRows = derive(function()
		local filtered = {}
		for _, row in rows() do
			if row.Team == team then
				table.insert(filtered, row)
			end
		end
		return filtered
	end)

	return create("Frame")({
		Name = team,
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(COLUMN_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
		}),
		create("TextLabel")({
			Name = "Header",
			LayoutOrder = 0,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			Font = HudTheme.Font,
			Text = `{team} team`,
			TextSize = HudTheme.BodyTextSize,
			TextColor3 = HudTheme.TeamColors[team] or HudTheme.TextColor,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		-- An empty team keeps its column and says so.
		create("TextLabel")({
			Name = "Empty",
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			Visible = function()
				return #teamRows() == 0
			end,
			Font = HudTheme.BodyFont,
			Text = "No players yet",
			TextSize = HudTheme.SmallTextSize,
			TextColor3 = HudTheme.MutedTextColor,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		indexes(teamRows, function(row, index)
			return scoreLine(row, index + 1)
		end),
	})
end

--[[
	Every player's hero, kills, and deaths, by team. Opened while Tab is held,
	with the gamepad's Back button, or with the Scores button.
]]
local function scoreboard(props: ScoreboardProps)
	return show(props.IsOpen, function()
		return create("Frame")({
			Name = "Scoreboard",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = HudTheme.PanelColor,
			BackgroundTransparency = HudTheme.PanelTransparency,
			ZIndex = 5,

			create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
			create("UIPadding")({
				PaddingTop = UDim.new(0, GAP),
				PaddingBottom = UDim.new(0, GAP),
				PaddingLeft = UDim.new(0, GAP),
				PaddingRight = UDim.new(0, GAP),
			}),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, GAP),
			}),
			teamColumn("Blue", props.Rows, 1),
			teamColumn("Red", props.Rows, 2),
		})
	end)
end

return scoreboard
