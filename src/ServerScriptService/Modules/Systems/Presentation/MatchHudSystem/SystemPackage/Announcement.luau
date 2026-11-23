--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create

const HudTheme = require("./HudTheme")

const PADDING_X = 18
const PADDING_Y = 8
const STROKE_THICKNESS = 2

export type AnnouncementView = {
	Text: string,
	-- Edges the banner: a team's color for a boss, or a buff's own color.
	Color: Color3,
}

export type AnnouncementProps = {
	-- Nil while there is nothing to announce.
	Message: () -> AnnouncementView?,
}

--[[
	A one-line banner for the moments every player should notice, such as a
	team taking a river boss.
]]
local function announcement(props: AnnouncementProps): Frame
	return create("Frame")({
		Name = "Announcement",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = HudTheme.PanelColor,
		BackgroundTransparency = HudTheme.PanelTransparency,
		Visible = function()
			return props.Message() ~= nil
		end,

		create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
		create("UIStroke")({
			Color = function()
				local message = props.Message()
				return if message then message.Color else HudTheme.StrokeColor
			end,
			Thickness = STROKE_THICKNESS,
		}),
		create("UIPadding")({
			PaddingTop = UDim.new(0, PADDING_Y),
			PaddingBottom = UDim.new(0, PADDING_Y),
			PaddingLeft = UDim.new(0, PADDING_X),
			PaddingRight = UDim.new(0, PADDING_X),
		}),
		create("TextLabel")({
			Name = "Text",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Font = HudTheme.Font,
			Text = function()
				local message = props.Message()
				return if message then message.Text else ""
			end,
			TextSize = HudTheme.TitleTextSize,
			TextColor3 = HudTheme.TextColor,
		}),
	})
end

return announcement
