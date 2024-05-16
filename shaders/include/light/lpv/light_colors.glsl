#if !defined INCLUDE_LIGHT_LPV_LIGHT_COLORS
#define INCLUDE_LIGHT_LPV_LIGHT_COLORS

const vec3[32] light_color = vec3[32](
	vec3(1.00, 1.00, 1.00) * 1.80 * COLORED_LIGHTS_I, // Strong white light
	vec3(1.00, 0.18, 0.00) *  0.35 * COLORED_LIGHTS_I, // Redstone wire
	vec3(1.00, 1.00, 1.00) *  0.75 * COLORED_LIGHTS_I, // Weak white light
	vec3(1.00, 0.45, 0.20) * 1.50 * COLORED_LIGHTS_I, // Strong golden light
	vec3(1.00, 0.70, 0.35) *  0.8 * COLORED_LIGHTS_I, // Medium golden light
	vec3(1.00, 0.40, 0.15) *  0.65 * COLORED_LIGHTS_I, // Weak golden light
	vec3(1.00, 0.18, 0.10) *  1.75 * COLORED_LIGHTS_I, // Redstone components
	vec3(1.00, 0.15, 0.00) * 10.0 * COLORED_LIGHTS_I, // Lava
	vec3(1.00, 0.45, 0.10) *  2.45 * COLORED_LIGHTS_I, // Medium orange light
	vec3(1.00, 0.63, 0.15) *  1.0 * COLORED_LIGHTS_I, // Brewing stand and Magma block
	vec3(1.00, 0.70, 0.35) *  1.3 * COLORED_LIGHTS_I, // Jack o' Lantern
	vec3(0.05, 0.23, 1.00) *  3.1 * COLORED_LIGHTS_I, // Soul lights
	vec3(0.30, 0.53, 1.00) * 4.5 * COLORED_LIGHTS_I, // Beacon
	vec3(0.15, 0.83, 1.00) *  8.75 * COLORED_LIGHTS_I, // Sculk
	vec3(0.75, 1.00, 0.83) *  0.25 * COLORED_LIGHTS_I, // End portal frame
	vec3(0.60, 0.10, 1.00) *  0.6 * COLORED_LIGHTS_I, // Pink glow
	vec3(0.75, 1.00, 0.50) *  0.25 * COLORED_LIGHTS_I, // Sea pickle
	vec3(1.00, 0.50, 0.25) *  1.0 * COLORED_LIGHTS_I, // Nether plants
	vec3(1.00, 0.70, 0.35) *  1.3 * COLORED_LIGHTS_I, // Candles
	vec3(1.00, 0.65, 0.30) *  1.9 * COLORED_LIGHTS_I, // Ochre froglight
	vec3(0.76, 1.00, 0.34) *  1.9 * COLORED_LIGHTS_I, // Verdant froglight
	vec3(0.75, 0.44, 1.00) *  1.9 * COLORED_LIGHTS_I, // Pearlescent froglight
	vec3(0.60, 0.10, 1.00) *  0.5 * COLORED_LIGHTS_I, // Enchanting table
	vec3(0.75, 0.44, 1.00) *  1.0 * COLORED_LIGHTS_I, // Amethyst cluster
	vec3(0.75, 0.44, 1.00) *  1.0 * COLORED_LIGHTS_I, // Calibrated sculk sensor
	vec3(0.75, 1.00, 0.83) *  1.5 * COLORED_LIGHTS_I, // Active sculk sensor
	vec3(1.00, 0.00, 0.00) *  1.9 * COLORED_LIGHTS_I, // Redstone block
	vec3(1.00, 0.30, 0.05) *  1.5 * COLORED_LIGHTS_I, // Crimson blocks
	vec3(0.25, 0.70, 1.00) *  1.5 * COLORED_LIGHTS_I, // Warped plants
	vec3(0.0), // Unused
	vec3(0.60, 0.10, 1.00) * 18.0 * COLORED_LIGHTS_EMISSION, // Nether portal
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
