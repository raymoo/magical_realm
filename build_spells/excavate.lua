
-- Spell Info
--
-- A spell for digging. It summons a digging ball that can be controlled by look
-- direction and the use key.
--
-- Metadata: A table with one field
--
-- uses: The number of remaining uses (nil for infinite)
--
--
-- Result Data: The entity who cast the spell
--
-- Smart Formspec: Just a field for uses.
--
-- param - A table with last_meta, succ_cb, err_cb


local spell_name = "excavate"

local display_name = "Excavate"

local description =
	"Summons a magical pickaxe to dig for you.\n\n"
	.. "No unlimited use.\n"
	.. "Cost: uses * 2. Also costs a steel block when casting.\n\n"
	.. "Controls: The sprite follows your look direction. Hold E to "
	.. "make it go farther away, and hold Shift + E to make it come back.\n\n"
	.. "The sprite only works at y=-4 or below."


local form_name = "combat_spells:excavate"


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

	if (uses < 1) then
		err_cb("Must have at least one use")
		return
	end

	succ_cb({ uses = uses })
end


local form = smartfs.create(form_name, function(state)

	state:size(5,3)

	local def_uses = (state.param.last_meta and state.param.last_meta.uses) or 1

	local uses_field = state:field(1,1, 3,1, "uses", "Uses (at least 1)")
	uses_field:setText("" .. def_uses)

	local butt = state:button(1.5,1.5, 2,1, "prepare", "Prepare")

	butt:click(function(self, state)

			local uses_str = uses_field:getText()

			handle_prep(uses_str, state.param.succ_cb, state.param.err_cb)
	end)
end)


local function show_form(last_meta, p_name, succ_cb, err_cb)

	form:show(p_name,
		  { last_meta = last_meta,
		    succ_cb = succ_cb,
		    err_cb = err_cb
	})
end


local function calculate_cost(aptitudes, meta)

	return meta.uses * 2
end


local function begin_cast(meta, player, pointed_thing, callback)

	local p_name = player:get_player_name()

	if (player == nil) then return meta end

	local p_inv = player:get_inventory()

	if not p_inv:contains_item("main", "default:steelblock") then
		minetest.chat_send_player(p_name, "You need a steel block to cast.")
		return meta
	end

	if (meta.uses ~= nil) then
		meta.uses = meta.uses - 1
	end

	callback(0, player)

	p_inv:remove_item("main", "default:steelblock")

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


local function make_sprite(player)
	local obj = minetest.add_entity(player:getpos(), "build_spells:mine_sprite")
	local ent = obj:get_luaentity()

	obj:set_armor_groups({immortal = 1})
	ent.owner = player
end


local function do_dig(player, pos)
	local p_pos = player:getpos()
	local safe = vector.distance(p_pos, pos) >= 2 and pos.y <= -4

	if not safe then return end

	local maxp = vector.add(pos, 1)
	local minp = vector.subtract(pos, 1)
	
	local affected =
		minetest.find_nodes_in_area(minp, maxp, {"group:soil", "group:stone"})

	for i, n_pos in ipairs(affected) do
		minetest.node_dig(n_pos, minetest.get_node(n_pos), player)
	end
end


minetest.register_entity("build_spells:mine_sprite",
	{ visual = "sprite",
	  textures = {"default_tool_steelpick.png"},
	  
	  on_step = function(self, dtime)

		  if self.lifetime <= 0 then
			  self.object:remove()
			  return
		  end
		  
		  local owner = self.owner
		  local s_pos = self.object:getpos()

		  if owner == nil then
			  self.object:remove()
			  return
		  end

		  -- Movement
		  local o_pos = vector.add(owner:getpos(),{x=0, y=1.4, z=0})
		  local o_dir = owner:get_look_dir()

		  -- Distance
		  local go = owner:get_player_control().aux1
		  local back = owner:get_player_control().sneak

		  if go then
			  if back then
				  self.distance = self.distance - 3 * dtime
			  else
				  self.distance = self.distance + 3 * dtime
			  end
		  end

		  self.distance = math.min(math.max(self.distance, 2), 20)
		  
		  local target = vector.add(vector.multiply(o_dir, self.distance), o_pos)

		  -- Brakes
		  local curVel = self.object:getvelocity()
		  if vector.length(curVel) > 3 then
			  local newVel = vector.multiply(vector.normalize(curVel), 3)
			  self.object:setvelocity(newVel)
		  end

		  local acc = vector.multiply(vector.direction(s_pos, target), 10)

		  self.object:setacceleration(acc)

		  self.lifetime = self.lifetime - dtime

		  if self.last_dig <= 0 then
			  do_dig(owner, s_pos)
			  self.last_dig = 0.2
		  else
			  self.last_dig = self.last_dig - dtime
		  end
	  end,

	  get_staticdata = function(self)
		  if not self.owner then return "" end
		  return self.owner:get_player_name()
	  end,

	  lifetime = 60,
	  distance = 2,
	  last_dig = 0,
})
		  

magic_spells.register_spell(spell_name,
			    { display_name = display_name,
			      description = description,
			      prep_form = show_form,
			      prep_cost = calculate_cost,
			      on_begin_cast = begin_cast,
			      on_finish_cast = make_sprite
})
