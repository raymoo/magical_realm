magic_spells = {}


-- List of spell data
local spells = {}


-- Table of caster HUDs
local huds = {}


local prep_cooldown = tonumber(minetest.setting_get("magic_prep_cooldown")) or 3600

local backup_interval = tonumber(minetest.setting_get("magic_backup_interval")) or 600

local init_max_prep = tonumber(minetest.setting_get("magic_starting_points")) or 5


magic_spells.error = 0
magic_spells.incomplete = 1
magic_spells.complete = 2


local function get_caster_data(player_name)
	return player_systems.get_state("casters", player_name)
end


local function set_caster_data(player_name, caster_data)
	player_systems.set_state("casters", player_name, caster_data)
end


local function update_HUD(player_name)

	local caster_data = get_caster_data(player_name)

	if (caster_data == nil) then
		minetest.log("error", player_name .. " has no caster data")
		return
	end

	
	local hud = huds[player_name]

	if (hud == nil) then
		minetest.log("error", player_name .. " has no caster HUD")
	end


	local cur_spell = caster_data.current_spell

	local player = minetest.get_player_by_name(player_name)
		
	if (player == nil) then
		minetest.log("error", player_name .. " doesn't exist")
		return
	end

	if (cur_spell == nil) then

		player:hud_change(hud, "text", "")
	else

		local rem_time = cur_spell.remaining_time

		local s_name = cur_spell.def.display_name

		local disp_str = string.format("Casting %s: %.0f seconds left", s_name, rem_time)

		player:hud_change(hud, "text", disp_str)
	end
end

		


local function gen_HUD(player_name)

	local player = minetest.get_player_by_name(player_name)

	if (player == nil) then
		minetest.log("error", "No player of that name!")
		return
	end

	local hud = player:hud_add({
			hud_elem_type = "text",
			position = {x = 0.1, y = 0.5},
			direction = 0,
			alignment = -1,
			scale = {x = -100, y = 24},
			text = "",
			number = 0x0000FF
	})

	huds[player_name] = hud

	update_HUD(player_name)
end
			

local log_finish_temp = "[magic_spells] %s finishes casting %s at %s"


local elapsed_hud = 1


local function caster_step(dtime)

	if (elapsed_hud < 1) then
		elapsed_hud = elapsed_hud + dtime
		return
	end

	elapsed_hud = 0

	local active_casters = player_systems.active_states("casters")

	for name, data in pairs(active_casters) do

		local cur_spell = data.current_spell

		if(cur_spell ~= nil) then

			local rem_time = cur_spell.remaining_time

			local new_rem = rem_time - 1

			
			if (new_rem > 0) then

				cur_spell.remaining_time = new_rem
			else

 				local s_name = cur_spell.spell_name

				local spell = spells[s_name]

				local player = minetest.get_player_by_name(name)

				local pos_string = minetest.pos_to_string(player:getpos())

				local mes = string.format(log_finish_temp, name, s_name, pos_string)

				minetest.log("action", mes)
				
				if (spell == nil) then
					minetest.log("error", "Casting unknown spell: " .. s_name)
				else
					spell.on_finish_cast(cur_spell.result_data)
				end
				
				data.current_spell = nil
			end

			update_HUD(name)

		end

	end

end


minetest.register_globalstep(caster_step)


local function initialize_caster()

	local caster_data = {}

	-- A set of spell names known to the user
	caster_data.known_spells = {}

	-- A map from spell names to metadata - a spell is prepared if it has a value
	-- in here
	caster_data.prepared_spells = {}

	-- A map from spell school names to nonnegative aptitude numbers
	caster_data.aptitudes = {}

	-- The last time the caster prepared
	caster_data.last_prep_time = os.time()

	-- The spell currently being casted. Table with elements:
	--   spell_name: The name of the spell
	--   remaining_time: How much more time left in casting time
	--   def: The spell definition
	--   result_data: The data passed to the callback in on_begin_cast
	caster_data.current_spell = nil
	caster_data.max_prep = init_max_prep
	caster_data.prep_points = init_max_prep

	-- The most recent settings for each spell. Used to show the caster the
	-- last thing they chose during preparation.
	caster_data.last_preps = {}

	caster_data.can_cast = true

	return caster_data
