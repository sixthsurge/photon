#if !defined INCLUDE_LIGHTING_LPV_LIGHT_COLORS
#define INCLUDE_LIGHTING_LPV_LIGHT_COLORS

const vec3[32] light_color = vec3[32](
	vec3(ST_WHITE_LIGHT_R * 1.00, ST_WHITE_LIGHT_G * 1.00, ST_WHITE_LIGHT_B * 1.00) * 12.0, // Strong white light
	vec3(MD_WHITE_LIGHT_R * 1.00, MD_WHITE_LIGHT_G * 1.00, MD_WHITE_LIGHT_B * 1.00) *  6.0, // Medium white light
	vec3(WE_WHITE_LIGHT_R * 1.00, WE_WHITE_LIGHT_G * 1.00, WE_WHITE_LIGHT_B * 1.00) *  1.0, // Weak white light
	vec3(ST_GOLDEN_LIGHT_R * 1.00, ST_GOLDEN_LIGHT_G * 0.55, ST_GOLDEN_LIGHT_B * 0.27) * 14.0, // Strong golden light
	vec3(MD_GOLDEN_LIGHT_R * 1.00, MD_GOLDEN_LIGHT_G * 0.57, MD_GOLDEN_LIGHT_B * 0.30) *  8.0, // Medium golden light
	vec3(WE_GOLDEN_LIGHT_R * 1.00, WE_GOLDEN_LIGHT_G * 0.57, WE_GOLDEN_LIGHT_B * 0.30) *  6.0, // Weak golden light
	vec3(RS_LIGHT_R * 1.00, RS_LIGHT_G * 0.18, RS_LIGHT_B * 0.10) *  5.0, // Redstone components
	vec3(LAVA_LIGHT_R * 1.00, LAVA_LIGHT_G * 0.38, LAVA_LIGHT_B * 0.10) *  7.0, // Lava
	vec3(MD_ORANGE_LIGHT_R * 1.00, MD_ORANGE_LIGHT_G * 0.45, MD_ORANGE_LIGHT_B * 0.10) *  9.0, // Medium orange light
	vec3(1.00, 0.63, 0.15) *  4.0, // Brewing stand
	vec3(JACK_LIGHT_R * 1.00, JACK_LIGHT_G * 0.57, JACK_LIGHT_B * 0.30) * 12.0, // Medium golden light
	vec3(SOUL_LIGHT_R * 0.45, SOUL_LIGHT_G * 0.73, SOUL_LIGHT_B * 1.00) *  6.0, // Soul lights
	vec3(0.45, 0.73, 1.00) * 14.0, // Beacon
	vec3(SCULK_LIGHT_R * 0.75, SCULK_LIGHT_G * 1.00, SCULK_LIGHT_B * 0.83) *  3.0, // Sculk
	vec3(0.75, 1.00, 0.83) *  1.0, // End portal frame
	vec3(0.60, 0.10, 1.00) *  2.5, // Pink glow
	vec3(0.75, 1.00, 0.50) *  1.0, // Sea pickle
	vec3(1.00, 0.50, 0.25) *  4.0, // Nether plants
	vec3(CANDLE_LIGHT_R * 1.00, CANDLE_LIGHT_G * 0.57, CANDLE_LIGHT_B * 0.30) *  8.0, // Medium golden light
	vec3(1.00, 0.65, 0.30) *  8.0, // Ochre froglight
	vec3(0.86, 1.00, 0.44) *  8.0, // Verdant froglight
	vec3(0.75, 0.44, 1.00) *  8.0, // Pearlescent froglight
	vec3(0.45, 0.73, 1.00) *  4.0, // Enchanting table
	vec3(0.75, 0.44, 1.00) *  4.0, // Amethyst cluster
	vec3(0.75, 0.44, 1.00) *  4.0, // Calibrated sculk sensor
	vec3(0.75, 1.00, 0.83) *  6.0, // Active sculk sensor
	vec3(RS_LIGHT_R * 1.00, RS_LIGHT_G * 0.18, RS_LIGHT_B * 0.10) *  3.3, // Redstone block
	vec3(1.00, 0.50, 0.25) *  3.0, // Open eyeblossom
	vec3(0.0), // Unused
	vec3(0.0), // Unused
	vec3(0.60, 0.10, 1.00) * 12.0, // Nether portal
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

#endif // INCLUDE_LIGHTING_LPV_LIGHT_COLORS
