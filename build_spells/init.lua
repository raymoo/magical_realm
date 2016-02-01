local modpath = minetest.get_modpath(minetest.get_current_modname()) .. "/"

dofile(modpath .. "excavate.lua")


loot.register_loot({ weights = { generic = 16, magical = 80, book = 80 },
		     payload = { stack = spellbooks.spellbook("excavate") },
})
