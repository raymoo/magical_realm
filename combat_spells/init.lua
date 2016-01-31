local mod_path = minetest.get_modpath(minetest.get_current_modname()) .. "/"

dofile(mod_path .. "summon_tnt.lua")
dofile(mod_path .. "magic_missile.lua")
dofile(mod_path .. "reflect_lesser.lua")
dofile(mod_path .. "rock_hide.lua")


loot.register_loot({ weights = { generic = 20, magical = 100, book = 100 },
		     payload = { stack = spellbooks.spellbook("magic_missile") },
})

loot.register_loot({ weights = { generic = 10, magical = 50, book = 50 },
		     payload = { stack = spellbooks.spellbook("reflect_lesser") },
})

loot.register_loot({ weights = { generic = 10, magical = 50, book = 50 },
		     payload = { stack = spellbooks.spellbook("rock_hide") },
})
