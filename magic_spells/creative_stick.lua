
local wand_range = tonumber(minetest.setting_get("magic_creative_wand_range")) or 30


local texture = "default_mese_crystal_fragment.png^default_stick.png"

local selected_spells = {}

local stick_form = smartfs.create("magic_spells:creative_stick", function(state)

	local p_name = state.player
	local prepareds = state.param
	local displays = {}

	local current_s_name = selected_spells[p_name]

	local current_displayed

	if (current_s_name == nil) then
		current_displayed = "None"
	else
		local spell = magic_spells.registered_spells[current_s_name]

		if (spell == nil) then
			current_displayed = "Invalid Spell"
		else
			current_displayed = spell.display_name
		end
	end
		

	state:size(8,8)
	local cur_lab = state:label(0.5,0.5, "title", "Current Spell: " .. current_displayed)
	local select_box = state:listbox(0.5,1, 7,5.5, "prepareds")

	state:button(0.5,7, 2,1, "done", "Done", true)

	select_box:removeItem(1)
	
	for i, s_name in ipairs(prepareds) do

		local spell = magic_spells.registered_spells[s_name]

		if (spell == nil) then
			select_box:addItem("Invalid Spell")
		else
			select_box:addItem(spell.display_name)
		end
	end

	select_box:onClick(function(self, state, idx)

			current_s_name = prepareds[tonumber(idx)]

			local spell = magic_spells.registered_spells[current_s_name]

			selected_spells[p_name] = current_s_name

			if (current_s_name == nil) then
				current_displayed = "Nothing"
			elseif (spell == nil) then
				current_displayed = "Invalid Spell"
			else
				current_displayed = spell.display_name
			end

			cur_lab:setText("Current Spell: " .. current_displayed)
			
			state:show()

	end)
end)
		


local function show_stick(stack, player, pointed_thing)

	if (not player:is_player()) then return nil end

	local p_name = player:get_player_name()

	local prepareds = {}

	for s_name, def in pairs(magic_spells.registered_spells) do

		table.insert(prepareds, s_name)
	end

	stick_form:show(p_name, prepareds)
	
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
