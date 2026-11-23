--!strict

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Module = {}

--[[
	Creates a signal. Each handler runs in its own thread, so a handler that
	errors or yields never stops the code that fired the signal, such as the
	unit simulation's step.
]]
function Module.new<T...>(): Signal<T...>
	local handlers: { [Connection]: ((T...) -> ())? } = {}

	local signal = {} :: Signal<T...>

	function signal.Connect(_self: Signal<T...>, handler: (T...) -> ()): Connection
		local connection = {} :: Connection
		connection.Connected = true

		function connection.Disconnect(self: Connection)
			self.Connected = false
			handlers[self] = nil
		end

		handlers[connection] = handler
		return connection
	end

	function signal.Fire(_self: Signal<T...>, ...: T...)
		for connection, handler in table.clone(handlers) do
			if connection.Connected and handler then
				task.spawn(handler, ...)
			end
		end
	end

	return signal
end

return Module
