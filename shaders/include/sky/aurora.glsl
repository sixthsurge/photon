#ifndef INCLUDE_SKY_AURORA
#define INCLUDE_SKY_AURORA

#define AURORA_SPEED 1.0
#define AURORA_SPEED2 0.3
#define AURORA_SAMPLES 50
#define AURORA_INTENSITY 1.8

#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/geometry.glsl"
#include "/include/utility/phase_functions.glsl"



#if AURORA_TYPE == AURORA_PHOTON

float aurora_shape(vec3 pos, float altitude_fraction) {
	const vec2 wind_0     = 0.001 * vec2(0.7, 0.1);
	const vec2 wind_1     = 0.0013 * vec2(-0.1, -0.7);
	float frequency = 0.00003 * mix(AURORA_FREQUENCY, AURORA_FREQUENCY_SNOW, biome_may_snow);

	float height_fade = cube(1.0 - altitude_fraction) * linear_step(0.0, 0.025, altitude_fraction);

	float worley_0 = texture(noisetex, pos.xz * frequency + wind_0 * frameTimeCounter).y;
	float worley_1 = texture(noisetex, pos.xz * frequency + wind_1 * frameTimeCounter).y;

	return linear_step(1.0, 2.0, worley_0 + worley_1) * height_fade;
}

vec3 aurora_color(vec3 pos, float altitude_fraction) {
	return mix(aurora_colors[0], aurora_colors[1], clamp01(dampen(altitude_fraction)));
}

vec3 draw_aurora(vec3 ray_dir, float dither) {
	const uint step_count      = 64u;
	const float rcp_steps      = rcp(float(step_count));
	const float volume_bottom  = 1000.0;
	const float volume_top     = 3000.0;
	const float volume_radius  = 20000.0;

	if (aurora_amount < 0.01) return vec3(0.0);

	// Calculate distance to enter and exit the volume

	float rcp_dir_y = rcp(ray_dir.y);
	float distance_to_lower_plane = volume_bottom * rcp_dir_y;
	float distance_to_upper_plane = volume_top    * rcp_dir_y;
	float distance_to_cylinder    = volume_radius * rcp_length(ray_dir.xz);

	float distance_to_volume_start = distance_to_lower_plane;
	float distance_to_volume_end   = min(distance_to_cylinder, distance_to_upper_plane);

	// Make sure that the volume is intersected
	if (distance_to_volume_start > distance_to_volume_end) return vec3(0.0);

	// Raymarching setup

	float ray_length  = max0(distance_to_volume_end - distance_to_volume_start);
	float step_length = ray_length * rcp_steps;

	vec3 ray_pos  = ray_dir * (distance_to_volume_start + step_length * dither);
	vec3 ray_step = ray_dir * step_length;

	vec3 emission = vec3(0.0);

	// Raymarching loop

	for (uint i = 0u; i < step_count; ++i, ray_pos += ray_step) {
		float altitude_fraction = linear_step(volume_bottom, volume_top, ray_pos.y);
		float shape = aurora_shape(ray_pos, altitude_fraction);
		vec3 color  = aurora_color(ray_pos, altitude_fraction);

		float d = length(ray_pos.xz);
		float distance_fade = (1.0 - cube(d * rcp(volume_radius))) * (1.0 - exp2(-0.001 * d));

		emission += color * (shape * distance_fade * step_length);
	}

	return (0.001 * mix(AURORA_BRIGHTNESS, AURORA_BRIGHTNESS_SNOW, biome_may_snow) ) * emission * aurora_amount;
}



#elif AURORA_TYPE == AURORA_NIMITZ

// Aurora from shadertoy by nimitz https://www.shadertoy.com/view/XtGGRt

mat2 mm2(in float a) {
	float c = cos(a), s = sin(a);
	return mat2(c,s,-s,c);
}
mat2 m2 = mat2(0.95534, 0.29552, -0.29552, 0.95534);
float tri(in float x) {
	return clamp(abs(fract(x)-.5),0.01,0.49);
}
vec2 tri2(in vec2 p) {
	return vec2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));
}

float triNoise2d(in vec2 p, float spd) {
	float z = 1.8;
	float z2 = 2.5;
	float rz = 0.0;
	p *= mm2(p.x * 0.06);
	vec2 bp = p;
	for (float i = 0.0; i < 5.0; i++ ) {
		vec2 dg = tri2(bp * 1.85) * 0.75;
		dg *= mm2(world_age * 0.02 * pi * spd);
		p -= dg / z2;

		bp *= 1.3;
		z2 *= 0.45;
		z *= 0.42;
		p *= 1.21 + (rz - 1.0) * 0.02;

		rz += tri(p.x + tri(p.y)) * z;
		p *= -m2;
	}
	return clamp(1.0 / pow(rz * 29.0, 1.3), 0.0, 0.55);
}

float hash21(in vec2 n) {
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

vec4 aurora(vec3 dir) {
	vec4 outColor = vec4(0);
	vec4 avgColor = vec4(0);

	for(int i = 0; i < AURORA_SAMPLES; i++) {
		float amp_fraction = float(i) / float(AURORA_SAMPLES - 1);
		float jitter = 0.012 * hash21(gl_FragCoord.xy) * smoothstep(0.0, 15.0, float(i));
		float height = ((0.8 + pow(amp_fraction * 24, 1.4) * 0.004)) / (dir.y * 2.0 + 0.4);
		height -= jitter;

		vec2 coord = (height * dir).zx;
		float pattern = triNoise2d(coord * mix(AURORA_FREQUENCY, AURORA_FREQUENCY_SNOW, biome_may_snow), AURORA_SPEED);
		vec4 interColor = vec4(0.0, 0.0, 0.0, pattern);

		interColor.rgb = pattern * mix(aurora_colors[0], aurora_colors[1], smoothstep(0.0, 1.0, amp_fraction)); //mix(aurora_colors[0], aurora_colors[1], smoothstep(0.0, 1.0, sqr(amp_fraction)));
		//interColor.rgb = pattern * aurora_color(vec3(0), smoothstep(0.0, 1.0, amp_fraction));
		//interColor.rgb = pattern * (sin(1.0 - vec3(2.15, -0.5, 1.2) + (amp_fraction * 49) * 0.043) * 0.5 + 0.5);
		avgColor =  mix(avgColor, interColor, 0.5);
		outColor += avgColor * exp2(-(amp_fraction * 24) * 0.065 - 2.5) * smoothstep(0.0, 5.0, (amp_fraction * 24)) * (rcp(AURORA_SAMPLES) * 24);
	}

	outColor *= clamp01(dir.y * 15.0 + 0.4);

	return outColor * mix(AURORA_BRIGHTNESS, AURORA_BRIGHTNESS_SNOW, biome_may_snow);
}

vec3 draw_aurora(vec3 ray_dir, float dither) {
	if (aurora_amount < 0.01) return vec3(0.0);
	//ray_dir *= dither;

	vec3 color = vec3(0.0);
	float fade = smoothstep(0.0, 0.1, abs(ray_dir.y));

	if (ray_dir.y > 0.0){
		vec4 aur = smoothstep(0.0, 1.5, aurora(ray_dir)) * fade;
		color = color * (1.0 - aur.a) + aur.rgb;
	} /*else {
		color += mix(aurora_colors[0], aurora_colors[1], -ray_dir.y) * triNoise2d(ray_dir.xz, AURORA_SPEED2) * fade * 0.3;
	}*/

	return color * aurora_amount;

}

#endif // AURORA_TYPE

#endif // INCLUDE_SKY_AURORA
