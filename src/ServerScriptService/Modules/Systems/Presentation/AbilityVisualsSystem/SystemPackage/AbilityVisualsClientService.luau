--!strict

const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const AbilityNetwork = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityNetwork"
)

-- Studs above the ground that effects are drawn at, about chest height.
const EFFECT_HEIGHT = 2.5
const FLAT_THICKNESS = 0.2
const WHITE = Color3.new(1, 1, 1)
-- A ring that lasts longer than this marks an area over time, like an aura,
-- so it stays up instead of bursting as a shockwave.
const AURA_MIN_DURATION = 1.2
const AURA_TRANSPARENCY = 0.75
-- Seconds an aura takes to fade at the end, and the burst that opens it.
const AURA_FADE = 0.3
const AURA_BURST = 0.45
-- A shockwave grows from this share of its radius.
const SHOCKWAVE_START = 0.3
const BURST_LINE_COUNT = 6
const BURST_LINE_THICKNESS = 0.18
const PILLAR_HEIGHT = 7
const PILLAR_LIFETIME = 0.2
const BEAM_HEIGHT = 1
const BEAM_GLOW_WIDTH = 1.6
const BEAM_CORE_WIDTH = 0.4
-- An orb's diameter as a share of its projectile's width, kept in a range
-- that reads from the camera.
const ORB_SHARE = 1.2
const MIN_ORB_SIZE = 0.9
const MAX_ORB_SIZE = 3
const ORB_GLOW_SCALE = 1.8
const TRAIL_LIFETIME = 0.25
-- Radians of arc each segment of a slash covers, at most, so a full spin
-- still reads as a curve.
const SLASH_SEGMENT_ARC = 0.28
const MIN_SLASH_SEGMENTS = 8
const SLASH_WIDTH = 0.7
const SLASH_LIFT = 0.6
-- The share of a slash's duration spent sweeping across its arc.
const SLASH_SWEEP_SHARE = 0.4
-- Each arc segment overlaps the next by this share, so the arc reads whole.
const SLASH_OVERLAP = 1.2

const AbilityTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityTypes"
)

type Effect = AbilityTypes.Effect

type MovingProjectile = {
	Part: Part,
	Glow: Part,
	Color: Color3,
	Position: Vector3,
	Direction: Vector3,
	Speed: number,
	-- Studs left to travel.
	Remaining: number,
}

local Module = {}

local folder: Folder? = nil
local projectiles: { MovingProjectile } = {}
local random = Random.new()

local function createEffectPart(color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

--[[
	Tweens a part toward goal over duration, optionally after a delay, then
	destroys it.
]]
local function tweenAway(
	part: BasePart,
	duration: number,
	goal: { [string]: any },
	options: { Delay: number?, Easing: Enum.EasingDirection? }?
)
	local info = TweenInfo.new(
		duration,
		Enum.EasingStyle.Quad,
		if options and options.Easing then options.Easing else Enum.EasingDirection.Out,
		0,
		false,
		if options and options.Delay then options.Delay else 0
	)
	local tween = TweenService:Create(part, info, goal)
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

local function flatDisc(color: Color3, position: Vector3, diameter: number): Part
	local disc = createEffectPart(color)
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(FLAT_THICKNESS, diameter, diameter)
	disc.CFrame = CFrame.new(position + Vector3.new(0, FLAT_THICKNESS, 0))
		* CFrame.Angles(0, 0, math.pi / 2)
	return disc
end

--[[
	An impact: a ground flash and an energy dome that grow out to the radius,
	speed lines bursting outward, and a pillar of light at the center.
]]
local function shockwave(
	effectFolder: Folder,
	position: Vector3,
	radius: number,
	color: Color3,
	duration: number
)
	local bright = color:Lerp(WHITE, 0.5)

	local disc = flatDisc(color, position, radius * 2 * SHOCKWAVE_START)
	disc.Transparency = 0.2
	disc.Parent = effectFolder
	tweenAway(disc, duration, {
		Size = Vector3.new(FLAT_THICKNESS, radius * 2, radius * 2),
		Transparency = 1,
	})

	local dome = createEffectPart(color)
	dome.Shape = Enum.PartType.Ball
	dome.Material = Enum.Material.ForceField
	dome.Size = Vector3.one * radius * 2 * SHOCKWAVE_START
	dome.CFrame = CFrame.new(position)
	dome.Parent = effectFolder
	tweenAway(dome, duration * 0.8, { Size = Vector3.one * radius * 2, Transparency = 1 })

	local spin = random:NextNumber(0, math.pi * 2)
	for index = 1, BURST_LINE_COUNT do
		local angle = spin + index / BURST_LINE_COUNT * math.pi * 2
		local outward = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local start = position
			+ outward * radius * SHOCKWAVE_START
			+ Vector3.new(0, EFFECT_HEIGHT * 0.4, 0)
		local line = createEffectPart(bright)
		line.Size = Vector3.new(BURST_LINE_THICKNESS, BURST_LINE_THICKNESS, radius * 0.5)
		line.CFrame = CFrame.lookAt(start, start + outward)
		line.Parent = effectFolder
		tweenAway(line, duration * 0.6, {
			CFrame = line.CFrame + outward * radius * 0.8,
			Size = Vector3.new(BURST_LINE_THICKNESS, BURST_LINE_THICKNESS, radius * 0.1),
			Transparency = 1,
		})
	end

	local pillar = createEffectPart(bright)
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(PILLAR_HEIGHT, radius * 0.6, radius * 0.6)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, PILLAR_HEIGHT / 2, 0))
		* CFrame.Angles(0, 0, math.pi / 2)
	pillar.Transparency = 0.3
	pillar.Parent = effectFolder
	tweenAway(pillar, PILLAR_LIFETIME, {
		Size = Vector3.new(PILLAR_HEIGHT, 0.05, 0.05),
		Transparency = 1,
	})