end


local function backup()

	player_systems.persist("casters")
	minetest.after(backup_interval, backup)
end


if (backup_interval > 0) then
	minetest.after(backup_interval, backup)
end


local function get_prepared_meta(player_name, spell_name)
	local caster_data = get_caster_data(player_name)

	if (caster_data == nil) then
		minetest.log("error", player_name .. " is missing caster data")
		return
	end

	return caster_data.prepared_spells[spell_name]
end


local function set_prepared_meta(player_name, spell_name, prep_meta)
	local caster_data = get_caster_data(player_name)

	if (caster_data == nil) then
		minetest.log("error", player_name .. " is missing caster data")
		return
	end

	caster_data.prepared_spells[spell_name] = prep_meta

	set_caster_data(player_name, caster_data)
end


local function def_begin_cast(metadata, player, pointed_thing, callback)

	callback(0,
		 { player_name = player,
		   pointed_thing = pointed_thing
	})
end



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


local function grant_spell(p_name, s_name)

	local c_data = get_caster_data(p_name)

	c_data.known_spells[s_name] = true

	set_caster_data(p_name, c_data)
end


local function revoke_spell(p_name, s_name)

	local c_data = get_caster_data(p_name)

	c_data.known_spells[s_name] = nil

	set_caster_data(p_name, c_data)
end


-- Handles the addition of a prepared spell, after the player already submitted
-- it.
local function prepare_spell(p_name, s_name, metadata, cost)

	local c_data = get_caster_data(p_name)

	if (c_data == nil) then
		minetest.log("error", "No caster named " .. p_name)
		return
	end

	local spell = spells[s_name]

	if (spell == nil) then
		minetest.log("error", "No spell called " .. s_name)
		return
	end

	c_data.prepared_spells[s_name] = metadata

	c_data.prep_points = c_data.prep_points - cost

	c_data.last_preps[s_name] = copy_shal(metadata)

	set_caster_data(p_name, c_data)
end


local function unprepare_spell(p_name, s_name)
	set_prepared_meta(p_name, s_name, nil)
end


-- Unprepares all spells and restores preparation slots. Sets the last preparation
-- time to now
local function reset_preparation(p_name)

	local c_data = get_caster_data(p_name)

	if (c_data == nil) then
		minetest.log("error", "No caster " .. p_name)
		return
	end

	c_data.prepared_spells = {}

	c_data.prep_points = c_data.max_prep

	c_data.last_prep_time = os.time()

	set_caster_data(p_name, c_data)
end


-- Cancels a caster's currently-casting spell
local function cancel_spell(p_name)

	local c_data = get_caster_data(p_name)

	if (c_data == nil) then
		minetest.log("error", "No caster " .. p_name)
		return
	end

	c_data.current_spell = nil

	set_caster_data(p_name, c_data)
end


local log_begin_temp = "[magic_spells] %s begins casting %s at %s"


-- Forces a player to cast a spell, inputting arbitrary metadata. Returns the
-- updated metadata.
local function force_cast_spell(player, pointed_thing, s_name, meta)

	local p_name = player:get_player_name()

	local c_data = get_caster_data(p_name)

	local spell = spells[s_name]

	local pos_string = minetest.pos_to_string(player:getpos())

	minetest.log("action", string.format(log_begin_temp, p_name, s_name, pos_string))

	if (c_data == nil) then
		minetest.log("error", p_name .. " doesn't exist, so can't cast.")
		return
	end

	if (spell == nil) then
		minetest.log("error", "No spell " .. s_name)
		return
	end

	local function callback(startup, result_data)

		local pos_later = minetest.pos_to_string(player:getpos())

		if (startup == 0) then
			local mes = string.format(log_finish_temp, p_name, s_name, pos_later)
			minetest.log("action", mes)
			spell.on_finish_cast(result_data)
		else
			local cb_caster = get_caster_data(p_name)

			local cur_spell =
				{ spell_name = s_name,
				  remaining_time = startup,
				  def = spell,
				  result_data = result_data
				}

			cb_caster.current_spell = cur_spell

			set_caster_data(p_name, cb_caster)
		end
		

	end

	-- Spellcasting new meta
	local res = spell.on_begin_cast(meta, player, pointed_thing, callback)

	update_HUD(p_name)

	return res
