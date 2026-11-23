--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const indexes = Vide.indexes
const read = Vide.read

const HudTheme = require("./HudTheme")

const GROUND_COLOR = Color3.fromRGB(46, 66, 46)
const LANE_COLOR = Color3.fromRGB(150, 135, 105)
const RIVER_COLOR = Color3.fromRGB(60, 105, 150)
const LANE_THICKNESS = 5
const RIVER_THICKNESS = 12

export type MinimapDot = {
	-- 0 to 1 across the map: X left to right, Y top to bottom.
	Position: Vector2,
	Color: Color3,
	-- Diameter in UI units.
	Size: number,
}

export type MinimapProps = {
	-- Paths in map coordinates (0 to 1), drawn under the dots.
	Lanes: { { Vector2 } },
	River: { Vector2 },
	Dots: () -> { MinimapDot },
	-- Width and height in UI units.
	Size: number | () -> number,
}

local function segment(
	from: Vector2,
	to: Vector2,
	size: () -> number,
	thickness: number,
	color: Color3
): Frame
	local offset = to - from
	local middle = (from + to) / 2
	return create("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(middle.X, middle.Y),
		Size = function()
			return UDim2.fromOffset(offset.Magnitude * size() + thickness, thickness)
		end,
		Rotation = math.deg(math.atan2(offset.Y, offset.X)),
		BackgroundColor3 = color,

		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
	})
end

local function path(
	points: { Vector2 },
	size: () -> number,
	thickness: number,
	color: Color3
): { Frame }
	local segments = {}
	for index = 1, #points - 1 do
		table.insert(segments, segment(points[index], points[index + 1], size, thickness, color))
	end
	return segments
end

--[[
	A top-down map of the arena with a dot for every unit worth tracking.
]]
local function minimap(props: MinimapProps): Frame
	local function getSize(): number
		return read(props.Size)
	end

	local lanes = {}
	for _, lane in props.Lanes do
		table.insert(lanes, path(lane, getSize, LANE_THICKNESS, LANE_COLOR))
	end

	return create("Frame")({
		Name = "Minimap",
		Size = function()
			local size = getSize()
			return UDim2.fromOffset(size, size)
		end,
		BackgroundColor3 = GROUND_COLOR,
		ClipsDescendants = true,

		create("UIStroke")({
			Color = HudTheme.StrokeColor,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		path(props.River, getSize, RIVER_THICKNESS, RIVER_COLOR),
		lanes,
		indexes(props.Dots, function(dot)
			return create("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = function()
					local position = dot().Position
					return UDim2.fromScale(position.X, position.Y)
				end,
				Size = function()
					local diameter = dot().Size
					return UDim2.fromOffset(diameter, diameter)
				end,
				BackgroundColor3 = function()
					return dot().Color
				end,
				ZIndex = 2,

				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			})
		end),
	})
end

return minimap
