#if !defined INCLUDE_LIGHT_LPV_LIGHT_COLORS
#define INCLUDE_LIGHT_LPV_LIGHT_COLORS

const vec3[32] light_color = vec3[32](
	vec3(S_WHITE_LIGHT_R, S_WHITE_LIGHT_G, S_WHITE_LIGHT_B) * S_WHITE_LIGHT_I, // Strong white light
	vec3(REDSTONE_WIRE_R, REDSTONE_WIRE_G, REDSTONE_WIRE_B) *  REDSTONE_WIRE_I, // Redstone wire
	vec3(W_WHITE_LIGHT_R, W_WHITE_LIGHT_G, W_WHITE_LIGHT_B) *  W_WHITE_LIGHT_I, // Weak white light
	vec3(S_GOLD_LIGHT_R, S_GOLD_LIGHT_G, S_GOLD_LIGHT_B) * S_GOLD_LIGHT_I, // Strong golden light
	vec3(M_GOLD_LIGHT_R, M_GOLD_LIGHT_G, M_GOLD_LIGHT_B) *  M_GOLD_LIGHT_I, // Medium golden light
	vec3(W_GOLD_LIGHT_R, W_GOLD_LIGHT_G, W_GOLD_LIGHT_B) *  W_GOLD_LIGHT_I, // Weak golden light
	vec3(REDSTONE_COMPONENTS_R, REDSTONE_COMPONENTS_G, REDSTONE_COMPONENTS_B) * REDSTONE_COMPONENTS_I, // Redstone components
	vec3(1.00, 0.15, 0.00) * 10.0, // Lava
	vec3(M_ORANGE_LIGHT_R, M_ORANGE_LIGHT_G, M_ORANGE_LIGHT_B) *  M_ORANGE_LIGHT_I, // Medium orange light
	vec3(1.00, 0.63, 0.15) *  1.0, // Brewing stand and Magma block
	vec3(JACK_O_LANTERN_R, JACK_O_LANTERN_G, JACK_O_LANTERN_B) *  JACK_O_LANTERN_I, // Jack o' Lantern
	vec3(SOUL_LIGHTS_R, SOUL_LIGHTS_G, SOUL_LIGHTS_B) *  SOUL_LIGHTS_I, // Soul lights
	vec3(BEACON_R, BEACON_G, BEACON_B) * BEACON_I, // Beacon
	vec3(SCULK_R, SCULK_G, SCULK_B) *  SCULK_I, // Sculk
	vec3(0.75, 1.00, 0.83) *  0.25, // End portal frame
	vec3(PINK_GLOW_R, PINK_GLOW_G, PINK_GLOW_B) *  PINK_GLOW_I, // Pink glow
	vec3(SEA_PICKLE_R, SEA_PICKLE_G, SEA_PICKLE_B) *  SEA_PICKLE_I, // Sea pickle
	vec3(NETHER_PLANTS_R, NETHER_PLANTS_G, NETHER_PLANTS_B) *  NETHER_PLANTS_I, // Nether plants
	vec3(CANDLES_R, CANDLES_G, CANDLES_B) * CANDLES_I, // Candles
	vec3(OCHRE_R, OCHRE_G, OCHRE_B) *  OCHRE_I, // Ochre froglight
	vec3(VERDANT_R, VERDANT_G, VERDANT_B) * VERDANT_I, // Verdant froglight
	vec3(PEARL_R, PEARL_G, PEARL_B) * PEARL_I, // Pearlescent froglight
	vec3(ENCHANTING_TABLE_R, ENCHANTING_TABLE_G, ENCHANTING_TABLE_B) * ENCHANTING_TABLE_I, // Enchanting table
	vec3(AMETHYST_R, AMETHYST_G, AMETHYST_B) * AMETHYST_I, // Amethyst cluster
	vec3(CALLIBRATED_SCULK_R, CALLIBRATED_SCULK_G, CALLIBRATED_SCULK_B) * CALLIBRATED_SCULK_I, // Calibrated sculk sensor
	vec3(ACTIVE_SCULK_R, ACTIVE_SCULK_G, ACTIVE_SCULK_B) * ACTIVE_SCULK_I, // Active sculk sensor
	vec3(REDSTONE_BLOCK_R, REDSTONE_BLOCK_G, REDSTONE_BLOCK_B) * REDSTONE_BLOCK_I, // Redstone block
	vec3(CRIMSON_BLOCKS_R, CRIMSON_BLOCKS_G, CRIMSON_BLOCKS_B) * 1.5, // Crimson blocks
	vec3(WARPED_PLANTS_R, WARPED_PLANTS_G, WARPED_PLANTS_B) * WARPED_PLANTS_I, // Warped plants
	vec3(0.0), // Unused
	vec3(NETHER_PORTAL_R, NETHER_PORTAL_G, NETHER_PORTAL_B) * NETHER_PORTAL_I * COLORED_LIGHTS_EMISSION, // Nether portal
	vec3(0.0)  // End portal
);

const vec3[16] tint_color = vec3[16](
	vec3(1.0, 0.1, 0.1), // Red
	vec3(1.0, 0.5, 0.1), // Orange
	vec3(1.0, 1.0, 0.1), // Yellow
	vec3(0.7, 0.7, 0.0), // Brown
	vec3(0.1, 1.0, 0.1), // Green
	vec3(0.5, 1.0, 0.5), // Lime
	vec3(0.1, 0.1, 1.0), // Blue
	vec3(0.5, 0.5, 1.0), // Light blue
	vec3(0.1, 1.0, 1.0), // Cyan
	vec3(0.7, 0.1, 1.0), // Purple
	vec3(1.0, 0.1, 1.0), // Magenta
	vec3(1.0, 0.5, 1.0), // Pink
	vec3(0.1, 0.1, 0.1), // Black
	vec3(0.9, 0.9, 0.9), // White
	vec3(0.3, 0.3, 0.3), // Gray
	vec3(0.7, 0.7, 0.7)  // Light gray
);

#endif // INCLUDE_LIGHT_LPV_LIGHT_COLORS
