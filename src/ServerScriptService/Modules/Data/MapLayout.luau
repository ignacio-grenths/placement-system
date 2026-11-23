--!strict

-- Positions below are written in the plan's 400 by 400 map drawing
-- (docs/moba-plan.html). SCALE turns drawing units into studs, and the
-- drawing's center becomes the world origin.
const SCALE = 1.5
const DRAWING_CENTER = 200

export type MapTeam = "Blue" | "Red"
export type LaneName = "Top" | "Mid" | "Bot"
export type StructureTier = "Outer" | "Inner" | "Gate" | "Core"
export type CampKind = "Small" | "CrystalGolem" | "EmberBeetle" | "Skyray" | "HiveQueen"

export type StructureSpot = {
	Id: string,
	Team: MapTeam,
	Lane: LaneName?,
	Tier: StructureTier,
	Position: Vector3,
}

export type Base = {
	Center: Vector3,
	Size: number,
	Fountain: Vector3,
	FountainRadius: number,
}

export type CampSpot = {
	-- Unique among camps. Id repeats on both sides of the map; Key does not.
	Key: string,
	Id: string,
	Kind: CampKind,
	-- Nil for the shared river bosses.
	Team: MapTeam?,
	Position: Vector3,
}

-- A camp on Blue's side. buildCamps adds Red's mirror of it and the keys.
type CampPlacement = {
	Id: string,
	Kind: CampKind,
	Position: Vector3,
}

-- A jungle wall: a thick line on the ground with round ends.
export type WallSpot = {
	From: Vector3,
	To: Vector3,
	-- Studs from the wall's center line to its face.
	Radius: number,
}

-- A patch of brush: tall alien plants that hide anyone inside from enemies
-- outside it. Shaped like a wall, but units walk through it.
export type BrushSpot = {
	From: Vector3,
	To: Vector3,
	-- Studs from the patch's center line to its edge.
	Radius: number,
}

export type LaunchPad = {
	Team: MapTeam,
	Position: Vector3,
	Landing: Vector3,
}

-- A route runs from its team's base to the enemy core.
export type Route = { Vector3 }

local function at(x: number, y: number): Vector3
	return Vector3.new((x - DRAWING_CENTER) * SCALE, 0, (y - DRAWING_CENTER) * SCALE)
end

-- The map mirrors across the line between the two bases, which swaps the
-- drawing's x and y. Red's half is built from Blue's this way, so the two
-- sides can never drift apart.
local function mirror(position: Vector3): Vector3
	return Vector3.new(position.Z, 0, position.X)
end