end


-- Nicer spell-casting that uses existing metadata. Returns nil on success, otherwise
-- returns an error string.
local function cast_spell(player, pointed_thing, s_name)

	local p_name = player:get_player_name()

	local c_data = get_caster_data(p_name)

	local prep_meta = get_prepared_meta(p_name, s_name)

	if (prep_meta == nil) then
		return "This spell has not been prepared."
	end

	if (c_data == nil) then
		return "Player does not exist."
	end

	if (c_data.current_spell ~= nil) then
		return "You are already casting something."
	end

	if (not c_data.can_cast) then
		return "You cannot cast right now."
	end

	local new_meta = force_cast_spell(player, pointed_thing, s_name, prep_meta)

	set_prepared_meta(p_name, s_name, new_meta)

	return nil
end
	


-- Handling of preparation GUI
--
-- These are the different form names:
--
-- magic_spells:select_prep - Selecting a spell to prepare. It contains
-- a "selected" textlist, that only contains spells the user has not prepared
-- yet. Uses smartfs, and takes a a list of spell names as a param.
--
-- It also has a button, to go to the preparation screen.
-- When a spell is selected, its description should appear.
--
-- magic_spells:err_prep - Error message window. Goes back to spell preparation on
-- submit. Its param is a table containing err, spell_name, and prep_cb.
--
-- magic_spells:conf_prep - Used after confirmation of spell preparation. Receives
-- a table param with the following fields:
--   spell_name - the spell used
--   metadata - the metadata entered
--   cost - the preparation slots used
--   prep_cb - How to return to the preparation dialog.


local select_form, err_form, conf_form


-- smartfs forms seem to break if you show a form from a different form's callbacks.
local function delay_show(form, p_name, param)

	minetest.after(0, function()
			       form:show(p_name, param)
	end)
end


local function show_select_prep(p_name)
	
	local c_data = get_caster_data(p_name)

	if (c_data == nil) then return end

	local preparable = {}

	for s_name, _ in pairs(c_data.known_spells) do

		if (not c_data.prepared_spells[s_name]) then
			table.insert(preparable, s_name)
		end
	end

	delay_show(select_form, p_name, preparable)
end


local function handle_prep_err(p_name, s_name, err, prep_cb)

	delay_show(err_form, p_name,
		   { err = err,
		     spell_name = s_name,
		     prep_cb = prep_cb
	})
end


local function show_conf(p_name, s_name, meta, cost, prep_cb)

	delay_show(conf_form, p_name,
		   { spell_name = s_name,
		     metadata = meta,
		     cost = cost,
		     prep_cb = prep_cb
	})
	
end


local function handle_prep_succ(p_name, s_name, meta, prep_cb)

	local c_data = get_caster_data(p_name)
	
	local spell = spells[s_name]

	if (spell == nil or c_data == nil) then return end

	local cost = math.ceil(spell.prep_cost(c_data.aptitudes, meta))

	if (cost > c_data.prep_points) then
		local err = "Not enough slots.\n"
			.. "Need: " .. cost
			.. " Have: " .. c_data.prep_points

		handle_prep_err(p_name, s_name, err, prep_cb)
	else
		show_conf(p_name, s_name, meta, cost, prep_cb)
	end

end


