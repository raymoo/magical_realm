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

		local disp_str = string.format("Casting %s: %.1f seconds left", s_name, rem_time)

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
			

local function caster_step(dtime)

	local active_casters = player_systems.active_states("casters")

	for name, data in pairs(active_casters) do

		local cur_spell = data.current_spell

		if(cur_spell ~= nil) then

			local rem_time = cur_spell.remaining_time

			local new_rem = rem_time - dtime

			
			if (new_rem > 0) then

				cur_spell.remaining_time = new_rem
			else
				local s_name = cur_spell.spell_name

				local spell = spells[s_name]

				if (spell == nil) then
					minetest.log("error", "Casting unknown spell: " .. s_name)
				else
					spell.on_finish_cast(cur_spell.result_data)
				end
				
				data.current_spell = nil
			end
		end

		update_HUD(name)

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


local def_fields_temp =
	"size[4, 5]"
	.. "field[1,1;3,1;startup;Startup Time;%d]"
.. "field[1,3;3,1;uses;Uses (0 for infinite);%d]"
	.. "button[1,4;2,1;prepare;Prepare]"


local function def_fields(last_meta)

	local last_startup = (last_meta and last_meta.startup) or 0
	local last_uses = (last_meta and last_meta.uses) or 0

	print(last_meta.uses)
	
	return string.format(def_fields_temp, last_startup, last_uses)
end


local function def_parse(fields)

	local startup = tonumber(fields.startup)

	if (startup == nil) then
		return magic_spells.error, "Non-number startup"
	end

	if (startup < 0) then
		return magic_spells.error, "Negative startup time"
	end

	local uses = tonumber(fields.uses)

	if (uses == nil) then
		return magic_spells.error, "Non-number uses"
	end

	if (uses < 0) then
		return magic_spells.error, "Negative uses"
	end

	if (uses == 0) then
		uses = nil
	end

	return magic_spells.complete, { startup = startup, uses = uses }

end


local function def_begin_cast(metadata, player, pointed_thing, callback)

	local p_name = player:get_player_name()

	if (metadata.uses == 0) then
		-- This shouldn't happen, but just in case
		minetest.chat_send_player(p_name, "You have no more uses.")
		return nil
	end
	
	if (metadata.uses ~= nil) then
		metadata.uses = metadata.uses - 1
		local use_string = "You now have " .. metadata.uses .. " uses."
	minetest.chat_send_player(p_name, use_string)
	end

	
	callback(metadata.startup,
		 { player_name = p_name, pointed_thing = pointed_thing
		 }, player, pointed_thing)

	if (metadata.uses == 0) then
		return nil
	else
		return metadata
	end
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


-- Forces a player to cast a spell, inputting arbitrary metadata. Returns the
-- updated metadata.
local function force_cast_spell(player, pointed_thing, s_name, meta)

	local p_name = player:get_player_name()

	local c_data = get_caster_data(p_name)

	local spell = spells[s_name]

	if (c_data == nil) then
		minetest.log("error", p_name .. " doesn't exist, so can't cast.")
		return
	end

	if (spell == nil) then
		minetest.log("error", "No spell " .. s_name)
		return
	end

	local function callback(startup, result_data)

		if (startup == 0) then
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
	return spell.on_begin_cast(meta, player, pointed_thing, callback)
end


-- Nicer spell-casting that uses existing metadata. Returns nil on success, otherwise
-- returns an error string.
local function cast_spell(player, pointed_thing, s_name)

	local p_name = player:get_player_name()

	local c_data = get_caster_data(p_name)

	local prep_meta = get_prepared_meta(p_name, s_name)

	if (prep_meta == nil) then
		return "The spell has not been prepared."
	end

	if (c_data == nil) then
		return "Player does not exist."
	end

	if (c_data.current_spell ~= nil) then
		return "Player is already casting something"
	end

	local new_meta = force_cast_spell(player, pointed_thing, s_name, prep_meta)

	set_prepared_meta(p_name, s_name, new_meta)

	return nil
end
	


-- Handling of preparation GUI
--
-- These are the different form names:
--
-- magic:select_prep - Selecting a spell to prepare. It contains
-- a "selected" textlist, that only contains spells the user has not prepared
-- yet. Needs to have a formspec data table associated, with these fields:
--   preparable_idx - the index of the currently-preparable spells (known and
--     not yet prepared)
--   preparable - a list of preparable spells
-- It also has a button, "prepare", to go to the preparation screen.
-- When a spell is selected, its description should appear.
--
-- magic:prep - Submission from the preparation screen. Should just be the
-- formspec provided in the spell definition. Before shown, the spell selected
-- should be saved as formspec data, in a string.
--
-- magic:err_prep - Error message window. Goes back to spell preparation on
-- submit, so should save spell name in formspec data.
--
-- magic:conf_prep - Used after confirmation of spell preparation. Before showing,
-- should save a table with the following fields:
--   spell_name - the spell used
--   metadata - the metadata entered
--   cost - the preparation slots used


