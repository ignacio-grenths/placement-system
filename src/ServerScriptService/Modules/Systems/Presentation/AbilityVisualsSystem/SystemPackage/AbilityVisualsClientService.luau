--!strict

const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const AbilityNetwork = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityNetwork"
)

-- Studs above the ground that effects are drawn at, about chest height.
const EFFECT_HEIGHT = 2.5
const PROJECTILE_LENGTH = 3
const PROJECTILE_THICKNESS = 0.8
const FLAT_THICKNESS = 0.2
const RING_START_TRANSPARENCY = 0.3
const BEAM_HEIGHT = 1

const AbilityTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityTypes"
)

type Effect = AbilityTypes.Effect

type MovingProjectile = {
	Part: Part,
	Position: Vector3,
	Direction: Vector3,
	Speed: number,
	-- Studs left to travel.
	Remaining: number,
}

local Module = {}

local folder: Folder? = nil
local projectiles: { MovingProjectile } = {}

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

local function fadeAndDestroy(part: BasePart, duration: number)
	local tween = TweenService:Create(part, TweenInfo.new(duration), { Transparency = 1 })
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

local function onEffect(effect: Effect)
	local effectFolder = folder
	if not effectFolder then
		return
	end
	local lift = Vector3.new(0, EFFECT_HEIGHT, 0)

	if effect.Kind == "Projectile" then
		local position = effect.Origin + lift
		local part = createEffectPart(effect.Color)
		part.Size = Vector3.new(effect.Width, PROJECTILE_THICKNESS, PROJECTILE_LENGTH)
		part.CFrame = CFrame.lookAt(position, position + effect.Direction)
		part.Parent = effectFolder
		table.insert(projectiles, {
			Part = part,
			Position = position,
			Direction = effect.Direction,
			Speed = effect.Speed,
			Remaining = effect.Range,
		})
	elseif effect.Kind == "Ring" then
		local part = createEffectPart(effect.Color)
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(FLAT_THICKNESS, effect.Radius * 2, effect.Radius * 2)
		part.CFrame = CFrame.new(effect.Position + Vector3.new(0, FLAT_THICKNESS, 0))
			* CFrame.Angles(0, 0, math.pi / 2)
		part.Transparency = RING_START_TRANSPARENCY
		part.Parent = effectFolder
		fadeAndDestroy(part, effect.Duration)
	elseif effect.Kind == "Beam" then
		local from = effect.From + lift
		local to = effect.To + lift
		local part = createEffectPart(effect.Color)
		part.Size = Vector3.new(effect.Width, BEAM_HEIGHT, (to - from).Magnitude)
		part.CFrame = CFrame.lookAt((from + to) / 2, to)
		part.Parent = effectFolder
		fadeAndDestroy(part, effect.Duration)
	end
end

local function stepProjectiles(deltaTime: number)
	for index = #projectiles, 1, -1 do
		local projectile = projectiles[index]
		local stepLength = math.min(projectile.Speed * deltaTime, projectile.Remaining)
		projectile.Position += projectile.Direction * stepLength
		projectile.Remaining -= stepLength
		projectile.Part.CFrame =
			CFrame.lookAt(projectile.Position, projectile.Position + projectile.Direction)

		if projectile.Remaining <= 0 then
			projectile.Part:Destroy()
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