end

--[[
	A lasting area, such as an aura: a see-through disc that opens with a
	burst and fades at the end.
]]
local function aura(
	effectFolder: Folder,
	position: Vector3,
	radius: number,
	color: Color3,
	duration: number
)
	local disc = flatDisc(color, position, radius * 2)
	disc.Transparency = AURA_TRANSPARENCY
	disc.Parent = effectFolder
	tweenAway(disc, AURA_FADE, { Transparency = 1 }, { Delay = duration - AURA_FADE })
	shockwave(effectFolder, position, radius, color, AURA_BURST)
end

--[[
	A bright core inside a wider glow. The glow flares out and fades while
	the core thins away.
]]
local function beam(
	effectFolder: Folder,
	from: Vector3,
	to: Vector3,
	width: number,
	color: Color3,
	duration: number
)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local frame = CFrame.lookAt((from + to) / 2, to)

	local glow = createEffectPart(color)
	glow.Size = Vector3.new(width * BEAM_GLOW_WIDTH, BEAM_HEIGHT, length)
	glow.CFrame = frame
	glow.Transparency = 0.35
	glow.Parent = effectFolder
	tweenAway(glow, duration, {
		Size = Vector3.new(width * BEAM_GLOW_WIDTH * 1.6, BEAM_HEIGHT * 1.5, length),
		Transparency = 1,
	})

	local core = createEffectPart(color:Lerp(WHITE, 0.65))
	core.Size = Vector3.new(width * BEAM_CORE_WIDTH, BEAM_HEIGHT * 0.5, length)
	core.CFrame = frame
	core.Parent = effectFolder
	tweenAway(
		core,
		duration,
		{ Size = Vector3.new(0.05, 0.05, length), Transparency = 0.6 },
		{ Easing = Enum.EasingDirection.In }
	)

	local flash = createEffectPart(color:Lerp(WHITE, 0.4))
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * width * 1.5
	flash.CFrame = CFrame.new(to)
	flash.Parent = effectFolder
	tweenAway(flash, duration * 0.6, { Size = Vector3.one * width * 3, Transparency = 1 })
end

--[[
	A crescent that sweeps across its arc, thickest in the middle, then fades.
]]
local function slash(
	effectFolder: Folder,
	effect: {
		Position: Vector3,
		Direction: Vector3,
		Radius: number,
		Arc: number,
		Color: Color3,
		Duration: number,
	}
)
	local center = effect.Position + Vector3.new(0, EFFECT_HEIGHT * SLASH_LIFT, 0)
	local heading = math.atan2(effect.Direction.X, effect.Direction.Z)
	local distance = effect.Radius * 0.85
	local segmentCount = math.max(MIN_SLASH_SEGMENTS, math.ceil(effect.Arc / SLASH_SEGMENT_ARC))
	local segmentLength = effect.Arc * distance / segmentCount * SLASH_OVERLAP
	local sweepTime = effect.Duration * SLASH_SWEEP_SHARE
	for index = 1, segmentCount do
		local along = (index - 0.5) / segmentCount
		local angle = heading - effect.Arc / 2 + effect.Arc * along
		local point = center + Vector3.new(math.sin(angle), 0, math.cos(angle)) * distance
		local tangent = Vector3.new(math.cos(angle), 0, -math.sin(angle))
		local width = SLASH_WIDTH * (0.3 + 0.7 * math.sin(math.pi * along))
		local appearDelay = sweepTime * along
		-- A bright thin core over a wider band in the effect's color.
		for _, layer in { { Share = 1, Tint = 0.15 }, { Share = 0.4, Tint = 0.75 } } do
			local part = createEffectPart(effect.Color:Lerp(WHITE, layer.Tint))
			part.Size = Vector3.new(width * layer.Share, 0.12, segmentLength)
			part.CFrame = CFrame.lookAt(point, point + tangent)
			-- Every segment holds until the sweep ends, so the arc fades as one.
			task.delay(appearDelay, function()
				part.Parent = effectFolder
				tweenAway(
					part,
					effect.Duration - sweepTime,
					{ Transparency = 1 },
					{ Delay = sweepTime - appearDelay }
				)
			end)
		end
	end
