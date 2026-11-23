--!strict

const BLUE_TEAM_COLOR = Color3.fromRGB(80, 150, 255)
const RED_TEAM_COLOR = Color3.fromRGB(240, 90, 90)

-- Keyed by resource kind.
const RESOURCE_COLORS: { [string]: Color3? } = {
	Mana = Color3.fromRGB(80, 150, 255),
	Energy = Color3.fromRGB(250, 210, 70),
	Stamina = Color3.fromRGB(240, 150, 60),
	None = Color3.fromRGB(120, 120, 130),
}

-- Keyed by team.
const TEAM_COLORS: { [string]: Color3? } = {
	Blue = BLUE_TEAM_COLOR,
	Red = RED_TEAM_COLOR,
}

-- Colors, fonts, and sizes every HUD piece shares, so they read as one set.
-- Sizes are UI units for a 1080p screen.
-- The arena's sleek sci-fi look: deep navy glass panels, tight corners, and
-- cyan edges. Gotham stays: the squared sci-fi fonts blur letters like a and
-- o at HUD sizes.
local Module = table.freeze({
	Font = Enum.Font.GothamBold,
	BodyFont = Enum.Font.GothamMedium,

	PanelColor = Color3.fromRGB(10, 16, 30),
	PanelTransparency = 0.2,
	PanelCorner = UDim.new(0, 6),
	PanelPadding = 10,
	BarBackground = Color3.fromRGB(6, 10, 20),

	TextColor = Color3.fromRGB(240, 244, 252),
	MutedTextColor = Color3.fromRGB(150, 170, 205),
	StrokeColor = Color3.fromRGB(70, 170, 255),

	HealthColor = Color3.fromRGB(80, 200, 110),
	ShieldColor = Color3.fromRGB(235, 240, 250),
	FallbackResourceColor = Color3.fromRGB(120, 120, 130),
	ResourceColors = table.freeze(RESOURCE_COLORS),
	BlueTeamColor = BLUE_TEAM_COLOR,
	RedTeamColor = RED_TEAM_COLOR,
	TeamColors = table.freeze(TEAM_COLORS),

	BodyTextSize = 18,
	SmallTextSize = 16,
	TitleTextSize = 22,
	-- Pressed with a thumb, so never smaller than this.
	ButtonHeight = 48,
})

return Module
