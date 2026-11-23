--!strict

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")

const JungleNetwork = require("./JungleNetwork")

export type BuffState = JungleNetwork.BuffState

local Module = {}

-- (buffs) whenever the local hero's buffs change.
Module.BuffsChanged = Signal.new() :: Signal.Signal<{ BuffState }>
-- (boss kind, team that slew it)
Module.BossSlain = Signal.new() :: Signal.Signal<string, string>

local buffs: { BuffState } = {}

local function readBuffs(payload: unknown): { BuffState }
	local result: { BuffState } = {}
	if typeof(payload) ~= "table" then
		return result
	end
	for _, entry in payload :: { unknown } do
		if typeof(entry) ~= "table" then
			continue
		end
		local fields = entry :: { [string]: unknown }
		local id = fields.Id
		local expiresAt = fields.ExpiresAt
		local stacks = fields.Stacks
		if
			typeof(id) == "string"
			and typeof(expiresAt) == "number"
			and typeof(stacks) == "number"
		then
			table.insert(result, {
				Id = id,
				ExpiresAt = expiresAt,
				Stacks = stacks,
			})
		end
	end
	return result
end

local function onBuffsChanged(payload: unknown)
	buffs = readBuffs(payload)
	Module.BuffsChanged:Fire(buffs)
end

local function onBossSlain(kind: unknown, team: unknown)
	if typeof(kind) == "string" and typeof(team) == "string" then
		Module.BossSlain:Fire(kind, team)
	end
end

--[[
	Returns the local hero's buffs as last sent. A timed buff can have run
	out since: compare its ExpiresAt with workspace:GetServerTimeNow().
]]
function Module:GetBuffs(): { BuffState }
	return buffs
end

function Module:Init()
	JungleNetwork.BuffsChanged.OnClientEvent:Connect(onBuffsChanged)
	JungleNetwork.BossSlain.OnClientEvent:Connect(onBossSlain)
end

return Module
