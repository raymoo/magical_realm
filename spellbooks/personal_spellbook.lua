
local texture = "default_book.png^[colorize:#00FF5E:127"


local main_form = smartfs.create("spellbooks:personal_spellbook",
			   function(state)
	local p_name = state.player

	state:size(5, 1.33)

	local prep_butt = state:button(0.33,0.16, 2,1, "prep", "Prepare")
	local unprep_butt = state:button(2.67,0.16, 2,1, "unprep", "Unprepare")

	prep_butt:click(function(self, state)
			magic_spells.prepare_spells(p_name)
	end)

	unprep_butt:click(function(self, state)
			local err = magic_spells.reset_preparation(p_name, false)

			if (err ~= nil) then
				minetest.chat_send_player(p_name, err)
			else
				minetest.chat_send_player(p_name, "Slots restored.")
			end
	end)
end)


local function show_main_form(stack, player, pointed_thing)

	main_form:show(player:get_player_name())
end


minetest.register_craftitem("spellbooks:personal_spellbook",
			    { description = "Personal Spellbook",
			      inventory_image = texture,
			      wield_image = texture,
			      stack_max = 1,
			      range = 10,
			      liquids_pointable = true,
			      on_place = show_main_form,
			      on_use = show_main_form

})


minetest.register_craft(
	{ type = "shapeless",
	  output = "spellbooks:personal_spellbook",
	  recipe = {
		  "default:book",
		  "dye:green",
	  },
})
