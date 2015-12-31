
local singleplayer = minetest.is_singleplayer()


local setting = minetest.setting_getbool("enable_tnt")
if (not singleplayer and setting ~= true) or (singleplayer and setting == false) then
	return
end


local spell_name = "summon_tnt"

local cast_range = 5

local description =
	"TNT beats scissors.\n"
	.. "No infinite use. Minimum startup 1.\n"
	.. "Cost: Uses * 100 / Startup, rounded up, and at least 1."


local function parse(fields)

	local startup = tonumber(fields.startup)
	local uses = tonumber(fields.uses)

	if (startup == nil) then return magic_spells.error, "Bad startup" end
	if (uses == nil) then return magic_spells.error, "Bad uses" end

	if (startup < 1) then return magic_spells.error, "Startup must be at least 1" end
	if (uses < 1) then return magic_spells.error, "Uses must be at least 1" end

	return magic_spells.complete, {
		startup = startup,
		uses = math.floor(uses)
	}


end


local function cost(aptitudes, meta)

	return math.max(1, meta.uses * 100 / meta.startup)
end


-- mostly copied from technic_extras
local function get_tnt_pos(player, range)
	local plpos = player:getpos()
	plpos.y = plpos.y+1.625
	local dir = player:get_look_dir()
	local p2 = vector.add(plpos, vector.multiply(dir, range))
	local _,pos = minetest.line_of_sight(plpos, p2)
	if not pos then
		return p2
	end
	return vector.round(vector.subtract(pos, dir))
end


local diagonal = {x=1, y=1, z=1}


local function cast_tnt(result)

	local player = minetest.get_player_by_name(result.player_name)

	if (player == nil) then
		minetest.log("error", "Player casting TNT is gone")
		return
	end


	local tnt_pos = get_tnt_pos(player, cast_range + 1)
	
	minetest.sound_play("tnt_ignite", {pos=tnt_pos})
	minetest.set_node(tnt_pos, {name = "tnt:tnt_burning"})
	minetest.get_node_timer(tnt_pos):start(2)

end
	


magic_spells.register_spell(spell_name,
			    { display_name = "Summon Lit TNT",
			      description = description,
			      -- Default prep form
			      parse_fields = parse,
			      prep_cost = cost,
			      -- Default on_begin_cast
			      on_finish_cast = cast_tnt
})
