
local base_prep = magic_spells.base_prep


local last_deaths = {}

local cooldown = 600


minetest.register_craftitem("magic_battle:prep_slot",
	{ description = "Preparation Slot",
	  inventory_image = "magic_battle_prep_slot.png",
	  wield_image = "magic_battle_prep_slot.png",
	  stack_max = 1000,
	  on_use = function(stack, user)
		  local p_name = user:get_player_name()
		  
		  magic_spells.change_prep_slots(p_name, 1)
		  stack:take_item()

		  minetest.chat_send_player(p_name, "Max slots increased by 1")

		  return stack
	  end,
})


minetest.register_on_dieplayer(function(player)
	local p_name = player:get_player_name()

	local now = os.time()

	local last_death = last_deaths[p_name] or 0
	
	local low
	
	if now - last_death >= cooldown then
		last_deaths[p_name] = now
		low = 1
	else
		low = 0
	end

	local p_pos = player:getpos()

	local drop_pos = vector.add({x=0,y=1,z=0}, p_pos)
	
	local old_max = magic_spells.get_max_prep(p_name)

	if old_max == nil then return end

	magic_spells.set_prep_slots(p_name, base_prep)

	minetest.chat_send_player(p_name, "You lost all your extra preparation slots.")

	local surplus = math.max(0, old_max - base_prep)

	local drops = {}

	local slots = ItemStack("magic_battle:prep_slot")
	slots:set_count(math.max(low, math.floor(surplus / 2)))

	table.insert(drops, slots)

	if math.random(3) == 1 and now - last_death >= cooldown then
		for i, v in ipairs(loot.generate_loot("magical", 1)) do
			table.insert(drops, v)
		end
	end

	for i, v in ipairs(drops) do
		minetest.item_drop(v, player, drop_pos)
	end
end)


minetest.register_craft(
	{ type = "shapeless",
	  output = "magic_battle:prep_slot 5",
	  recipe = { "spellbooks:spellbook" },
})