local function show_prep(p_name, s_name, prep_cb)

	local c_data = get_caster_data(p_name)

	if (c_data == nil) then return end

	local last_meta = c_data.last_preps[s_name]

	local function succ_cb(meta)
		handle_prep_succ(p_name, s_name, meta, prep_cb)
	end

	local function err_cb(err)
		handle_prep_err(p_name, s_name, err, prep_cb)
	end

	if (prep_cb == nil) then
		handle_prep_succ(p_name, s_name, {}, prep_cb)
	else
		minetest.after(0, prep_cb, last_meta, p_name, succ_cb, err_cb)
	end
end


local function handle_prep_conf(p_name, s_name, meta, cost)

	local c_data = get_caster_data(p_name)

	if (c_data == nil) then return end

	if (not c_data.known_spells[s_name]) then
		minetest.chat_send_player(p_name, "You don't know this spell.")
		return
	end

	if (c_data.prep_points < cost) then
		minetest.chat_send_player(p_name, "Not enough slots.")
		return
	end

	prepare_spell(p_name, s_name, meta, cost)

	show_select_prep(p_name)

end


select_form = smartfs.create("magic_spells:select_prep", function(state)

		       local spell_list = state.param

		       state.selected_idx = nil

		       state:size(8,8)
		       state:label(0.5,0,"title","Select a spell to prepare")
		       local spells_box = state:listbox(0.5,0.5,3,6,"selected")

		       spells_box:removeItem(1)

		       for i, s_name in ipairs(spell_list) do

			       local s_data = spells[s_name]

			       local disp

			       if (s_data == nil) then
				       disp = s_name
			       else
				       disp = s_data.display_name
			       end

			       spells_box:addItem(disp)
		       end

		       local prep_button = state:button(3.5,7,2,1,"prepare","Prepare")
		       local desc_box =
			       state:textarea(4.5, 0.5, 3.5, 6, "desc", "Description")

		       desc_box:setText("")

		       spells_box:onClick(function(self, state, idx)

				       state.selected_idx = tonumber(idx)
				       local s_name = spell_list[tonumber(state.selected_idx)]

				       local s_def = s_name and spells[s_name]

				       local s_desc = (s_def and s_def.description)
					       or "Error: Spell not found."

				       desc_box:setText(s_desc)

				       state:show()
		       end)

		       prep_button:click(function(self, state)

				       if (state.selected_idx == nil) then
					       return
				       end

				       local s_name = spell_list[state.selected_idx]

				       local s_def = s_name and spells[s_name]

				       if (s_def == nil) then
					       return
				       end

				       local p_name = state.player

				       show_prep(p_name, s_name, s_def.prep_form)
		       end)

		       
end)


err_form = smartfs.create("magic_spells:err_prep", function(state)

		       state:size(5,3)
		       state:label(0.5, 0.5, "title", "Error")
		       state:label(0.5, 1, "err", state.param.err)
		       local butt = state:button(1,2, 2,1, "back", "Back")

		       butt:click(function(self, state)

				       local p_name = state.player
				       local s_name = state.param.spell_name

				       if (state.param.prep_cb == nil) then
					       show_select_prep(p_name)
					       return
				       end

				       show_prep(p_name, s_name, state.param.prep_cb)
		       end)
end)


local slot_cost_temp =
	"This will cost %d of %d preparation slots.\n Are you sure?"


conf_form = smartfs.create("magic_spells:conf_prep", function(state)

				   local p_name = state.player
				   local s_name = state.param.spell_name
				   local meta = state.param.metadata
				   local cost = state.param.cost
				   local prep_cb = state.param.prep_cb

				   local c_data = get_caster_data(p_name)

				   if (c_data == nil) then return end

				   local av_points = c_data.prep_points

				   local cost_text =
					   string.format(slot_cost_temp, cost, av_points)

				   state:size(5,3)
				   state:label(0.2,0, "cost", cost_text)
				   
				   local yes = state:button(0.5,2, 1.5,1, "yes", "Yes")
				   
				   local no = state:button(3.5,2, 1.5,1, "no", "No")

				   yes:click(function(self, state)
						   handle_prep_conf(p_name, s_name, meta, cost)
				   end)

				   no:click(function(self, state)

						   if (prep_cb == nil) then
							   show_select_prep(p_name)
							   return
						   end

						   show_prep(p_name, s_name, prep_cb)
				   end)
end)


