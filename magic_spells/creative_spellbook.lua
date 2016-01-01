
local texture = "default_book.png^[colorize:#5412B8:127"


local formname = "magic_spells:creative_book"

local template =
	"size[8,8]label[0.5,0;Select a spell to learn]"
	.. "textlist[0.5,0.5;3,6;selected;%s]"
	.. "button[3.5,7;2,1;learn;Learn]"
	.. "textarea[4.5,0.5;3.5,6;desc;Description;%s]"
	.. "button[5.5,7;2,1;unprepare;Unprepare]"


-- Stores a table with idx, spell_names, descs, text_list
local formdata = {}

local function show_select_learn(p_name)


	local learnable = {}
	local display_names = {}
	local descriptions = {}


	for s_name, def in pairs(magic_spells.registered_spells) do

		table.insert(learnable, s_name)
		table.insert(display_names, def.display_name)
		table.insert(descriptions, def.description)
	end


	local text_list = table.concat(display_names, ",")

	local formspec = string.format(template, text_list, "")

	formdata[p_name] =
		{ idx = nil,
		  spell_names = learnable,
		  descs = descriptions,
		  text_list = text_list
		}

	minetest.show_formspec(p_name, formname, formspec)
end


local function handle_fields(player, formname, fields)

	if (formname ~= "magic_spells:creative_book") then return false end

	local p_name = player:get_player_name()

	local data = formdata[p_name]

	if (data == nil) then return true end

	if (fields["selected"]) then

		local event = minetest.explode_textlist_event(fields.selected)

		data.idx = tonumber(event.index)

		local selected_desc = data.descs[data.idx]

		local description

		if (selected_desc == nil) then
			description = ""
		else
			local s_name = data.spell_names[data.idx]
			
			description =
				selected_desc .. "\n\nEnter in creative wand: " .. s_name
		end

		local formspec = string.format(template, data.text_list, description)

		minetest.show_formspec(p_name, formname, formspec)

		return true
	end

	if (fields["learn"]) then

		local s_name = data.spell_names[data.idx]

		print(data.idx)

		print(s_name)

		if (s_name == nil) then
			show_select_learn(p_name)
			return true
		end

		local err = magic_spells.give_spell(p_name, s_name)

		if (err ~= nil) then
			minetest.chat_send_player(p_name, err)
			return true
		end

		show_select_learn(p_name)

		return true
	end

	if (fields["unprepare"]) then

		local err = magic_spells.reset_preparation(p_name, true)
		if (err ~= nil) then
			minetest.chat_send_player(p_name, err)
		else
			minetest.chat_send_player(p_name, "Preparation slots restored.")
		end

		return true
	end

	return false
end


minetest.register_on_player_receive_fields(handle_fields)


minetest.register_craftitem("magic_spells:creative_spellbook",
			    { description = "Creative Spellbook",
			      inventory_image = texture,
			      wield_image = texture,
			      stack_max = 1,
			      range = 10,
			      liquids_pointable = true,
			      on_place = function(stack, player, pointed_thing)

				      magic_spells.prepare_spells(player:get_player_name())
			      end,

			      on_use = function(stack, player, pointed_thing)

				      show_select_learn(player:get_player_name())

end})
