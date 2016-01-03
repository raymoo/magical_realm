
-- Spell: moon_shoes
-- Name: Moon Shoes
--
-- Gives a player low gravity effect.
--
-- Metadata: A table with two values
--   uses - number of uses
--   duration - duration of spell
--
-- Result Data: A table with two values
--  player - reference to the player
--  duration - duration
--
-- Smart Formspec
--   A field for entering use count (No infinites)
--   A field for entering duration in minutes (At least 1)
--
--   param - A table with last_meta, succ_cb, err_cb

local spell_name = "moon_shoes"
local disp_name = "Moon Shoes"

local gravity_ratio = 0.2

local description =
	"Reduces your gravity significantly.\n\n"
	.. "Cost: 2 * uses * duration"

local function handle_prep(uses_str, dur_str, succ_cb, err_cb)

	local uses = tonumber(uses_str)

	local dur = tonumber(dur_str)

	if (uses == nil) then
		err_cb("Uses not a number")
		return
	end

	if (uses ~= math.floor(uses)) then
		err_cb("Uses is not an integer")
		return
	end

	if (uses < 1) then
		err_cb("You must have at least one use.")
		return
	end

	if (dur == nil) then
		err_cb("Duration not a number")
		return
	end

	if (dur ~= math.floor(dur)) then
		err_cb("Duration not an integer")
		return
	end

	if (dur < 1) then
		err_cb("Duration must be at least 1 minute.")
		return
	end
	

	succ_cb({ uses = uses,
		  duration = dur
	})
end

local form_name = "travel_spells:moon_shoes"


local ej_form = smartfs.create(form_name, function(state)

	state:size(5,5.5)

	local def_uses = (state.param.last_meta and state.param.last_meta.uses) or 1

	local uses_field = state:field(1,1, 3,1, "uses", "Uses")
	uses_field:setText("" .. def_uses)

	local dur_field = state:field(1,2.5, 3,1, "dur", "Duration (minutes)")

	local butt = state:button(1.5,4, 2,1, "prepare", "Prepare")

	butt:click(function(self, state)

			local uses_str = uses_field:getText()
			local dur_str = dur_field:getText()

			handle_prep(uses_str, dur_str, state.param.succ_cb, state.param.err_cb)
	end)
end)


local function show_form(last_meta, p_name, succ_cb, err_cb)

	ej_form:show(p_name,
			{ last_meta = last_meta,
			  succ_cb = succ_cb,
			  err_cb = err_cb
	})
end


local function calculate_cost(aptitudes, meta)
	return 2 * meta.uses * meta.duration
end


local function begin_cast(meta, player, pointed_thing, callback)

	local p_name = player:get_player_name()
	
	if (meta.uses ~= nil) then
		meta.uses = meta.uses - 1
	end

	if (player == nil) then return end

	callback(0,
		 { player = player,
		   duration = meta.duration
	})
	
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


local function make_puff(pos)

	local pos_offset = {x=0.5, y=0.5, z=0.5}

	minetest.add_particlespawner({ amount = 5,
		  time = 0.2,
		  minpos = vector.subtract(pos, pos_offset),
		  maxpos = vector.add(pos, pos_offset),
		  minvel = {x=-0.5, y=-0.5, z=-0.5},
		  maxvel = {x=0.5, y=0.5, z=0.5},
		  minexptime = 2,
		  maxexptime = 4,
		  minsize = 10,
		  maxsize = 10,
		  texture = smoke_texture
	})
end



local function bouncy(player)

	if (not player:is_player()) then return end

	local p_name = player:get_player_name()
	
	local override = player:get_physics_override()

	override.gravity = gravity_ratio

	player:set_physics_override(override)

	return
end


local function unbouncy(effect, player)
	
	if (player == nil or not player:is_player()) then return end

	local p_name = player:get_player_name()
	
	local override = player:get_physics_override()

	override.gravity = 1

	player:set_physics_override(override)

	return
end


playereffects.register_effect_type("travel_spells:moon_shoes",
				  "Moon Shoes",
				  nil,
				  {
					  "gravity"
				  },
				  bouncy,
				  unbouncy
)


local function do_it(tab)

	
	local player = tab.player
	local dur = tab.duration

	local succ = playereffects.apply_effect_type("travel_spells:moon_shoes",
						     dur * 60,
						     player)

	if (not succ) then
		minetest.chat_send_player(player:get_player_name(), "Could not activate.")
	end
end


magic_spells.register_spell(spell_name,
			    { display_name = disp_name,
			      description = description,
			      prep_form = show_form,
			      prep_cost = calculate_cost,
			      on_begin_cast = begin_cast,
			      on_finish_cast = do_it
})