player_systems.register_player_system("casters",
				      { initialize_player = initialize_caster
					, serialize_player = function(meta)
						meta.current_spell = nil
						return minetest.serialize(meta)
					end
					, deserialize_player = minetest.deserialize
					, on_player_join = function (p_name)
						cancel_spell(p_name)
						gen_HUD(p_name)
					end
					, on_player_leave = function(p)
						huds[p] = nil
					end
})


minetest.register_on_dieplayer(function(p)

		local p_name = p:get_player_name()

		cancel_spell(p_name)
end)


magic_spells.register_spell = function(name, spell)
	
	if (spells[name] ~= nil) then
		minetest.log("error", "Spell name collision: " .. name)
	end

	local spell_def = copy_shal(spell)

	spell_def.on_begin_cast = spell_def.on_begin_cast or def_begin_cast

	spells[name] = spell_def
end


magic_spells.give_spell = function(p_name, s_name)

	if (spells[s_name] == nil) then return "Spell " .. s_name .. " does not exist" end

	local c_data = get_caster_data(p_name)

	if (c_data == nil) then return "Not a valid caster" end

	c_data.known_spells[s_name] = true

	set_caster_data(p_name, c_data)
end


magic_spells.take_spell = function(p_name, s_name)

	local c_data = get_caster_data(p_name)

	if (c_data == nil) then return "Not a valid caster" end

	c_data.known_spells[s_name] = false

	set_caster_data(p_name, c_data)
end


magic_spells.get_prepared_meta = get_prepared_meta


magic_spells.set_prepared_meta = set_prepared_meta


magic_spells.prepare_spells = show_select_prep


magic_spells.reset_preparation = function (p_name, force)

	local c_data = get_caster_data(p_name)

	if (c_data == nil) then
		return "No such caster"
	end

	local last_time = c_data.last_prep_time

	local elapsed = os.time() - last_time

	if ((not force) and elapsed < prep_cooldown) then
		return "You must wait " .. prep_cooldown - elapsed .. " more seconds."
	end

	reset_preparation(p_name)

end


magic_spells.cast = cast_spell


magic_spells.force_cast = force_cast_spell


magic_spells.cancel_cast = function(p_name)

	local c_data = get_caster_data(p_name)

	if (c_data == nil) then
		return "No such caster"
	end

	cancel_spell(p_name)
end


magic_spells.get_current_spell = function(p_name)

	local c_data = get_caster_data(p_name)

	return c_data and c_data.current_spell.spell_name
end


magic_spells.registered_spells = spells


magic_spells.set_can_cast = function (p_name, can_cast)

	local c_data = get_caster_data(p_name)

	if (c_data == nil) then return end

	c_data.can_cast = can_cast

	set_caster_data(p_name, c_data)
end


-- Privileges / Commands


-- Whether you can give spells out like candy.
minetest.register_privilege("givespell",
			    { description = "Grant spells using /givespell",
			      give_to_singleplayer = false
})


local function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end


local function givespell_func(name, param)

	local args = {}

	local name_s, name_e = param:find("%w+")


	if (name_s == nil) then return false, "No player specified" end

	local p_name = param:sub(name_s, name_e)

	local s_name = trim(param:sub(name_e + 1, -1))
	
	if (s_name == "") then return false, "No spell specified" end

	
	local err = magic_spells.give_spell(p_name, s_name)

	if (err ~= nil) then return false, err end

	return true
	

end


minetest.register_chatcommand("givespell",
			      { params = "<player> <spell>",
				description = "Give a player a spell",
				privs = { givespell = true },
				func = givespell_func
})
				

local modpath = minetest.get_modpath(minetest.get_current_modname()) .. "/"


dofile(modpath .. "creative_stick.lua")
dofile(modpath .. "creative_spellbook.lua")
