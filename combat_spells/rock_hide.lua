
-- Spell: rock_hide
-- Name: Rock Hide
--
-- Gives the caster 1 hp of damage soak, for 10 seconds.
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

local spell_name = "rock_hide"
local disp_name = "Rock Hide"

local description =
	"Gives you two hearts of damage soak, but halves your speed.\n\n"
	.. "Cost: 4 * uses * duration"

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
v	end

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

local form_name = "combat_spells:rock_hide"

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
	return 4 * meta.uses * meta.duration
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


local function do_it(tab)

	
	local player = tab.player
	local dur = tab.duration

	local succ = monoidal_effects.apply_effect("combat_spells:rock_hide",
						   dur * 60,
						   player:get_player_name())

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


-- Player-indexed damage soak values
local soaks = {}


local function set_soak(p_name, soak)
	if not soaks[p_name] then
		soaks[p_name] = {}
	end

	soaks[p_name] = soak
end


minetest.register_on_leaveplayer(function(player)
		soaks[player:get_player_name()] = nil
end)


minetest.register_on_player_hpchange(function(player, change)
		local soak = soaks[player:get_player_name()]

		if soak == nil then return change end

		if change > -1 then return change end

		return math.min(change + soak, 0)
end, true)


monoidal_effects.register_monoid("combat_spells:soak",
	{ combine = function(x, y) return x + y end,
	  fold = function(elems)
		  local tot = 0
		  for k, v in pairs(elems) do
			  tot = tot + v
		  end

		  return tot
	  end,
	  identity = 0,
	  apply = function(soak, player)
		  set_soak(player:get_player_name(), soak)
	  end
})


monoidal_effects.register_type("combat_spells:rock_hide",
			       { disp_name = "Rock Hide",
				 tags = {magic = true},
				 monoids = {["combat_spells:soak"] = true,
					 ["magic_monoids:speed_malus"] = true},
				 cancel_on_death = true,
				 values = {["combat_spells:soak"] = 4,
					 ["magic_monoids:speed_malus"] = 0.5 },
})

