local mod_path = minetest.get_modpath(minetest.get_current_modname()) .. "/"

dofile(mod_path .. "blink.lua")
dofile(mod_path .. "ethereal_jaunt.lua")
dofile(mod_path .. "moon_shoes.lua")
dofile(mod_path .. "haste.lua")


loot.register_loot({ weights = { generic = 20, magical = 100 },
		     payload = { stack = spellbooks.spellbook("blink") },
})

loot.register_loot({ weights = { generic = 4, magical = 20 },
		     payload = { stack = spellbooks.spellbook("ethereal_jaunt") },
})

loot.register_loot({ weights = { generic = 20, magical = 100 },
		     payload = { stack = spellbooks.spellbook("moon_shoes") },
})

loot.register_loot({ weights = { generic = 10, magical = 50 },
		     payload = { stack = spellbooks.spellbook("haste") },
})

