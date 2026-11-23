--!strict

local Module = {
	-- Client to server: (slot, aim x, aim z, target unit id or nil).
	CastRequest = script.CastRequest,
	-- Server to the hero's owner: { [Slot]: AbilityInfo }.
	LoadoutChanged = script.LoadoutChanged,
	-- Server to the hero's owner: (slot, cooldown seconds, server time it ends).
	CooldownStarted = script.CooldownStarted,
	-- Server to the hero's owner: (ability name, server time it ends), or
	-- ("", 0) when the channel stops.
	ChannelChanged = script.ChannelChanged,
	-- Server to every client: an AbilityTypes.Effect to draw.
	Effect = script.Effect,
}

return Module
