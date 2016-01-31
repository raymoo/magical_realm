
local texture = "default_book.png^[colorize:#A13232:127"

-- param - name of the spell

local learn_form = smartfs.create("spellbooks:spellbook", function(state)
	local p_name = state.player
	local s_name = state.param

	local knowns = magic_spells.known_spells(p_name)
	if knowns == nil then return end

	local s_def = magic_spells.registered_spells[s_name]
	if s_def == nil then return end

	local s_disp = s_def.display_name
	local s_desc = s_def.description
	
	state:size(8,8)

	state:label(0.25, 0.25, "spell_name", s_disp)

	local desc = state:textarea(0.25, 1.5, 7, 4.5, "desc", "Description:")
	desc:setText(s_desc)

	print(dump(knowns))

	if knowns[s_name] then
		state:label(0.25, 6.5, "already_known", "(You already know this spell)")
	else
		local butt = state:button(0.25, 6.5, 2, 1, "learn", "Learn")

		butt:click(function(self, state)
			local player = minetest.get_player_by_name(p_name)
			if player == nil then return end

			local held = player:get_wielded_item()

			if held:get_name() ~= "spellbooks:spellbook" then
				minetest.chat_send_player(p_name, "You aren't holding a spellbook.")
				return
			end
			
			local book_s_name = held:get_metadata()

			local err = magic_spells.give_spell(p_name, book_s_name)

			if err == nil then
				player:set_wielded_item(ItemStack(nil))
				butt:setPosition(1000,1000)
				state:show()
			else
				minetest.chat_send_player(p_name, "Error: " .. err)
			end
		end)
	end
end)


minetest.register_craftitem("spellbooks:spellbook",
			    { description = "Spellbook",
			      inventory_image = texture,
			      wield_image = texture,
			      stack_max = 1,
			      on_use = function(stack, user)
				      local s_name = stack:get_metadata()
				      learn_form:show(user:get_player_name(), s_name)
			      end,
})


spellbooks.spellbook = function(s_name)
	local stack = ItemStack("spellbooks:spellbook")

	stack:set_metadata(s_name)

	return stack
end