local function mirrorAll(positions: { Vector3 }): { Vector3 }
	local mirrored = table.create(#positions)
	for _, position in positions do
		table.insert(mirrored, mirror(position))
	end
	return mirrored
end

const LANE_NAMES: { LaneName } = { "Top", "Mid", "Bot" }

const BLUE_CORE = at(45, 355)
const RED_CORE = mirror(BLUE_CORE)

const BLUE_ROUTES: { [LaneName]: Route } = {
	Top = { at(45, 330), at(45, 60), at(60, 45), at(330, 45), RED_CORE },
	Mid = { at(70, 330), at(330, 70), RED_CORE },
	Bot = { at(70, 355), at(340, 355), at(355, 340), at(355, 70), RED_CORE },
}

-- Towers and gates stand at the lane's edge, not its center line, so aliens
-- walking the lane pass beside them instead of pushing into them head-on.
const BLUE_STRUCTURES: { StructureSpot } = {
	{ Id = "TopOuter", Team = "Blue", Lane = "Top", Tier = "Outer", Position = at(54, 150) },
	{ Id = "TopInner", Team = "Blue", Lane = "Top", Tier = "Inner", Position = at(54, 240) },
	{ Id = "TopGate", Team = "Blue", Lane = "Top", Tier = "Gate", Position = at(54, 298) },
	{ Id = "MidOuter", Team = "Blue", Lane = "Mid", Tier = "Outer", Position = at(143.6, 243.6) },
	{ Id = "MidInner", Team = "Blue", Lane = "Mid", Tier = "Inner", Position = at(115.6, 271.6) },
	{ Id = "MidGate", Team = "Blue", Lane = "Mid", Tier = "Gate", Position = at(93.6, 293.6) },
	{ Id = "BotOuter", Team = "Blue", Lane = "Bot", Tier = "Outer", Position = at(250, 346) },
	{ Id = "BotInner", Team = "Blue", Lane = "Bot", Tier = "Inner", Position = at(160, 346) },
	{ Id = "BotGate", Team = "Blue", Lane = "Bot", Tier = "Gate", Position = at(108, 346) },
	{ Id = "Core", Team = "Blue", Tier = "Core", Position = BLUE_CORE },
}

const BLUE_CAMPS: { CampPlacement } = {
	{ Id = "CrystalGolem", Kind = "CrystalGolem", Position = at(100, 200) },
	{ Id = "WestSmallNorth", Kind = "Small", Position = at(85, 150) },
	{ Id = "WestSmallSouth", Kind = "Small", Position = at(125, 235) },
	{ Id = "EmberBeetle", Kind = "EmberBeetle", Position = at(210, 300) },
	{ Id = "SouthSmallWest", Kind = "Small", Position = at(165, 320) },
	{ Id = "SouthSmallEast", Kind = "Small", Position = at(255, 318) },
}

const WALL_RADIUS = 2

-- Blue's half of the jungle. Walls line the lanes with gaps to enter by,
-- shield camps from the river, and narrow the routes between camps.
const BLUE_WALLS: { WallSpot } = {
	-- West jungle, between top lane, mid lane, and the river.
	{ From = at(62, 170), To = at(62, 225), Radius = WALL_RADIUS },
	{ From = at(95, 138), To = at(106, 152), Radius = WALL_RADIUS },
	{ From = at(112, 222), To = at(128, 206), Radius = WALL_RADIUS },
	{ From = at(150, 215), To = at(160, 205), Radius = WALL_RADIUS },
	{ From = at(85, 232), To = at(100, 222), Radius = WALL_RADIUS },
	-- South jungle, between mid lane, bot lane, and the river.
	{ From = at(185, 338), To = at(235, 338), Radius = WALL_RADIUS },
	{ From = at(225, 272), To = at(240, 287), Radius = WALL_RADIUS },
	{ From = at(180, 300), To = at(190, 288), Radius = WALL_RADIUS },
	{ From = at(140, 285), To = at(155, 275), Radius = WALL_RADIUS },
	{ From = at(270, 300), To = at(282, 312), Radius = WALL_RADIUS },
}

const BRUSH_RADIUS = 5

-- Blue's half of the brush: one beside each lane, two flanking mid, two on
-- the river bank by the bosses, and one on each jungle path.
const BLUE_BRUSHES: { BrushSpot } = {
	{ From = at(58, 100), To = at(58, 118), Radius = BRUSH_RADIUS },
	{ From = at(290, 342), To = at(308, 342), Radius = BRUSH_RADIUS },
	{ From = at(168, 212), To = at(176, 204), Radius = BRUSH_RADIUS },
	{ From = at(184, 236), To = at(196, 224), Radius = BRUSH_RADIUS },
	{ From = at(88, 118), To = at(96, 126), Radius = BRUSH_RADIUS },
	{ From = at(246, 276), To = at(256, 286), Radius = BRUSH_RADIUS },
	{ From = at(78, 182), To = at(78, 196), Radius = BRUSH_RADIUS },
	{ From = at(204, 322), To = at(218, 322), Radius = BRUSH_RADIUS },
}

const BLUE_LAUNCH_PADS: { LaunchPad } = {
	{ Team = "Blue", Position = at(80, 255), Landing = at(150, 150) },
	{ Team = "Blue", Position = at(135, 305), Landing = at(250, 250) },
}

local function buildRoutes(): { [MapTeam]: { [LaneName]: Route } }
	local redRoutes: { [LaneName]: Route } = {}
	for lane, route in BLUE_ROUTES do
		redRoutes[lane :: LaneName] = mirrorAll(route)
	end
	return { Blue = BLUE_ROUTES, Red = redRoutes }
end

local function buildStructures(): { StructureSpot }
	local structures = table.clone(BLUE_STRUCTURES)
	for _, spot in BLUE_STRUCTURES do
		table.insert(structures, {
			Id = spot.Id,
			Team = "Red",
			Lane = spot.Lane,
			Tier = spot.Tier,
			Position = mirror(spot.Position),
		})
	end
	return structures
end

local function buildCamps(): { CampSpot }
	local camps: { CampSpot } = {}
	for _, placement in BLUE_CAMPS do
		table.insert(camps, {
			Key = `Blue:{placement.Id}`,
			Id = placement.Id,
			Kind = placement.Kind,
			Team = "Blue",
			Position = placement.Position,
		})
		table.insert(camps, {
			Key = `Red:{placement.Id}`,
			Id = placement.Id,
			Kind = placement.Kind,
			Team = "Red",
			Position = mirror(placement.Position),
		})
	end
	table.insert(camps, {
		Key = "HiveQueen",
		Id = "HiveQueen",
		Kind = "HiveQueen",
		Position = at(125, 125),
	})
	table.insert(camps, { Key = "Skyray", Id = "Skyray", Kind = "Skyray", Position = at(275, 275) })
	return camps
end

local function buildWalls(): { WallSpot }
	local walls = table.clone(BLUE_WALLS)
	for _, wall in BLUE_WALLS do
		table.insert(walls, {
			From = mirror(wall.From),
			To = mirror(wall.To),
			Radius = wall.Radius,
		})
	end
	return walls
end

local function buildBrushes(): { BrushSpot }
	local brushes = table.clone(BLUE_BRUSHES)
	for _, brush in BLUE_BRUSHES do
		table.insert(brushes, {
			From = mirror(brush.From),
			To = mirror(brush.To),
			Radius = brush.Radius,
		})
	end
	return brushes
end

local function buildLaunchPads(): { LaunchPad }
	local pads = table.clone(BLUE_LAUNCH_PADS)
	for _, pad in BLUE_LAUNCH_PADS do
		table.insert(pads, {
			Team = "Red",
			Position = mirror(pad.Position),
			Landing = mirror(pad.Landing),
		})
	end
	return pads
end

local Module = {}

-- Studs from the center to each edge of the playable square.
Module.HalfSize = DRAWING_CENTER * SCALE
Module.LaneWidth = 18
Module.RiverWidth = 45

Module.LaneNames = LANE_NAMES

Module.Routes = buildRoutes()
Module.Structures = buildStructures()
Module.Camps = buildCamps()
Module.Walls = buildWalls()
Module.Brushes = buildBrushes()
Module.LaunchPads = buildLaunchPads()

Module.Bases = {
	Blue = {
		Center = at(57, 343),
		Size = 86 * SCALE,
		Fountain = at(25, 375),
		FountainRadius = 30,
	},
	Red = {
		Center = mirror(at(57, 343)),
		Size = 86 * SCALE,
		Fountain = mirror(at(25, 375)),
		FountainRadius = 30,
	},
} :: { [MapTeam]: Base }

Module.River = { at(60, 60), at(340, 340) }

Module.CrashRing = {
	Position = at(200, 200),
	Radius = 24 * SCALE,
}

return Module