local formspec_data = {}


local function get_formspec_data(p_name, formname)

	if (formspec_data[p_name] == nil or formspec_data[p_name][formname] == nil) then
		return nil
	end

	return copy_shal(formspec_data[p_name][formname])
end


local function set_formspec_data(p_name, formname, data)
	if (formspec_data[p_name] == nil) then
		if (minetest.get_player_by_name(p_name) ~= nil) then
			formspec_data[p_name] = {}
		else
			return
		end
	end

	formspec_data[p_name][formname] = copy_shal(data)
end


minetest.register_on_leaveplayer(function(player)
		formspec_data[player:get_player_name()] = nil
end)


local selection_temp =
	"size[8,8]label[0.5,0;Select a spell to prepare]"
	.. "textlist[0.5,0.5;3,6;selected;%s]"
	.. "button[3.5,7;2,1;prepare;Prepare]"
	.. "textarea[4.5,0.5;3.5,6;desc;Description;%s]"


local function show_select_prep(p_name)

	local preparable_list = {}

	local preparable_display_list = {}

	local caster_data = get_caster_data(p_name)

	local old_fs_data = get_formspec_data(p_name, "magic:select_prep")

	if (caster_data == nil) then
		minetest.log("error", "No caster data for " .. p_name)
		return
	end

	local idx = (old_fs_data and old_fs_data.preparable_idx) or 1

	for s_name, garbage in pairs(caster_data.known_spells) do

		if(caster_data.prepared_spells[s_name] == nil and spells[s_name] ~= nil) then
			table.insert(preparable_list, s_name)
			table.insert(preparable_display_list, spells[s_name].display_name)
		end
	end

	local text_list = table.concat(preparable_display_list, ",")

	local selected_s_name = preparable_list[idx]
	
	local selected_spell = spells[selected_s_name]

	local description

	if (selected_spell == nil) then
		description = ""
	else
		description = minetest.formspec_escape(selected_spell.description)
	end

	local formspec = string.format(selection_temp, text_list, description)

	set_formspec_data(p_name, "magic:select_prep",
			  { preparable = preparable_list, preparable_idx = idx })

	minetest.show_formspec(p_name, "magic:select_prep", formspec)
end
	

local function show_prep(p_name, s_name)

	local spell = spells[s_name]

	local c_data = get_caster_data(p_name)

	if (spell == nil) then
		minetest.log("error", "Unknown Spell: " .. s_name)
		return
	end

	if (c_data == nil) then
		minetest.log("error", "Unknown Caster: " .. p_name)
		return
	end

	local formspec = spell.prep_form(c_data.last_preps[s_name])

	set_formspec_data(p_name, "magic:prep", s_name)

	minetest.show_formspec(p_name, "magic:prep", formspec)
end


local insufficient_temp =
	"size[4,4]label[1,0;Error]label[1,1;Insufficient points]"
	.. "label[1,2;Have %d, need %d]button[1,3;2,1;back;Back]"


local function show_insufficient_prep(p_name, s_name, req_prep, cur_prep)

	local formspec = string.format(insufficient_temp, cur_prep, req_prep)

	set_formspec_data(p_name, "magic:err_prep", s_name)

	minetest.show_formspec(p_name, "magic:err_prep", formspec)
end


local error_temp =
	"size[4,3]label[1,0;Error]label[1,1;%s]"
	.. "button[1,2;2,1;back;Back]"


local function show_error_prep(p_name, s_name, error_str)

	local formspec = string.format(error_temp, error_str)

	set_formspec_data(p_name, "magic:err_prep", s_name)
	
	minetest.show_formspec(p_name, "magic:err_prep", formspec)
end


local conf_temp =
	"size[5,3]label[0.2,0;This will cost %d of %d preparation slots. \nAre you sure?]"
	.. "label[1,1;You can hit ESC to go back.]button[1,2;2,1;confirm;Confirm]"


local function show_conf_prep(p_name, s_name, metadata, req_prep, cur_prep)

	local formspec = string.format(conf_temp, req_prep, cur_prep)

	local data =
		{ spell_name = s_name,
		  metadata = metadata,
		  cost = req_prep
		}

	set_formspec_data(p_name, "magic:conf_prep", data)
	
	minetest.show_formspec(p_name, "magic:conf_prep", formspec)
