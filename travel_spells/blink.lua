
-- Spell: blink
-- Name: Blink
--
-- Teleports the user to a random nearby location
--
-- To make a node safe to blink onto, add it to the group:blink_safe.
-- If you are me, you can also add them to the safe_nodes list.
--
-- Metadata: A table with one numerical field, uses
--
-- Result Data: Reference to the player
--
-- Smart Formspec:
--   A field for entering use count - 0 for infinite
--   A button to finish preparation
--
--   param - A table with last_meta, succ_cb, err_cb

local safe_nodes =
	{ "group:soil",
	  "group:tree",
	  "group:wool",
	  "group:sand",
	  "group:stone",
	  "group:wood",
	  "group:blink_safe"
	}


local spell_name = "blink"
local disp_name = "Blink"

local range = 20

local description =
	"Teleport to a random nearby location. Useful to escape dangerous "
	.. "situations. \n\n"
	.. "If unlimited uses is chosen, startup is 5 seconds.\n\n"
	.. "Cost: uses\n"
	.. "15 (Unlimited)"


local function handle_prep(uses_str, succ_cb, err_cb)

	local uses = tonumber(uses_str)

	if (uses == nil) then
		err_cb("Uses not a number")
		return
	end

	if (uses ~= math.floor(uses)) then
		err_cb("Uses is not an integer")
		return
	end

	if (uses == 0) then
		uses = nil
	end

	succ_cb({ uses = uses })
end


local form_name = "travel_spells:blink"


local blink_form = smartfs.create(form_name, function(state)

	state:size(5,3)

	local def_uses = (state.param.last_meta and state.param.last_meta.uses) or 1

	local uses_field = state:field(1,1, 3,1, "uses", "Uses (0 for infinite)")
	uses_field:setText("" .. def_uses)

	local butt = state:button(1.5,1.5, 2,1, "prepare", "Prepare")

	butt:click(function(self, state)

			local uses_str = uses_field:getText()

			handle_prep(uses_str, state.param.succ_cb, state.param.err_cb)
	end)
end)


local function show_form(last_meta, p_name, succ_cb, err_cb)

	blink_form:show(p_name,
			{ last_meta = last_meta,
			  succ_cb = succ_cb,
			  err_cb = err_cb
	})
end


local function calculate_cost(aptitudes, meta)

	if (meta.uses == nil) then
		return 15
	else
		return meta.uses
	end
end

local function begin_cast(meta, player, pointed_thing, callback)

	local p_name = player:get_player_name()
	
	if (meta.uses ~= nil) then
		meta.uses = meta.uses - 1
	end

	if (player == nil) then return end

	if (meta.uses ~= nil) then
		callback(0, player)
	else
		callback(5, player)
	end
	
	if (meta.uses ~= nil) then
		if (p_name ~= nil) then
			minetest.chat_send_player(p_name, "You now have " .. meta.uses .. " uses.")
		end
	end

	if (meta.uses == 0) then
		return nil
	else
		return meta
	end
end


local function blink(player)

	local p_pos = player:getpos()

	if (p_pos == nil) then return end

	local minB = vector.add({x=-range, y=-range, z=-range}, p_pos)
	local maxB = vector.add({x=range, y=range, z=range}, p_pos)

	local candidates = minetest.find_nodes_in_area_under_air(minB, maxB, safe_nodes)

	local chosen = candidates[math.random(#candidates)]


	if (chosen == nil) then
		minetest.chat_send_player(player:get_player_name(), "Could not find an open spot")
		return
	end

	
	local target_pos = vector.add(chosen, {x=0, y=1, z=0})
	
	player:moveto(target_pos, false)
end


magic_spells.register_spell(spell_name,
			    { display_name = disp_name,
			      description = description,
			      prep_form = show_form,
			      prep_cost = calculate_cost,
			      on_begin_cast = begin_cast,
			      on_finish_cast = blink
})
