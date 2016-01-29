local me = monoidal_effects

me.register_type("magic_monoids:speed_bonus",
	{ disp_name = "",
	  dynamic = true,
	  monoids = { speed = true },
	  tags = {},
	  hidden = true,
	  cancel_on_death = false,
	  values = { speed = 1 }, -- Dummy default
})


me.register_type("magic_monoids:speed_malus",
	{ disp_name = "",
	  dynamic = true,
	  monoids = { speed = true },
	  tags = {},
	  hidden = true,
	  cancel_on_death = false,
	  values = { speed = 1 }, -- Dummy default
})


me.register_monoid("magic_monoids:speed_bonus",
	{ combine = math.max,
	  fold = function(elems)
		  local max = 1
		  for k, v in pairs(elems) do
			  max = math.max(max, v)
		  end

		  return max
	  end,
	  identity = 1,
	  apply = function(bonus, player)
		  local p_name = player:get_player_name()
		  
		  me.cancel_effect_type("magic_monoids:speed_bonus", p_name)
		  me.apply_effect("magic_monoids:speed_bonus", "perm", p_name,
				  { speed = bonus })
	  end
})


me.register_monoid("magic_monoids:speed_malus",
	{ combine = math.min,
	  fold = function(elems)
		  local min = 1
		  for k, v in pairs(elems) do
			  min = math.min(min, v)
		  end

		  return min
	  end,
	  identity = 1,
	  apply = function(malus, player)
		  local p_name = player:get_player_name()
		  
		  me.cancel_effect_type("magic_monoids:speed_malus", p_name)
		  me.apply_effect("magic_monoids:speed_malus", "perm", p_name,
				  { speed = malus })
	  end
})
