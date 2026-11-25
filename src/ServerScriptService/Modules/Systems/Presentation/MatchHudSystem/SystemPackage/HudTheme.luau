--!strict

const BLUE_TEAM_COLOR = Color3.fromRGB(80, 150, 255)
const RED_TEAM_COLOR = Color3.fromRGB(240, 90, 90)

-- Keyed by resource kind.
const RESOURCE_COLORS: { [string]: Color3? } = {
	Mana = Color3.fromRGB(50, 130, 235),
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
-- The fantasy look: forest-night panels, nearly square corners, and thin gold
-- trim. Titles use a serif; body text and numbers stay in Gotham, which stays
-- sharp at HUD sizes.
local Module = table.freeze({
	Font = Enum.Font.GothamBold,
	BodyFont = Enum.Font.GothamMedium,
	TitleFont = Enum.Font.Merriweather,

	PanelColor = Color3.fromRGB(10, 20, 24),
	PanelTransparency = 0.1,
	PanelCorner = UDim.new(0, 3),
	PanelPadding = 10,
	BarBackground = Color3.fromRGB(4, 10, 12),

	TextColor = Color3.fromRGB(240, 230, 210),
	MutedTextColor = Color3.fromRGB(165, 158, 140),
	StrokeColor = Color3.fromRGB(200, 170, 110),
	BrightStrokeColor = Color3.fromRGB(240, 210, 130),
	GoldColor = Color3.fromRGB(255, 205, 80),

	HealthColor = Color3.fromRGB(60, 190, 90),
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
