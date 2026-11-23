--!strict

-- A cylinder stands upright: Size.Y is its height and Size.X its diameter.
-- An ellipsoid fills its whole size, unlike a ball, which stays round. A
-- wedge slopes down toward its front.
export type PartShape = "Ball" | "Block" | "Cylinder" | "Ellipsoid" | "Wedge"

export type PartPlan = {
	Shape: PartShape,
	Size: Vector3,
	-- From the center of the part it is attached to, before that part turns.
	-- -Z is the front.
	Offset: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
}

local Module = {}

function Module.create(plan: PartPlan, transparency: number): BasePart
	local part: BasePart = if plan.Shape == "Wedge"
		then Instance.new("WedgePart")
		else Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = plan.Color
	part.Material = plan.Material or Enum.Material.SmoothPlastic
	part.Transparency = math.max(plan.Transparency or 0, transparency)

	if plan.Shape == "Ball" then
		(part :: Part).Shape = Enum.PartType.Ball
		part.Size = plan.Size
		part.CFrame = plan.Offset
	elseif plan.Shape == "Cylinder" then
		-- A cylinder part runs along its X axis, so it is stood upright.
		(part :: Part).Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(plan.Size.Y, plan.Size.X, plan.Size.Z)
		part.CFrame = plan.Offset * CFrame.Angles(0, 0, math.pi / 2)
	elseif plan.Shape == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		part.Size = plan.Size
		part.CFrame = plan.Offset
	else
		part.Size = plan.Size
		part.CFrame = plan.Offset
	end
	return part
end

--[[
	Fixes a detail part to a body, so moving the body carries it along. The
	body has to be at the origin, unturned, when this runs.
]]
function Module.attach(part: BasePart, body: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanQuery = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
	part.Parent = body
end

return Module
