
-- Spell Info
--
-- Metadata: A table with two numerical fields:
--  count: The number of missiles
--  uses: The number of uses (nil for infinite)
--
-- Result Data: A table containing a reference to a target object, "target",
--   as well as the count field from the metadata, and the player, as player.
--
-- Smart Formspec:
--   A textlist allowing the choice of 1, 2, 3, 4, or 5 missiles
--   A field for entering use count (0 for infinite)
--   A button to finish preparation.
--
--   param - A table with metadata, succ_cb, err_cb


local spell_name = "magic_missile"

local description =
	"A homing bolt of force flies toward your target.\n\n"
	.. "Each missile does one heart of damage.\n"
	.. "If unlimited uses is chosen, startup is missile_count seconds.\n\n"
	.. "Cost: uses * missile_count \n"
	.. "missile_count^2 (Unlimited uses)"


local function handle_prep(count_str, uses_str, succ_cb, err_cb)

	local count = tonumber(count_str)

	local uses = tonumber(uses_str)


	if (uses == nil) then
		err_cb("Uses not a number")
		return
	end

	if (uses < 0) then
		err_cb("Uses is negative")
		return
	end

	if (uses ~= math.floor(uses)) then
		err_cb("Uses is not an integer")
		return
	end

	if (count == nil) then
		err_cb("No missile count selected")
		return
	end

		
	-- Infinite requested
	if (uses == 0) then
		uses = nil
	end

	succ_cb({ count = count,
		  uses = uses
	})
end


local mm_form = smartfs.create("combat_spells:magic_missile", function(state)
				       
	state:size(8,6)

	local def_count, def_uses

	if (state.param.metadata == nil) then
		def_count = 1
		def_uses = 0
	else
		def_count = state.param.metadata.count
		def_uses = state.param.metadata.uses or 0
	end
		

	local count_box = state:listbox(0.5,0.5, 3,7, "count")
	count_box:removeItem(1)

	count_box:addItem("1 Missile")
	count_box:addItem("2 Missiles")
	count_box:addItem("3 Missiles")
	count_box:addItem("4 Missiles")
	count_box:addItem("5 Missiles")


	local uses_field = state:field(4.5,2.5, 3,2, "uses", "Uses (0 for infinite)")
	uses_field:setText("" .. def_uses)

	local butt = state:button(4.5,5, 2,1, "prepare", "Prepare")

	count_box:onClick(function(self, state, idx)

			state.count_idx = tonumber(idx)
	end)

	butt:click(function(self, state)

			local count_str = state.count_idx or ""
			local uses_str = uses_field:getText()

			handle_prep(count_str, uses_str,
				    state.param.succ_cb, state.param.err_cb)

	end)
end)
	

local function show_form(last_meta, p_name, succ_cb, err_cb)
	mm_form:show(p_name,
		     {metadata = last_meta,
		      succ_cb = succ_cb,
		      err_cb = err_cb
	})
end


local function calculate_cost(aptitudes, meta)

	if (meta.uses == nil) then
		return math.ceil(math.pow(meta.count,2))
	else
		return math.ceil(meta.uses * meta.count)
	end

end


local function begin_cast(meta, player, pointed_thing, callback)

	local target = pointed_thing and pointed_thing.ref

	if target == nil then
		if (player:is_player()) then
			minetest.chat_send_player(player:get_player_name(),
						  "You must target an entity.")
		end
		
		return meta
	end


	if (meta.uses ~= nil) then
		meta.uses = meta.uses - 1
	end

	local startup
	if (meta.uses == nil) then
		startup = meta.count
	else
		startup = 0
	end

	callback(startup,
		 { target = target,
		   count = meta.count,
		   player = player
	})

	if (meta.uses ~= nil) then
		minetest.chat_send_player(player:get_player_name(), "You now have " .. meta.uses .. " uses.")
	end

	if (meta.uses == 0) then
		return nil
	else
		return meta
	end

end


local function cast_missile(result)

	local count = result.count

	local target = result.target

	local player = result.player

	if (target:getpos() == nil) then
		minetest.chat_send_player(player:get_player_name(), "Your target is gone!")
		return
	end

	for i = 1, count do

		local p_pos = player:getpos()

		local mis_pos = vector.add(p_pos, {x=0, y=1.4, z=0})

		local missile =
			minetest.add_entity(mis_pos, "combat_spells:magic_missile")

		if (missile ~= nil) then

			local ent = missile:get_luaentity()

			local x = math.random(-3, 3)
			local y = math.random(0, 3)
			local z = math.random(-3, 3)

			ent.target = target
			ent.magical_owner = player

			missile:setvelocity({x=x, y=y, z=z})
		end

	end

	minetest.sound_play("combat_spells_magic_missile",
			    {
				    pos = p_pos
	})

end


-- Target needs to be set when spawned.
minetest.register_entity("combat_spells:magic_missile",
			 { target = nil,
			   lifetime = 10,

			   magical_power = 2,
			   magical_reflect = function(self, new_owner)
				   
				   self.target = self.magical_owner
				   self.magical_owner = new_owner
			   end,
			   
			   hp_max = 1,
			   physical = true,
			   collide_with_objects = false,
			   collisionbox = { -0.1, -0.1, -0.1, 0.1, 0.1, 0.1 },
			   visual = "sprite",
			   visual_size = { x = 0.5, y = 0.5 },
			   textures = {"combat_spells_magic_missile.png"},
			   is_visible = true,

			   on_activate = function(self, staticdata, dtime_s)

				   self.object:set_armor_groups({immortal = 1})
			   end,

			   on_step = function(self, dtime)
				   
				   if (self.target == nil or self.target:getpos() == nil) then
					   self.object:remove()
					   return
				   end

				   local self_pos = self.object:getpos()

				   local other_pos =
					   vector.add(self.target:getpos(), {x=0, y=1.4, z=0})

				   local dir = vector.direction(self_pos,other_pos)

				   if (vector.distance(self_pos, other_pos) < 1) then

					   local armors = self.target:get_armor_groups()

					   print(dump(armors))

					   if not armors.immortal then
						   self.target:punch(self.object,
							1,
							{ full_punch_interval = 1,
							  max_drop_level = 0,
							  damage_groups = { fleshy = 2 }
							},
							dir)
					   end
							     
					   self.object:remove()
					   return
				   end

				   self.lifetime = self.lifetime - dtime

				   if (self.lifetime < 0) then

					   self.object:remove()
					   return
				   end

				   self.object:setacceleration(vector.multiply(dir, 10))

				   local cur_vel = self.object:getvelocity()

				   if (vector.length(cur_vel) > 3) then

					   local new_vel = vector.multiply(vector.normalize(cur_vel), 3)

					   self.object:setvelocity(new_vel)
				   end
end})


magic_spells.register_spell(spell_name,
			    { display_name = "Magic Missile",
			      description = description,
			      prep_form = show_form,
			      prep_cost = calculate_cost,
			      on_begin_cast = begin_cast,
			      on_finish_cast = cast_missile
})
