#if !defined WIND_ANIMATION_INCLUDED
#define WIND_ANIMATION_INCLUDED

vec3 get_wind_offset(vec3 world_pos, float wind_speed, float wind_strength, bool is_tall_plant_top_vertex) {
	const float wind_angle = 30.0 * degree;
	const vec2 wind_dir = vec2(cos(wind_angle), sin(wind_angle));

	float t = wind_speed * frameTimeCounter;

	float gust_amount  = texture(noisetex, 0.05 * (world_pos.xz + wind_dir * t)).y;
	      gust_amount *= gust_amount;

	vec3 gust = vec3(wind_dir * gust_amount, 0.1 * gust_amount).xzy;

	world_pos = 32.0 * world_pos + 3.0 * t + vec3(0.0, golden_angle, 2.0 * golden_angle);
	vec3 wobble = sin(world_pos) + 0.5 * sin(2.0 * world_pos) + 0.25 * sin(4.0 * world_pos);

	if (is_tall_plant_top_vertex) { gust *= 2.0; wobble *= 0.5; }

	return wind_strength * (gust + 0.1 * wobble);
}

vec3 animate_vertex(vec3 world_pos, bool is_top_vertex, float skylight, uint object_id) {
	float wind_speed = 0.3;
	float wind_strength = sqr(skylight) * (0.25 + 0.66 * rainStrength);

	switch (object_id) {
#ifdef WAVING_PLANTS
	case 16:
		return get_wind_offset(world_pos, wind_speed, wind_strength, false) * float(is_top_vertex);

	case 17:
		return get_wind_offset(world_pos, wind_speed, wind_strength, false) * float(is_top_vertex);

	case 18:
		return get_wind_offset(world_pos, wind_speed, wind_strength, is_top_vertex);
#endif

#ifdef WAVING_LEAVES
	case 19:
		return get_wind_offset(world_pos, wind_speed, wind_strength * 0.5, false);
#endif

	default:
		return vec3(0.0);
	}
}

#endif // WIND_ANIMATION_INCLUDED
