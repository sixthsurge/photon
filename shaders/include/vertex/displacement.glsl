#if !defined INCLUDE_VERTEX_DISPLACEMENT
#define INCLUDE_VERTEX_DISPLACEMENT

#if !defined PROGRAM_GBUFFERS_TERRAIN && !(defined PROGRAM_SHADOW_FALLBACK || defined PROGRAM_SHADOW_SOLID || defined PROGRAM_SHADOW_CUTOUT)
	#undef WAVING_PLANTS
	#undef WAVING_LEAVES
#endif

#if !defined PROGRAM_GBUFFERS_WATER && !(defined PROGRAM_SHADOW_FALLBACK || defined PROGRAM_SHADOW_WATER)
	#undef WATER_DISPLACEMENT
#endif

#include "/include/misc/material_masks.glsl"

#if defined WAVING_PLANTS || defined WAVING_LEAVES
#include "/include/weather/core.glsl"
#endif

#ifdef IS_IRIS 
uniform vec3 eyePosition;
#else 
#define eyePosition cameraPosition
#endif

#if defined WATER_DISPLACEMENT
float gerstner_wave(vec2 coord, vec2 wave_dir, float t, float noise, float wavelength) {
	// Gerstner wave function from Belmu in #snippets, modified
	const float g = 9.8;

	float k = tau / wavelength;
	float w = sqrt(g * k);

	float x = w * t - k * (dot(wave_dir, coord) + noise);

	return sqr(sin(x) * 0.5 + 0.5);
}

float get_water_displacement(vec3 world_pos, float skylight) {
	const float wave_frequency = 0.3 * WATER_WAVE_FREQUENCY;
	const float wave_speed     = 0.37 * WATER_WAVE_SPEED_STILL;
	const float wave_angle     = 30.0 * degree;
	const float wavelength     = 1.0;
	const vec2  wave_dir       = vec2(cos(wave_angle), sin(wave_angle));

	float wave = gerstner_wave(world_pos.xy * wave_frequency, wave_dir, frameTimeCounter * wave_speed, 0.0, wavelength);
	      wave = (wave * 0.05 - 0.025) * (skylight * 0.9 + 0.1);

	return wave;
}
#endif

#if defined WAVING_PLANTS || defined WAVING_LEAVES
vec3 get_wind_displacement(vec3 world_pos, float wind_speed, float wind_strength, bool is_tall_plant_top_vertex) {
	const float wind_angle = 30.0 * degree;
	const vec2  wind_dir   = vec2(cos(wind_angle), sin(wind_angle));

	#if defined WORLD_OVERWORLD
	// Adjust wind strength based on weather windiness
	float windiness = weather_wind();
	wind_strength *= 0.5 + windiness;
	#endif

	float t = wind_speed * frameTimeCounter;

	float gust_amount  = texture(noisetex, 0.05 * (world_pos.xz + wind_dir * t)).y;
	      gust_amount *= gust_amount;

	vec3 gust = vec3(wind_dir * gust_amount, 0.1 * gust_amount).xzy;

	world_pos = 32.0 * world_pos + 3.0 * t + vec3(0.0, golden_angle, 2.0 * golden_angle);
	vec3 wobble = sin(world_pos) + 0.5 * sin(2.0 * world_pos) + 0.25 * sin(4.0 * world_pos);

	if (is_tall_plant_top_vertex) { gust *= 2.0; wobble *= 0.5; }

	return wind_strength * (gust + 0.1 * wobble);
}
#endif

vec3 animate_vertex(vec3 world_pos, bool is_top_vertex, float skylight, uint material_mask) {
	float wind_speed = 0.3;
	float wind_strength = sqr(skylight) * (0.25 + 0.66 * rainStrength);

	// Displace plants close to the player
	vec3 to_player = eyePosition - world_pos;
	vec3 player_displacement = vec3(
		-6.0 * to_player.xz * exp2(-length(to_player * vec3(6.0, 2.0, 6.0))),
		0.0
	).xzy;

	switch (material_mask) {
#ifdef WATER_DISPLACEMENT
	case MATERIAL_WATER:
		world_pos.y += get_water_displacement(world_pos, skylight);
		return world_pos;
#endif

#ifdef WAVING_PLANTS
	case MATERIAL_SMALL_PLANTS:
	case MATERIAL_OPEN_EYEBLOSSOM:
		return world_pos + (get_wind_displacement(world_pos, wind_speed, wind_strength, false) + player_displacement) * float(is_top_vertex);

	case MATERIAL_TALL_PLANTS_LOWER:
		return world_pos + (get_wind_displacement(world_pos, wind_speed, wind_strength, false) + player_displacement) * float(is_top_vertex);

	case MATERIAL_TALL_PLANTS_UPPER:
		return world_pos + (get_wind_displacement(world_pos, wind_speed, wind_strength, is_top_vertex) + player_displacement);
#endif

#ifdef WAVING_LEAVES
	case MATERIAL_LEAVES:
		return world_pos + get_wind_displacement(world_pos, wind_speed, wind_strength * 0.5, false);
#endif

	default:
		return world_pos;
	}
}

#endif // INCLUDE_VERTEX_DISPLACEMENT
