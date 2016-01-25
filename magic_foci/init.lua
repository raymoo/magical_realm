local max_wear = 65535

local focus_form = smartfs.create("magic_foci:focus", function(state)
			
	local p_name = state.player
	local prepareds = state.param.prepareds
	local current_s_name = state.param.selected
	local displays = {}

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

			local player = minetest.get_player_by_name(state.player)

			if (player == nil) then return end

			local focus = player:get_wielded_item()

			if focus == nil then return end

			local foc_def = focus:get_definition()

			if foc_def == nil then return end

			if not foc_def.groups["magic_foci:focus"] then return end

			focus:set_metadata(current_s_name or "")

			player:set_wielded_item(focus)

			if (current_s_name == nil or current_s_name == "") then
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


local function show_focus(stack, player, pointed_thing)
	
	if (not player:is_player()) then return nil end

	local p_name = player:get_player_name()

	local prepareds = {}

	for s_name, def in pairs(magic_spells.registered_spells) do

		if (magic_spells.get_prepared_meta(p_name, s_name) ~= nil) then
			table.insert(prepareds, s_name)
		end
	end

	focus_form:show(p_name,
			{
				prepareds = prepareds,
				selected = stack:get_metadata()
	})
end


local function mk_focus_cast(wear)
	return function(stack, player, pointed_thing)

		if (not player:is_player()) then return nil end

		local p_name = player:get_player_name()
		
		local s_name = stack:get_metadata()

		if (s_name == nil) then
			minetest.chat_send_player(player:get_player_name(), "No spell set")
			return nil
		end

		local err = magic_spells.cast(player, pointed_thing, s_name)
		
		if (err ~= nil) then
			minetest.chat_send_player(player:get_player_name(), err)
		else
			stack:add_wear(wear)
		end

		return stack
	end
end


local function mk_focus_def(desc, texture, range, uses)
	return { description = desc,
		 inventory_image = texture,
		 wield_image = texture,
		 stack_max = 1,
		 range = range,
		 liquids_pointable = false,
		 on_place = show_focus,
		 on_use = mk_focus_cast(math.ceil(max_wear / uses)),
		 groups = { ["magic_foci:focus"] = 1 }
	}
end


local wood_desc = "Wooden Focus"
local wood_texture = "magic_foci_focus_wood.png"
local wood_range = 5
local wood_uses = 5

minetest.register_tool("magic_foci:focus_wood",
		       mk_focus_def(wood_desc, wood_texture, wood_range, wood_uses))

minetest.register_craft({ output = "magic_foci:focus_wood",
			  recipe = {
				  { "", "default:stick", ""},
				  { "default:stick", "default:paper", "default:stick"},
				  { "", "default:stick", ""},
			  },
})


local stone_desc = "Stone Focus"
local stone_texture = "magic_foci_focus_stone.png"
local stone_range = 10
local stone_uses = 20

minetest.register_tool("magic_foci:focus_stone",
		       mk_focus_def(stone_desc, stone_texture, stone_range, stone_uses))

minetest.register_craft({ output = "magic_foci:focus_stone",
			  recipe = {
				  { "", "default:stone", ""},
				  { "default:stone", "default:desert_stone", "default:stone"},
				  { "", "default:stone", ""},
			  },
})


local gold_desc = "Gold Focus"
local gold_texture = "magic_foci_focus_gold.png"
local gold_range = 15
local gold_uses = 80

minetest.register_tool("magic_foci:focus_gold",
		       mk_focus_def(gold_desc, gold_texture, gold_range, gold_uses))

minetest.register_craft(
	{ output = "magic_foci:focus_gold",
	  recipe = {
		  { "", "default:steel_ingot", ""},
		  { "default:steel_ingot", "default:gold_ingot", "default:steel_ingot"},
		  { "", "default:steel_ingot", ""},
	  },
})


local dmd_desc = "Diamond Focus"
local dmd_texture = "magic_foci_focus_diamond.png"
local dmd_range = 20
local dmd_uses = 320

minetest.register_tool("magic_foci:focus_diamond",
		       mk_focus_def(dmd_desc, dmd_texture, dmd_range, dmd_uses))

minetest.register_craft(
	{ output = "magic_foci:focus_diamond",
	  recipe = {
		  { "", "default:gold_ingot", ""},
		  { "default:gold_ingot", "default:diamond", "default:gold_ingot"},
		  { "", "default:gold_ingot", ""},
	  },
})
