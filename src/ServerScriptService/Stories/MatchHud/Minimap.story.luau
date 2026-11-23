--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")
const Minimap = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/Minimap"
)

const BLUE = Color3.fromRGB(80, 150, 255)
const RED = Color3.fromRGB(240, 90, 90)
const LOCAL_HERO = Color3.fromRGB(120, 255, 150)

const CONTROLS = {
	Layout = UILabs.Ordered(
		UILabs.ControlGroup({
			-- Width and height in UI units: 220 on a desktop, 150 on touch.
			Size = UILabs.Ordered(UILabs.Slider(220, 120, 320, 10), 1),
		}),
		1
	),
	Units = UILabs.Ordered(
		UILabs.ControlGroup({
			ShowStructures = UILabs.Ordered(true, 1),
			-- Aliens per team spread along each lane.
			AliensPerLane = UILabs.Ordered(UILabs.Slider(6, 0, 20, 1), 2),
		}),
		2
	),
}

type StoryProps = {
	controls: {
		Layout: { Size: () -> number },
		Units: { ShowStructures: () -> boolean, AliensPerLane: () -> number },
	},
	target: Frame,
}

local function toMapPoint(position: Vector3): Vector2
	local size = MapLayout.HalfSize * 2
	return Vector2.new(
		(position.X + MapLayout.HalfSize) / size,
		(position.Z + MapLayout.HalfSize) / size
	)
end

local function toMapPath(points: { Vector3 }): { Vector2 }
	local mapped = {}
	for _, point in points do
		table.insert(mapped, toMapPoint(point))
	end
	return mapped
end

local function story(props: StoryProps)
	local controls = props.controls
	local blueTeam: MapLayout.MapTeam = "Blue"
	local lanes = {}
	for _, route in MapLayout.Routes[blueTeam] do
		table.insert(lanes, toMapPath(route))
	end

	local function dots(): { Minimap.MinimapDot }
		local list = {}
		if controls.Units.ShowStructures() then
			for _, spot in MapLayout.Structures do
				table.insert(list, {
					Position = toMapPoint(spot.Position),
					Color = if spot.Team == "Blue" then BLUE else RED,
					Size = 8,
				})
			end
		end
		-- Aliens spread evenly between the two cores along each lane.
		local count = controls.Units.AliensPerLane()
		for _, route in MapLayout.Routes[blueTeam] do
			for index = 1, count do
				local share = index / (count + 1)
				local position = route[1]:Lerp(route[#route], share)
				table.insert(list, {
					Position = toMapPoint(position),
					Color = if share < 0.5 then BLUE else RED,
					Size = 4,
				})
			end
		end
		table.insert(list, {
			Position = toMapPoint(MapLayout.Bases[blueTeam].Fountain),
			Color = LOCAL_HERO,
			Size = 13,
		})
		return list
	end

	return Minimap({
		Lanes = lanes,
		River = toMapPath(MapLayout.River),
		Dots = dots,
		Size = controls.Layout.Size,
	})
end

return {
	summary = "The minimap with every structure, aliens along each lane, and the local hero at the Blue fountain.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
