--!strict

const RunService = game:GetService("RunService")

const Signal = require("./Signal")

-- Seconds each step covers above speed 1, whatever the frame rate, so a
-- sped-up match plays out the same on any machine.
const FIXED_STEP = 1 / 30
-- Seconds of steps one frame may run. Roblox kills a thread that runs too
-- long, which would stop a step halfway and leave units broken.
const STEP_BUDGET = 0.05

type Timer = {
	DueAt: number,
	Callback: (...any) -> (),
	Arguments: { any },
	-- Kept apart from Arguments, since a nil argument would cut #Arguments.
	ArgumentCount: number,
}

local Module = {}

-- Fires once per simulation step with the step's length in seconds. At
-- speed 1 that is once per frame.
Module.Stepped = Signal.new() :: Signal.Signal<number>

local speed = 1
-- Above speed 1, the simulation's own time, which moves only in steps.
local simulationTime = 0
-- Server time minus os.clock(), fixed when the speed goes above 1.
local serverClockOffset = 0
-- Simulation seconds owed but not yet stepped.
local owedTime = 0
local timers: { Timer } = {}
local connection: RBXScriptConnection? = nil

local function runDueTimers()
	local now = Module.now()
	local index = 1
	while index <= #timers do
		local timer = timers[index]
		if timer.DueAt <= now then
			-- Swap-remove: the order timers run in within one step is free.
			timers[index] = timers[#timers]
			timers[#timers] = nil
			task.spawn(timer.Callback, table.unpack(timer.Arguments, 1, timer.ArgumentCount))
		else
			index += 1
		end
	end
end

local function onHeartbeat(frameTime: number)
	if speed == 1 then
		runDueTimers()
		Module.Stepped:Fire(frameTime)
		return
	end

	owedTime += frameTime * speed
	const frameStart = os.clock()
	while owedTime >= FIXED_STEP do
		if os.clock() - frameStart > STEP_BUDGET then
			-- Catching up later would only make longer frames.
			owedTime = 0
			break
		end
		owedTime -= FIXED_STEP
		simulationTime += FIXED_STEP
		runDueTimers()
		Module.Stepped:Fire(FIXED_STEP)
	end
end

-- The clock only ticks once a running game uses it, so requiring it in edit
-- mode (specs, stories, the command bar) connects nothing.
local function ensureRunning()
	if not connection and RunService:IsRunning() then
		connection = RunService.Heartbeat:Connect(onHeartbeat)
	end
end

--[[
	Returns the simulation's time in seconds, for measuring durations the
	way os.clock() does. At speed 1 it equals os.clock().
]]
function Module.now(): number
	return if speed == 1 then os.clock() else simulationTime
end

--[[
	Returns the simulation's time on the server clock clients share, for
	times sent to them. At speed 1 it equals workspace:GetServerTimeNow().
]]
function Module.serverTime(): number
	return if speed == 1 then workspace:GetServerTimeNow() else simulationTime + serverClockOffset
end

--[[
	Runs the simulation this many times as fast as real time, for balance
	runs with nobody watching. Above 1 it steps in fixed slices and slows
	down when the machine can't keep up.
]]
function Module.setSpeed(multiplier: number)
	assert(multiplier >= 1 and multiplier % 1 == 0, "Speed must be a whole number from 1")
	if speed == 1 and multiplier > 1 then
		simulationTime = os.clock()
		serverClockOffset = workspace:GetServerTimeNow() - os.clock()
	end
	speed = multiplier
	ensureRunning()
end

function Module.getSpeed(): number
	return speed
end

--[[
	Connects a handler to every simulation step, like Heartbeat.
]]
function Module.onStep(handler: (frameTime: number) -> ()): Signal.Connection
	ensureRunning()
	return Module.Stepped:Connect(handler)
end

--[[
	Calls callback with the arguments once the simulation has run for the
	given seconds, like task.delay.
]]
function Module.delay(seconds: number, callback: (...any) -> (), ...: any)
	ensureRunning()
	table.insert(timers, {
		DueAt = Module.now() + seconds,
		Callback = callback,
		Arguments = { ... },
		ArgumentCount = select("#", ...),
	})
end

--[[
	Yields the calling thread until the simulation has run for the given
	seconds, like task.wait.
]]
function Module.wait(seconds: number)
	local thread = coroutine.running()
	Module.delay(seconds, function()
		task.spawn(thread)
	end)
	coroutine.yield()
end

return Module
