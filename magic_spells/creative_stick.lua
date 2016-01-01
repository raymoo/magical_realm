
local wand_range = tonumber(minetest.setting_get("magic_creative_wand_range")) or 30


local texture = "default_mese_crystal_fragment.png^default_stick.png"

local selected_sticks = {}

local selected_spells = {}

local f_name = "magic:creative_stick"

local form = "field[select;Spell: ;]"


local function handle_fields(player, formname, fields)

	if (formname ~= f_name) then return false end
	
	local p_name = player:get_player_name()
	
	local stick = selected_sticks[p_name]


	if (stick == nil) then
		minetest.chat_send_player(p_name, "Error, no associated stick")
		return true
	end


	if (fields.select == nil) then return true end


	selected_spells[p_name] = fields.select

	minetest.chat_send_player(p_name, "Selected " .. fields.select)

	return true

end


minetest.register_on_player_receive_fields(handle_fields)


local function show_stick(stack, player, pointed_thing)

	if (not player:is_player()) then return nil end

	local p_name = player:get_player_name()

	selected_sticks[p_name] = stack

	minetest.show_formspec(p_name, f_name, form)
	
	return nil
end


local function stick_cast(stack, player, pointed_thing)

	if (not player:is_player()) then return nil end

	local p_name = player:get_player_name()
	
	local s_name = selected_spells[p_name]

	if (s_name == nil) then
		minetest.chat_send_player(player:get_player_name(), "No spell set")
		return nil
	end

	
	local err = magic_spells.cast(player, pointed_thing, s_name)

	if (err ~= nil) then
		minetest.chat_send_player(player:get_player_name(), err)
	end

	return nil
end


minetest.register_craftitem("magic_spells:creative_stick",
			    { description = "Stick of Ultimate Power",
			      inventory_image = texture,
			      wield_image = texture,
			      stack_max = 1,
			      range = wand_range,
			      liquids_pointable = true,
			      on_place = show_stick,
			      on_use = stick_cast
})
