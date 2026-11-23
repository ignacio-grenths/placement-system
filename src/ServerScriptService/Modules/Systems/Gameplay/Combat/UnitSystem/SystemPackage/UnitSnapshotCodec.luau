--!strict

-- Unreliable remotes drop payloads over 1,000 bytes, so chunks stay under.
const MAX_CHUNK_BYTES = 900
-- An f64 server time and a u16 entry count.
const HEADER_BYTES = 10
const ENTRY_BYTES = 19
const ENTRIES_PER_CHUNK = (MAX_CHUNK_BYTES - HEADER_BYTES) // ENTRY_BYTES
-- Positions travel in twentieths of a stud, so a signed 16-bit value covers
-- 1,638 studs either side of the origin.
const POSITION_SCALE = 20
const MAX_INT16 = 32767
const MAX_UINT16 = 65535
const FACING_STEPS = 256
const TAU = math.pi * 2

export type Entry = {
	Id: number,
	X: number,
	Z: number,
	Facing: number,
	Flags: number,
	Health: number,
	MaxHealth: number,
	Resource: number,
	MaxResource: number,
	Shield: number,
	-- The unit's MoveEpoch, 0 to 255.
	Epoch: number,
}

local Module = {}

-- Seconds between snapshots. Clients read it to tell a unit that stood
-- still (and so was skipped) from one that moved.
Module.SendInterval = 1 / 15

Module.Flags = table.freeze({
	Dead = 1,
	Untargetable = 2,
	Stunned = 4,
	Rooted = 8,
	-- Grown huge, like Brakk in Colossus Form.
	Enlarged = 16,
	-- Out of the receiving team's sight. The entry's other fields are blank.
	Hidden = 32,
})

function Module.quantizePosition(value: number): number
	return math.clamp(math.round(value * POSITION_SCALE), -MAX_INT16, MAX_INT16)
end

function Module.quantizeFacing(facing: number): number
	return math.round(facing % TAU / TAU * FACING_STEPS) % FACING_STEPS
end

--[[
	Rounds up, so a unit left with a sliver of health never shows as zero.
]]
function Module.quantizeAmount(value: number): number
	return math.clamp(math.ceil(value), 0, MAX_UINT16)
end

--[[
	Packs entries into as many payloads as it takes to keep each one under
	the unreliable remote limit. No entries gives no payloads.
]]
function Module.encode(serverTime: number, entries: { Entry }): { buffer }
	local payloads = {}
	local count = #entries
	local first = 1

	while first <= count do
		local last = math.min(first + ENTRIES_PER_CHUNK - 1, count)
		local payload = buffer.create(HEADER_BYTES + (last - first + 1) * ENTRY_BYTES)
		buffer.writef64(payload, 0, serverTime)
		buffer.writeu16(payload, 8, last - first + 1)

		local offset = HEADER_BYTES
		for index = first, last do
			local entry = entries[index]
			buffer.writeu16(payload, offset, entry.Id)
			buffer.writei16(payload, offset + 2, Module.quantizePosition(entry.X))
			buffer.writei16(payload, offset + 4, Module.quantizePosition(entry.Z))
			buffer.writeu8(payload, offset + 6, Module.quantizeFacing(entry.Facing))
			buffer.writeu8(payload, offset + 7, entry.Flags)
			buffer.writeu16(payload, offset + 8, Module.quantizeAmount(entry.Health))
			buffer.writeu16(payload, offset + 10, Module.quantizeAmount(entry.MaxHealth))
			buffer.writeu16(payload, offset + 12, Module.quantizeAmount(entry.Resource))
			buffer.writeu16(payload, offset + 14, Module.quantizeAmount(entry.MaxResource))
			buffer.writeu16(payload, offset + 16, Module.quantizeAmount(entry.Shield))
			buffer.writeu8(payload, offset + 18, entry.Epoch % 256)
			offset += ENTRY_BYTES
		end

		table.insert(payloads, payload)
		first = last + 1
	end

	return payloads
end

function Module.decode(payload: buffer): (number, { Entry })
	local serverTime = buffer.readf64(payload, 0)
	local count = buffer.readu16(payload, 8)
	local entries = table.create(count)

	local offset = HEADER_BYTES
	for _ = 1, count do
		table.insert(entries, {
			Id = buffer.readu16(payload, offset),
			X = buffer.readi16(payload, offset + 2) / POSITION_SCALE,
			Z = buffer.readi16(payload, offset + 4) / POSITION_SCALE,
			Facing = buffer.readu8(payload, offset + 6) / FACING_STEPS * TAU,
			Flags = buffer.readu8(payload, offset + 7),
			Health = buffer.readu16(payload, offset + 8),
			MaxHealth = buffer.readu16(payload, offset + 10),
			Resource = buffer.readu16(payload, offset + 12),
			MaxResource = buffer.readu16(payload, offset + 14),
			Shield = buffer.readu16(payload, offset + 16),
			Epoch = buffer.readu8(payload, offset + 18),
		})
		offset += ENTRY_BYTES
	end

	return serverTime, entries
end

return Module
