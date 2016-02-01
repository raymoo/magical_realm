-- A player system is a generic system that handles some various player-specific
-- state, and may have some serialization procedure.

-- More concretely, a system is defined by a table with the following elements:
--
--  initialize_player(): Returns a state for a new player.
--
--  serialize_player(state): Takes a state state, and
--   returns a serialized (string) state.
--
--  deserialize_player(ser_state): Takes player serialized (string) state
--    ser_state, and returns the deserialized state.
--    For any valid state s, deserialize_player(serialize_player(s)) should
--    be semantically equivalent to s.
--
--  on_player_join(player): Guaranteed to be run after player state has been
--    loaded. Takes the player name.
--
--  on_player_leave(player): Guaranteed to be run before player state has been
--    unloaded. Takes the player name.
--
-- on_player_join and on_player_leave are optional.


local function copy_shal(orig)

	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs(orig) do
			copy[orig_key] = orig_value
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	    return copy
end


player_systems = {}


local world_path = minetest.get_worldpath()

local mod_data_path = world_path .. "/psystem-saves"


minetest.mkdir(mod_data_path)


-- The list of active systems
local systems = {}
player_systems.systems = systems


local function make_save_path(system, player)
	return mod_data_path .. "/" .. system .. "-" .. player
end


local function read_player_file(system, player)
	local the_file = io.open(make_save_path(system, player), "rb")
	local contents
	if (the_file == nil) then
		contents = nil
	else
		contents = the_file:read("*a")
		the_file:close()
	end
	
	return contents
end


local function write_player_file(system, player, data)
	local the_file = io.open(make_save_path(system, player), "wb")
	the_file:write(data)
	the_file:close()
end


local function persist_player_state(system, player, state)

	local cur_system = systems[system]

	minetest.log("verbose", "Persisting" .. system .. " save for " .. player)

	if (cur_system == nil) then
		minetest.log("error", "System does not exist")
		return
	end

	if (cur_system.serialize_player == nil) then
		minetest.log("error", "No serialization function, not writing data.")
		return
	end

	write_player_file(system, player, cur_system.serialize_player(state))

	minetest.log("verbose", "Persist finished")
end


-- System is the string name of the system, player is the name of the joining
-- player. Returns the deserialized state of the player.
local function load_player_state(system, player)

	local cur_system = systems[system]

	local loaded_state

	minetest.log("verbose", "Loading " .. system .. " save for " .. player)

	if (cur_system == nil) then
		minetest.log("error", "System does not exist")
		return nil
	end
	
	local pfile = read_player_file(system, player)
	
	if (pfile == nil) then
		minetest.log("verbose", "No player save. Initializing player.")
		
		if (cur_system.initialize_player == nil) then
			minetest.log("error", "No initialization function for " .. system)
			return nil
		else
			local new_state = cur_system.initialize_player()
			persist_player_state(system, player, new_state)
			return cur_system.initialize_player()
		end
		
		
	else
		minetest.log("verbose", "Player save found. Loading.")

		if (cur_system.deserialize_player == nil) then
			minetest.log("error", "No deserialization function for " .. system)
			return nil
		else
			return cur_system.deserialize_player(pfile)
		end
	end
end


local function get_loaded_player_state(system, player)

	local cur_system = systems[system]
	
	return copy_shal(cur_system.active_state[player])
end


local function set_loaded_player_state(system, player, new_state)

	local cur_system = systems[system]

	cur_system.active_state[player] = copy_shal(new_state)
end


local function del_loaded_player_state(system, player)
	
	set_loaded_player_state(system, player, nil)
end


local function handle_player_join(system, player)

	minetest.log("verbose", "Handling join of " .. player .. " for " .. system)

	local cur_system = systems[system]

	if (cur_system == nil) then
		minetest.log("error", "System does not exist")
		return
	end

	local player_state = load_player_state(system, player)

	set_loaded_player_state(system, player, player_state)

	if (cur_system.on_player_join ~= nil) then
		cur_system.on_player_join(player)
	end
end


-- Also used on shutdown
local function handle_player_leave(system, player)

	minetest.log("verbose", "Handling leave of " .. player .. " for " .. system)

	local cur_system = systems[system]

	if(cur_system == nil) then
		minetest.log("error", "System does not exist")
		return
	end

	if (cur_system.on_player_leave ~= nil) then
		cur_system.on_player_leave(player)
	end

	local player_state = get_loaded_player_state(system, player)
		
	persist_player_state(system, player, player_state)

	del_loaded_player_state(system, player)
end


local function persist_actives(system)

	minetest.log("verbose", "Handling shutdown for " .. system)

	local cur_system = systems[system]

	if (cur_system == nil) then
		minetest.log("error", "System does not exist")
		return
	end

	local actives = cur_system.active_state

	for p_name in pairs(actives) do
		local player_state = get_loaded_player_state(system, p_name)

		persist_player_state(system, p_name, player_state)
	end
end
		

player_systems.register_player_system = function(name, system_def)

	minetest.debug(type(system_def))

	systems[name] = copy_shal(system_def)

	systems[name].active_state = {}

	minetest.register_on_joinplayer(function(player)

			local p_name = player:get_player_name()

			handle_player_join(name, p_name)
	end)


	minetest.register_on_leaveplayer(function(player)

			local p_name = player:get_player_name()

			handle_player_leave(name, p_name)
	end)
	
	minetest.register_on_shutdown(function()
			persist_actives(name)
	end)
end


-- Gets the player state. Is expensive if the player is not currently in-game.
-- Takes the system and player name and returns its state.
player_systems.get_state = function(system, p_name)
	
	local loaded_state = get_loaded_player_state(system, p_name)

	if (loaded_state ~= nil) then
		return loaded_state
	else
		return load_player_state(system, p_name)
	end
end


-- Sets the player state. Is expensive if the player is not currently in-game.
-- Takes the system and player name, as well as a state to set.
player_systems.set_state = function(system, p_name, state)

	if (get_loaded_player_state(system, p_name) ~= nil) then
		set_loaded_player_state(system, p_name, state)
	else
		persist_player_state(system, p_name, state)
	end
end


player_systems.persist = persist_actives


-- Gets a table of active states. Changing the fields will change the state.
player_systems.active_states = function(system)

	return systems[system] and systems[system].active_state
end
