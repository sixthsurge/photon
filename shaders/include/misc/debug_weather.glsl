#if !defined INCLUDE_MISC_DEBUG_WEATHER
#define INCLUDE_MISC_DEBUG_WEATHER

uniform int worldTime;
uniform int worldDay;
uniform float sunAngle;

uniform float rainStrength;
uniform float wetness;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform float world_age;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

uniform float biome_cave;
uniform float biome_temperate;
uniform float biome_arid;
uniform float biome_snowy;
uniform float biome_taiga;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_may_rain;
uniform float biome_may_snow;
uniform float biome_temperature;
uniform float biome_humidity;

uniform float desert_sandstorm;

#include "/include/weather/core.glsl"
#include "/include/weather/clouds.glsl"

void debug_weather(inout vec3 color) {
	const int number_col = 30;

	Weather weather = get_weather();
	CloudsParameters clouds_params = get_clouds_parameters(weather);

	begin_text(ivec2(gl_FragCoord.xy) / debug_text_scale, debug_text_position);
	text.bg_col = vec4(0.0);
	print((_W, _E, _A, _T, _H, _E, _R));
	print_line();
	print((_T, _e, _m, _p, _e, _r, _a, _t, _u, _r, _e));
	text.char_pos.x = number_col;
	print_float(weather.temperature);
	print_line();
	print((_H, _u, _m, _i, _d, _i, _d, _i, _t, _y));
	text.char_pos.x = number_col;
	print_float(weather.humidity);
	print_line();
	print((_B, _i, _o, _m, _e, _space, _t, _e, _m, _p, _e, _r, _a, _t, _u, _r, _e));
	text.char_pos.x = number_col;
	print_float(biome_temperature);
	print_line();
	print((_B, _i, _o, _m, _e, _space, _r, _a, _i, _n, _f, _a, _l, _l));
	text.char_pos.x = number_col;
	print_float(biome_humidity);
	print_line();
	print((_W, _i, _n, _d));
	text.char_pos.x = number_col;
	print_float(weather.wind);
	print_line();
	print_line();
	print((_C, _L, _O, _U, _D, _S));
	print_line();
	print((_C, _u, _m, _u, _l, _u, _s, _space, _c, _o, _n, _g, _e, _s, _t, _u, _s, _space, _b, _l, _e, _n, _d));
	text.char_pos.x = number_col;
	print_float(clouds_params.cumulus_congestus_blend);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _0, _space, _c, _o, _v, _e, _r, _a, _g, _e, _space, _m, _i, _n));
	text.char_pos.x = number_col;
	print_float(clouds_params.l0_coverage.x);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _0, _space, _c, _o, _v, _e, _r, _a, _g, _e, _space, _m, _a, _x));
	text.char_pos.x = number_col;
	print_float(clouds_params.l0_coverage.y);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _0, _space, _c, _u, _m, _u, _l, _u, _s, _minus, _s, _t, _r, _a, _t, _u, _s, _space, _b, _l, _e, _n, _d));
	text.char_pos.x = number_col;
	print_float(clouds_params.l0_cumulus_stratus_blend);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _1, _space, _c, _o, _v, _e, _r, _a, _g, _e, _space, _m, _i, _n));
	text.char_pos.x = number_col;
	print_float(clouds_params.l1_coverage.x);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _1, _space, _c, _o, _v, _e, _r, _a, _g, _e, _space, _m, _a, _x));
	text.char_pos.x = number_col;
	print_float(clouds_params.l1_coverage.y);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _1, _space, _c, _u, _m, _u, _l, _u, _s, _minus, _s, _t, _r, _a, _t, _u, _s, _space, _b, _l, _e, _n, _d));
	text.char_pos.x = number_col;
	print_float(clouds_params.l1_cumulus_stratus_blend);
	print_line();
	print((_C, _i, _r, _r, _u, _s, _space, _a, _m, _o, _u, _n, _t));
	text.char_pos.x = number_col;
	print_float(clouds_params.cirrus_amount);
	print_line();
	print((_C, _i, _r, _r, _o, _c, _u, _m, _u, _l, _u, _s, _space, _a, _m, _o, _u, _n, _t));
	text.char_pos.x = number_col;
	print_float(clouds_params.cirrocumulus_amount);
	print_line();
	print((_N, _o, _c, _t, _i, _l, _u, _c, _e, _n, _t, _space, _a, _m, _o, _u, _n, _t));
	text.char_pos.x = number_col;
	print_float(clouds_params.noctilucent_amount);
	print_line();
	print((_C, _r, _e, _p, _u, _s, _c, _u, _l, _a, _r, _space, _r, _a, _y, _s, _space, _a, _m, _o, _u, _n, _t));
	text.char_pos.x = number_col;
	print_float(clouds_params.crepuscular_rays_amount);
	print_line();
	end_text(color);
}

#endif // INCLUDE_MISC_DEBUG_WEATHER
