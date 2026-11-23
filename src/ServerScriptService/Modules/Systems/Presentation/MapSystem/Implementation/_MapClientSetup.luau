--!strict

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")

const MapClientService = require("../SystemPackage/MapClientService")

-- Greybox colors until the real map art exists.
const GROUND_COLOR = Color3.fromRGB(70, 96, 64)
const OUTSIDE_COLOR = Color3.fromRGB(40, 44, 52)
const RIVER_COLOR = Color3.fromRGB(64, 120, 170)
const LANE_COLOR = Color3.fromRGB(176, 158, 120)
const RING_COLOR = Color3.fromRGB(96, 88, 104)
const CAMP_COLOR = Color3.fromRGB(48, 62, 44)
const BOSS_PIT_COLOR = Color3.fromRGB(90, 60, 110)
const PAD_COLOR = Color3.fromRGB(120, 230, 160)
const BASE_COLORS: { [MapLayout.MapTeam]: Color3 } = {
	Blue = Color3.fromRGB(60, 86, 130),
	Red = Color3.fromRGB(130, 64, 64),
}
const FOUNTAIN_COLORS: { [MapLayout.MapTeam]: Color3 } = {
	Blue = Color3.fromRGB(110, 170, 255),
	Red = Color3.fromRGB(255, 130, 130),
}
-- Red's routes are Blue's run backward, so drawing Blue's covers every lane.
const DRAWN_ROUTES_TEAM: MapLayout.MapTeam = "Blue"

-- Studs of dark ground drawn past the playable square's edge.
const OUTSIDE_MARGIN = 120
-- Radii in studs, by camp kind.
const CAMP_RADII = {
	Small = 6,
	CrystalGolem = 9,
	EmberBeetle = 9,
	Skyray = 18,
	HiveQueen = 26,
}
const PAD_RADIUS = 4

-- Draw order, bottom to top.
const RIVER_LAYER = 1
const RING_LAYER = 2
const LANE_LAYER = 3
const BASE_LAYER = 4
const DETAIL_LAYER = 5

local Module = {}

function Module:Start()
	MapClientService:DrawGround(
		MapLayout.HalfSize + OUTSIDE_MARGIN,
		OUTSIDE_COLOR,
		Enum.Material.Slate
	)
	MapClientService:DrawSquare(
		Vector3.zero,
		MapLayout.HalfSize * 2,
		GROUND_COLOR,
		RIVER_LAYER - 0.5
	)
	MapClientService:DrawPath(MapLayout.River, MapLayout.RiverWidth, RIVER_COLOR, RIVER_LAYER)
	MapClientService:DrawDisc(
		MapLayout.CrashRing.Position,
		MapLayout.CrashRing.Radius,
		RING_COLOR,
		RING_LAYER
	)

	for _, route in MapLayout.Routes[DRAWN_ROUTES_TEAM] do
		MapClientService:DrawPath(route, MapLayout.LaneWidth, LANE_COLOR, LANE_LAYER)
	end

	for team, base in MapLayout.Bases do
		-- Annotated because luau-lsp types a loop key over string literals as string.
		local mapTeam: MapLayout.MapTeam = team :: MapLayout.MapTeam
		MapClientService:DrawSquare(base.Center, base.Size, BASE_COLORS[mapTeam], BASE_LAYER)
		MapClientService:DrawDisc(
			base.Fountain,
			base.FountainRadius,
			FOUNTAIN_COLORS[mapTeam],
			DETAIL_LAYER
		)
	end

	for _, camp in MapLayout.Camps do
		local color = if camp.Team then CAMP_COLOR else BOSS_PIT_COLOR
		MapClientService:DrawDisc(camp.Position, CAMP_RADII[camp.Kind], color, DETAIL_LAYER)
	end

	for _, pad in MapLayout.LaunchPads do
		MapClientService:DrawDisc(pad.Position, PAD_RADIUS, PAD_COLOR, DETAIL_LAYER)
	end
end

return Module
