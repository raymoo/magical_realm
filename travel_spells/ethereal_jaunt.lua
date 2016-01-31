
-- Spell: ethereal_jaunt
-- Name: Ethereal Jaunt
--
-- Makes a player invisible, weightless, unable to cast spells, 0 collisionbox,
-- able to fly, noclip, and half speed. But unable to cast or interact.
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

local smoke_texture = "magic_particles_smoke.png^[mask:travel_spells_cyan.png"

local spell_name = "ethereal_jaunt"
local disp_name = "Ethereal Jaunt"

local description =
	"Sends you to the Ethereal Plane.\n"
	.. "You are invisible, weightless, and can fly, even through walls.\n"
	.. "If you are in solid material when you rematerialize, you will die.\n\n"
	.. "Cost: uses * duration"

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

local form_name = "travel_spells:ethereal_jaunt"


local ej_form = smartfs.create(form_name, function(state)

	state:size(5,5.5)

	local def_uses = (state.param.last_meta and state.param.last_meta.uses) or 1
	local def_dur = (state.param.last_meta and state.param.last_meta.duration) or 1

	local uses_field = state:field(1,1, 3,1, "uses", "Uses")
	uses_field:setText("" .. def_uses)

	local dur_field = state:field(1,2.5, 3,1, "dur", "Duration (seconds)")
	dur_field:setText("" .. def_dur)

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
	return meta.uses * meta.duration
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



local function immaterialize(player)


	local p_name = player:get_player_name()
	local privs = minetest.get_player_privs(p_name)

	player:set_properties({
			collisionbox = {0},
			visual_size = {x=0, y=0},
			makes_footstep_sound = false
	})

	privs.interact = nil

	minetest.set_player_privs(p_name, privs)

	player:set_nametag_attributes({color = {a=0}})

	return
end


local function materialize(player)
	
	local p_name = player:get_player_name()
	local privs = minetest.get_player_privs(p_name)

	player:set_properties({
			collisionbox = {-0.3, -1, -0.3, 0.3, 1, 0.3},
			visual_size = {x=1, y=1},
			makes_footstep_sound = true
	})

	privs.interact = true

	minetest.set_player_privs(p_name, privs)

	player:set_nametag_attributes({color = {a=255, r=255, g=255, b=255}})

	return
end


local function eth_change(val1, val2, player)

	local p_pos = player:getpos()
	
	if val1 ~= val2 then
		make_puff(vector.add(p_pos, {x=0,y=1,z=0}))
		minetest.sound_play("travel_spells_ethereal_jaunt",
				    {
					    pos = p_pos
		})
	end

	-- Change from ethereal to non-ethereal
	if val1 and not val2 then
		local node = minetest.get_node(p_pos)

		local node_def = minetest.registered_nodes[node.name]

		if (node_def and node_def.walkable == true) then
			local safety = minetest.find_node_near(p_pos, 2, "air")

			local p_name = player:get_player_name()

			if (safety == nil) then
				minetest.after(0, function()
					local hp = player:get_hp()

					if (hp ~= nil and hp ~= 0) then
						player:set_hp(0)
					end
					
					minetest.chat_send_player(p_name, "You are crushed.")
				end)
			else
				player:moveto(safety, true)
			end
		end
	end
end


monoidal_effects.register_monoid("travel_spells:ethereal",
	{ combine = function(v1, v2) return v1 or v2 end,
	  fold = function(elems)
		  for k, v in pairs(elems) do
			  if v then return true end
		  end

		  return false
	  end,
	  identity = false,
	  apply = function(v, player)
		  if v then
			  immaterialize(player)
		  else
			  materialize(player)
		  end
	  end,
	  on_change = eth_change,
})


monoidal_effects.register_type("travel_spells:ethereal",
			       { disp_name = "Ethereal (k to fly, h to noclip)",
				 tags = {magic = true},
				 monoids = { ["magic_monoids:speed_malus"] = true,
					     fly = true,
					     noclip = true,
					     ["travel_spells:ethereal"] = true,
				 },
				 cancel_on_death = true,
				 values = { ["magic_monoids:speed_malus"] = 0.5,
					    fly = true,
					    noclip = true,
					    ["travel_spells:ethereal"] = true,
				 }
})


local function do_it(tab)

	
	local player = tab.player
	local dur = tab.duration

	local succ = monoidal_effects.apply_effect("travel_spells:ethereal",
						   dur,
						   player:get_player_name())

	if (not succ) then
		minetest.chat_send_player(player:get_player_name(), "Could not jaunt")
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
