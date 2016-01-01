
-- Spell Info
--
-- Metadata: A table with three numerical fields:
--  count: The number of missiles
--  startup: The casting startup
--  uses: The number of uses (nil for infinite)
--
-- Result Data: A table containing a reference to a target object, "target",
--   as well as the count field from the metadata, and the player, as player.
--
-- Formspec:
--   count: A textlist allowing the choice of 1, 2, 3, 4, or 5 missiles
--   startup: A field for entering startup time
--   uses: A field for entering use count (0 for infinite)
--   prepare: A button to finish preparation.
--
-- form_data: Just holds the selected count index.



local spell_name = "magic_missile"

local description =
	"A homing bolt of force flies toward your target.\n\n"
	.. "Each missile does one heart of damage.\n\n"
.. "Cost: \nmissile_count^2 * 2 / (startup + 1) if unlimited uses\n"
	.. "uses * missile_count * 2 / (startup + 1) otherwise\n\n"
	.. "Costs are rounded up."


-- Hold selected missile count
local form_data = {}


local form_temp =
	"size[8,6]"
	.. "textlist[0.5,0.5;3,7;count;1 missile, 2 missiles, 3 missiles, 4 missiles, 5 missiles;%d;False]"
	.. "field[4.5,0.5;3,2;startup;Startup;%d]"
.. "field[4.5,2.5;3,2;uses;Uses (0 for infinite);%d]"
	.. "button[4.5,5;2,1;prepare;Prepare]"


local function mk_form(last_meta, p_name)

	local def_count, def_startup, def_uses
	
	if (last_meta == nil) then
		def_count = 1
		def_startup = 0.5
		def_uses = 0
	else
		def_count = last_meta.count or 1
		def_startup = last_meta.startup or 0.5
		def_uses = last_meta.uses or 0
	end

	form_data[p_name] = def_count

	return string.format(form_temp, def_count, def_startup, def_uses)

end


local function parse(fields, p_name)

	if (fields["count"]) then

		local event = minetest.explode_textlist_event(fields.count)

		local count = tonumber(event.index)

		if (count == nil or count < 1 or count > 5) then
			count = 1
		end

		form_data[p_name] = count

		return magic_spells.incomplete

	end

	if (fields["prepare"]) then

		local count = form_data[p_name]

		local startup = tonumber(fields.startup)

		local uses = tonumber(fields.uses)


		if (startup == nil) then
			return magic_spells.error, "Startup not a number"
		end

		if (uses == nil) then
			return magic_spells.error, "Uses not a number"
		end

		if (startup < 0) then
			return magic_spells.error, "Startup is negative"
		end

		if (uses < 0) then
			return magic_spells.error, "Uses is negative"
		end

		if (uses ~= math.floor(uses)) then
			return magic_spells.error, "Uses is not an integer"
		end

		if (count == nil) then
			return magic_spells.error, "No missile count selected"
		end

		
		-- Infinite requested
		if (uses == 0) then
			uses = nil
		end

		return magic_spells.complete, { count = count,
						startup = startup,
						uses = uses
					      }
	end

	return magic_spells.incomplete, nil
	
end


local function calculate_cost(aptitudes, meta)

	if (meta.uses == nil) then
		return math.ceil(2 * math.pow(meta.count, 2) / (meta.startup + 1))
	else
		return math.ceil(meta.uses * 2 * meta.count / (meta.startup + 1))
	end

end


local function begin_cast(meta, player, pointed_thing, callback)

	local target = pointed_thing.ref

	if (target == nil or not target:is_player()) then
		return meta
	end


	if (meta.uses ~= nil) then
		meta.uses = meta.uses - 1
	end

	callback(meta.startup,
		 { target = target,
		   count = meta.count,
		   player = player
	})

	if (meta.uses ~= nil) then
		minetest.chat_send_player(player:get_player_name(), "You now have " .. meta.uses " uses.")
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
			minetest.add_entity(mis_pos, "evocation_spells:magic_missile")

		if (missile ~= nil) then

			local ent = missile:get_luaentity()

			local x = math.random(-3, 3)
			local y = math.random(0, 3)
			local z = math.random(-3, 3)

			ent.target = target

			missile:setvelocity({x=x, y=y, z=z})
		end

	end

end


-- Target needs to be set when spawned.
minetest.register_entity("evocation_spells:magic_missile",
			 { target = nil,
			   lifetime = 10,
			   hp_max = 1,
			   physical = true,
			   collide_with_objects = false,
			   collisionbox = { -0.1, -0.1, -0.1, 0.1, 0.1, 0.1 },
			   visual = "sprite",
			   visual_size = { x = 0.5, y = 0.5 },
			   textures = {"evocation_spells_magic_missile.png"},
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



					   self.target:punch(self.object,
							     1,
							     { full_punch_interval = 1,
							       max_drop_level = 0,
							       damage_groups = { fleshy = 2 }
							     },
							     dir)
							     
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
			      prep_form = mk_form,
			      parse_fields = parse,
			      prep_cost = calculate_cost,
			      on_begin_cast = begin_cast,
			      on_finish_cast = cast_missile
})
