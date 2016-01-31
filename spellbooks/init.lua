local modpath = minetest.get_modpath(minetest.get_current_modname()) .. "/"

spellbooks = {}

dofile(modpath .. "personal_spellbook.lua")
dofile(modpath .. "spellbook.lua")