end

local function launchOrb(effectFolder: Folder, effect: Effect)
	if effect.Kind ~= "Projectile" then
		return
	end
	local position = effect.Origin + Vector3.new(0, EFFECT_HEIGHT, 0)
	local size = math.clamp(effect.Width * ORB_SHARE, MIN_ORB_SIZE, MAX_ORB_SIZE)

	local orb = createEffectPart(effect.Color:Lerp(WHITE, 0.55))
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * size
	orb.CFrame = CFrame.lookAt(position, position + effect.Direction)

	local glow = createEffectPart(effect.Color)
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.one * size * ORB_GLOW_SCALE
	glow.Transparency = 0.55
	glow.CFrame = orb.CFrame
	glow.Parent = effectFolder

	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, size / 2, 0)
	top.Parent = orb
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -size / 2, 0)
	bottom.Parent = orb
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.FaceCamera = true
	trail.Lifetime = TRAIL_LIFETIME
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(effect.Color:Lerp(WHITE, 0.3), effect.Color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0.1)
	trail.Parent = orb
	orb.Parent = effectFolder

	table.insert(projectiles, {
		Part = orb,
		Glow = glow,
		Color = effect.Color,
		Position = position,
		Direction = effect.Direction,
		Speed = effect.Speed,
		Remaining = effect.Range,
	})
end

local function onEffect(effect: Effect)
	local effectFolder = folder
	if not effectFolder then
		return
	end
	local lift = Vector3.new(0, EFFECT_HEIGHT, 0)

	if effect.Kind == "Projectile" then
		launchOrb(effectFolder, effect)
	elseif effect.Kind == "Ring" then
		if effect.Duration >= AURA_MIN_DURATION then
			aura(effectFolder, effect.Position, effect.Radius, effect.Color, effect.Duration)
		else
			shockwave(effectFolder, effect.Position, effect.Radius, effect.Color, effect.Duration)
		end
	elseif effect.Kind == "Beam" then
		beam(
			effectFolder,
			effect.From + lift,
			effect.To + lift,
			effect.Width,
			effect.Color,
			effect.Duration
		)
	elseif effect.Kind == "Slash" then
		slash(effectFolder, effect)
	end
end

--[[
	Ends a projectile with a flash. The orb hides at once, but stays a moment
	longer so its trail can fade out behind it.
]]
local function finishProjectile(projectile: MovingProjectile)
	local effectFolder = folder
	local orb = projectile.Part
	orb.Transparency = 1
	projectile.Glow:Destroy()
	if effectFolder then
		local flash = createEffectPart(projectile.Color:Lerp(WHITE, 0.4))
		flash.Shape = Enum.PartType.Ball
		flash.Size = orb.Size
		flash.CFrame = CFrame.new(projectile.Position)
		flash.Parent = effectFolder
		tweenAway(flash, TRAIL_LIFETIME, { Size = orb.Size * 2.5, Transparency = 1 })
	end
	task.delay(TRAIL_LIFETIME, function()
		orb:Destroy()
	end)
end

local function stepProjectiles(deltaTime: number)
	for index = #projectiles, 1, -1 do
		local projectile = projectiles[index]
		local stepLength = math.min(projectile.Speed * deltaTime, projectile.Remaining)
		projectile.Position += projectile.Direction * stepLength
		projectile.Remaining -= stepLength
		local frame = CFrame.lookAt(projectile.Position, projectile.Position + projectile.Direction)
		projectile.Part.CFrame = frame
		projectile.Glow.CFrame = frame

		if projectile.Remaining <= 0 then
			finishProjectile(projectile)
			projectiles[index] = projectiles[#projectiles]
			projectiles[#projectiles] = nil
		end
	end
end

function Module:Start()
	local effectFolder = Instance.new("Folder")
	effectFolder.Name = "AbilityEffects"
	effectFolder.Parent = workspace
	folder = effectFolder

	AbilityNetwork.Effect.OnClientEvent:Connect(onEffect)
	RunService.RenderStepped:Connect(stepProjectiles)
end

return Module