end


local function handle_fields(player, formname, fields)

	local p_name = player:get_player_name()

	local caster_data = get_caster_data(p_name)

	if (formname == "magic:select_prep") then

		local select_data =
			get_formspec_data(p_name, "magic:select_prep")

		if (fields["prepare"]) then
			local s_name = select_data.preparable[select_data.preparable_idx]

			if (s_name == nil) then
				show_select_prep(p_name)
				return true
			end
			
			show_prep(p_name,
				  select_data.preparable[select_data.preparable_idx])
			return true
		end

		if (fields["selected"]) then
			local event = minetest.explode_textlist_event(fields.selected)

			select_data.preparable_idx = tonumber(event.index)

			set_formspec_data(p_name, "magic:select_prep", select_data)

			show_select_prep(p_name)
			return true
		end
	end

	if (formname == "magic:prep") then

		if (fields["quit"]) then
			show_select_prep(p_name)
			return true
		end

		local s_name = get_formspec_data(p_name, "magic:prep")

		local spell = spells[s_name]

		if (spell == nil) then
			minetest.log("error", "Unknown spell " .. s_name)
			return true
		end

		local res_type, result = spell.parse_fields(fields)

		if (res_type == magic_spells.error) then
			show_error_prep(p_name, s_name, result)
			return true
		end

		if (res_type == magic_spells.incomplete) then
			minetest.show_formspec(p_name, "magic:prep", result)
			return true
		end

		local cost = spell.prep_cost(caster_data.aptitudes, result)

		if (cost > caster_data.prep_points) then
			show_insufficient_prep(p_name, s_name, cost, caster_data.prep_points)
			return true
		else
			show_conf_prep(p_name, s_name, result, cost, caster_data.prep_points)
			return true
		end
	end

	if (formname == "magic:err_prep") then

		local s_name = get_formspec_data(p_name, "magic:err_prep")

		show_prep(p_name, s_name)
		return true
	end

	if (formname == "magic:conf_prep") then		

		local data = get_formspec_data(p_name, "magic:conf_prep")

		local s_name = data.spell_name

		if (fields["quit"]) then
			show_prep(p_name, s_name)
			return true
		end

		if (not caster_data.known_spells[s_name]) then
			minetest.chat_send_player(p_name, "You don't know this spell.")
			return true
		end

		if (caster_data.prep_points < data.cost) then
			minetest.chat_send_player(p_name, "Not enough slots.")
			return true
		end

		prepare_spell(p_name, s_name, data.metadata, data.cost)

		show_select_prep(p_name)

		return true

	end
end


player_systems.register_player_system("casters",
				      { initialize_player = initialize_caster
					, serialize_player = minetest.serialize
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


minetest.register_on_player_receive_fields(handle_fields)
	

magic_spells.register_spell = function(name, spell)
	
	if (spells[name] ~= nil) then
		minetest.log("error", "Spell name collision: " .. name)
	end

	local spell_def = copy_shal(spell)

	spell_def.prep_form = spell_def.prep_form or def_fields
	spell_def.parse_fields = spell_def.parse_fields or def_parse
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


-- Privileges / Commands


-- Determines whether the player can prepare using /prepare
minetest.register_privilege("prepare",
			    { description = "Player can prepare spells with /prepare",
			      give_to_singleplayer = false
})


minetest.register_chatcommand("prepare",
			      { description = "Prepare spells",
				privs = { prepare = true },
				func = function(name,param)
					magic_spells.prepare_spells(name)
					return true
				end
})


minetest.register_chatcommand("unprepare",
			      { description = "Resets preparation",
				privs = { prepare = true},
				func = function(name, param)

					local err = magic_spells.reset_preparation(name)

					if (err ~= nil) then
						return false, err
					else
						return true
					end
				end
})


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
				

minetest.register_privilege("cast",
			    { description = "Cast using /cast",
			      give_to_singleplayer = false
})


minetest.register_chatcommand("cast",
			      { params = "<spell>",
				description = "Cast a spell, pointing at nothing",
				privs = { cast = true },
				func = function(name, param)

					local player = minetest.get_player_by_name(name)

					if (player == nil) then return false, "Bad player" end

					local err = cast_spell(player, nil, trim(param))

					return (err == nil), err
end})


local modpath = minetest.get_modpath(minetest.get_current_modname()) .. "/"


dofile(modpath .. "creative_stick.lua")
