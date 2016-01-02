
-- Spell Info
--
-- A spell for reflecting weak magical projectiles. When cast, it will reflect
-- weak magical projectiles back to their users, if possible.
--
-- To make your projectile (entity) reflectable, its property table should have
-- the following values:
--
-- magical_power - A number, representing how strong the projectile is. This spell
-- can reflect projectiles of level 2 or lower.
--
-- magical_owner - An ObjectRef to the owner of the projectile
--
-- magical_reflect(self, new_owner) - A function that takes itself (luaentity) as an
-- argument, and does the necessary things to start heading back to the
-- original owner. new_owner is the spellcaster that reflected the projectile.
-- It may or may not be another player.
--
--
-- Metadata: A table with two numerical fields:
--
-- uses: The number of remaining uses (nil for infinite)
--
--
-- Result Data: The entity who cast the spell
--
-- Smart Formspec: Just a field for uses.
--
-- param - A table with last_meta, succ_cb, err_cb

local reflect_radius = 5

local max_power = 2


local spell_name = "reflect_lesser"

local display_name = "Lesser Reflect"

local description =
	"Sets weak projectiles back on their caster.\n\n"
	.. "No unlimited use.\n"
	.. "Cost: uses * 4"


local form_name = "combat_spells:reflect_lesser"


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


local rl_form = smartfs.create(form_name, function(state)

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

	rl_form:show(p_name,
		     { last_meta = last_meta,
		       succ_cb = succ_cb,
		       err_cb = err_cb
	})
end


local function calculate_cost(aptitudes, meta)

	return meta.uses * 4
end


local function begin_cast(meta, player, pointed_thing, callback)

	local p_name = player:get_player_name()
	
	if (meta.uses ~= nil) then
		meta.uses = meta.uses - 1
	end

	if (player == nil) then return end

	callback(0, player)

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


local function reflect_spells(player)

	local p_pos = player:getpos()

	if (p_pos == nil) then return end

	local chest_pos = vector.add(p_pos, {x=0, y=1.4, z=0})

	local targets = minetest.get_objects_inside_radius(chest_pos, reflect_radius)

	for i, target in ipairs(targets) do

		local ent = target:get_luaentity()

		if (ent ~= nil) then

			local power = ent.magical_power
			local owner = ent.magical_owner
			local reflect = ent.magical_reflect

			if (power ~= nil
				    and owner ~= nil
				    and reflect ~= nil
				    and power <= max_power
				    and owner ~= player
			) then					
				reflect(ent, player)
			end
		end
	end
end


magic_spells.register_spell(spell_name,
			    { display_name = display_name,
			      description = description,
			      prep_form = show_form,
			      prep_cost = calculate_cost,
			      on_begin_cast = begin_cast,
			      on_finish_cast = reflect_spells
})
