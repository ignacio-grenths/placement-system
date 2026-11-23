--!strict

const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

const RENDER_STEP_NAME = "OverheadCamera"
-- Angle of the view below the horizon, in radians.
const PITCH = math.rad(56)
const FIELD_OF_VIEW = 45
const DEFAULT_DISTANCE = 85
const MIN_DISTANCE = 55
const MAX_DISTANCE = 110
const ZOOM_STEP = 6
-- Pixels from the screen edge where the mouse pans an unlocked camera.
const EDGE_PAN_MARGIN = 16
-- Studs per second.
const PAN_SPEED = 120

local Module = {}

local focusProvider: (() -> Vector3?)? = nil
local boundsHalfSize = math.huge
local isLocked = true
local focus = Vector3.zero
local distance = DEFAULT_DISTANCE

local function clampToBounds(point: Vector3): Vector3
	return Vector3.new(
		math.clamp(point.X, -boundsHalfSize, boundsHalfSize),
		0,
		math.clamp(point.Z, -boundsHalfSize, boundsHalfSize)
	)
end

local function getEdgePanDirection(): Vector3
	local mouse = UserInputService:GetMouseLocation()
	local viewport = workspace.CurrentCamera.ViewportSize
	local x = 0
	local z = 0
	if mouse.X <= EDGE_PAN_MARGIN then
		x = -1
	elseif mouse.X >= viewport.X - EDGE_PAN_MARGIN then
		x = 1
	end
	-- The camera looks toward -Z, so the top of the screen is -Z.
	if mouse.Y <= EDGE_PAN_MARGIN then
		z = -1
	elseif mouse.Y >= viewport.Y - EDGE_PAN_MARGIN then
		z = 1
	end
	return Vector3.new(x, 0, z)
end

local function isMouseInput(): boolean
	local inputType = UserInputService:GetLastInputType()
	return inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseWheel
		or inputType == Enum.UserInputType.Keyboard
end

local function update(deltaTime: number)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FIELD_OF_VIEW

	local heroPosition = if focusProvider then focusProvider() else nil
	-- Touch and gamepad have no screen edges to pan with, so they stay locked.
	local isFollowing = isLocked
		or not isMouseInput()
		or UserInputService:IsKeyDown(Enum.KeyCode.Space)
	if isFollowing then
		if heroPosition then
			focus = heroPosition
		end
	else
		focus = clampToBounds(focus + getEdgePanDirection() * PAN_SPEED * deltaTime)
	end

	local offset = Vector3.new(0, math.sin(PITCH) * distance, math.cos(PITCH) * distance)
	camera.CFrame = CFrame.lookAt(focus + offset, focus)
end

local function onInputBegan(input: InputObject, isProcessed: boolean)
	if isProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Y then
		isLocked = not isLocked
	end
end

local function onInputChanged(input: InputObject, isProcessed: boolean)
	if isProcessed or input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return
	end
	distance = math.clamp(distance - input.Position.Z * ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
end

--[[
	Sets where the camera looks while locked: usually the local hero's drawn
	position. A provider that returns nil keeps the camera where it is.
]]
function Module:SetFocusProvider(provider: () -> Vector3?)
	focusProvider = provider
end

function Module:SetBounds(halfSize: number)
	boundsHalfSize = halfSize
end

function Module:IsLocked(): boolean
	return isLocked
end

function Module:SetLocked(locked: boolean)
	isLocked = locked
end

function Module:Start()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, update)
end

return Module
