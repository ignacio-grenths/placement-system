--!strict

const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const UserInputService = game:GetService("UserInputService")

const HeroControlNetwork = require("./HeroControlNetwork")

-- Holding the move button resends the move this often (seconds), so the
-- hero keeps following the cursor.
const HOLD_RESEND_INTERVAL = 0.15
const STICK_RESEND_INTERVAL = 0.15
const STICK_DEAD_ZONE = 0.25
-- Studs ahead of the hero that a stick move aims for.
const STICK_LOOKAHEAD = 8
const MARKER_DIAMETER = 3
const MARKER_HEIGHT = 0.3
const MARKER_COLOR = Color3.fromRGB(120, 255, 160)
const MARKER_FADE_TIME = 0.4

export type PickResult = { Kind: "Attack", UnitId: number } | { Kind: "Move", Position: Vector3 }

local Module = {}

local picker: ((Ray) -> PickResult?)? = nil
local heroPositionProvider: (() -> Vector3?)? = nil
local isHoldingMove = false
local holdTimer = 0
local stickDirection = Vector3.zero
local isStickActive = false
local stickTimer = 0
local marker: Part? = nil
local markerTween: Tween? = nil

local function getMarker(): Part
	local existing = marker
	if existing then
		return existing
	end

	local created = Instance.new("Part")
	created.Name = "MoveMarker"
	created.Shape = Enum.PartType.Cylinder
	created.Size = Vector3.new(0.1, MARKER_DIAMETER, MARKER_DIAMETER)
	created.Color = MARKER_COLOR
	created.Material = Enum.Material.Neon
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.CastShadow = false
	marker = created
	return created
end

local function showMarker(position: Vector3)
	local part = getMarker()
	if markerTween then
		markerTween:Cancel()
	end
	part.Transparency = 0
	part.CFrame = CFrame.new(position.X, MARKER_HEIGHT, position.Z)
		* CFrame.Angles(0, 0, math.pi / 2)
	part.Parent = workspace

	local tween = TweenService:Create(part, TweenInfo.new(MARKER_FADE_TIME), { Transparency = 1 })
	tween:Play()
	markerTween = tween
end

--[[
	A fresh click or tap: attack the enemy under it, or walk to the ground.
]]
local function commandAt(ray: Ray)
	local result = if picker then picker(ray) else nil
	if not result then
		return
	end

	if result.Kind == "Attack" then
		HeroControlNetwork.AttackCommand:FireServer(result.UnitId)
	else
		HeroControlNetwork.MoveCommand:FireServer(result.Position.X, result.Position.Z)
		showMarker(result.Position)
	end
end

--[[
	A held move button: keep walking toward the cursor, but never start an
	attack, so sweeping over an enemy doesn't lock onto it.
]]
local function followCursor(ray: Ray)
	local result = if picker then picker(ray) else nil
	if result and result.Kind == "Move" then
		HeroControlNetwork.MoveCommand:FireServer(result.Position.X, result.Position.Z)
	end
end

local function stepStick(deltaTime: number)
	if stickDirection.Magnitude <= STICK_DEAD_ZONE then
		if isStickActive then
			isStickActive = false
			HeroControlNetwork.StopCommand:FireServer()
		end
		return
	end

	stickTimer -= deltaTime
	if isStickActive and stickTimer > 0 then
		return
	end
	isStickActive = true
	stickTimer = STICK_RESEND_INTERVAL

	local heroPosition = if heroPositionProvider then heroPositionProvider() else nil
	if heroPosition then
		local target = heroPosition + stickDirection.Unit * STICK_LOOKAHEAD
		HeroControlNetwork.MoveCommand:FireServer(target.X, target.Z)
	end
end

local function update(deltaTime: number)
	if isHoldingMove then
		holdTimer -= deltaTime
		if holdTimer <= 0 then
			holdTimer = HOLD_RESEND_INTERVAL
			local mouse = UserInputService:GetMouseLocation()
			followCursor(workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y))
		end
	end
	stepStick(deltaTime)
end

local function onInputBegan(input: InputObject, isProcessed: boolean)
	if isProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isHoldingMove = true
		holdTimer = HOLD_RESEND_INTERVAL
		commandAt(workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y))
	elseif input.KeyCode == Enum.KeyCode.S then
		HeroControlNetwork.StopCommand:FireServer()
	end
end

local function onInputEnded(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isHoldingMove = false
	end
end

local function onInputChanged(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		-- Stick up points toward the top of the screen, which is -Z.
		stickDirection = Vector3.new(input.Position.X, 0, -input.Position.Y)
	end
end

local function onTouchTapInWorld(position: Vector2, isProcessedByUI: boolean)
	if isProcessedByUI then
		return
	end
	commandAt(workspace.CurrentCamera:ScreenPointToRay(position.X, position.Y))
end

--[[
	Sets what a click means: the picker turns a camera ray into an attack on
	a unit or a move to a ground point, or nil to ignore the click.
]]
function Module:SetPicker(newPicker: (Ray) -> PickResult?)
	picker = newPicker
end

function Module:SetHeroPositionProvider(provider: () -> Vector3?)
	heroPositionProvider = provider
end

function Module:Start()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.TouchTapInWorld:Connect(onTouchTapInWorld)
	RunService.RenderStepped:Connect(update)
end

return Module
