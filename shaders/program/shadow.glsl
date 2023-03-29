#include "/include/global.glsl"

varying vec2 uv;
varying vec3 world_pos;

flat varying uint material_mask;
flat varying vec3 tint;
flat varying mat3 tbn;

// ------------
//   uniforms
// ------------

uniform sampler2D tex;
uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float frameTimeCounter;
uniform float rainStrength;

uniform vec2 taa_offset;
uniform vec3 light_dir;


//----------------------------------------------------------------------------//
#if defined vsh

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

#include "/include/light/distortion.glsl"
#include "/include/vertex/wind_animation.glsl"

float gerstner_wave(vec2 coord, vec2 wave_dir, float t, float noise, float wavelength) {
	// Gerstner wave function from Belmu in #snippets, modified
	const float g = 9.8;

	float k = tau / wavelength;
	float w = sqrt(g * k);

	float x = w * t - k * (dot(wave_dir, coord) + noise);

	return sqr(sin(x) * 0.5 + 0.5);
}

vec3 apply_water_displacement(vec3 world_pos) {
	const float wave_frequency = 0.3 * WATER_WAVE_FREQUENCY;
	const float wave_speed     = 0.37 * WATER_WAVE_SPEED_STILL;
	const float wave_angle     = 0.5;
	const float wavelength     = 1.0;
	const vec2  wave_dir       = vec2(cos(wave_angle), sin(wave_angle));

	if (material_mask != 1) return world_pos;

	vec2 wave_coord = world_pos.xz * wave_frequency;

	world_pos.y += (gerstner_wave(wave_coord, wave_dir, frameTimeCounter * wave_speed, 0.0, wavelength) * 0.05 - 0.025);

	return world_pos;
}

void main() {
	uv            = gl_MultiTexCoord0.xy;
	material_mask = uint(mc_Entity.x - 10000.0);
	tint          = gl_Color.rgb;

	tbn[0] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbn[2] = mat3(shadowModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
	tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);

	vec3 shadow_view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

	// Wind animation
	vec3 scene_pos = transform(shadowModelViewInverse, shadow_view_pos);
	bool is_top_vertex = uv.y < mc_midTexCoord.y;

	world_pos  = scene_pos + cameraPosition;
	world_pos += animate_vertex(world_pos, is_top_vertex, clamp01(rcp(240.0) * gl_MultiTexCoord1.y), material_mask);
#ifdef WATER_DISPLACEMENT
	if (material_mask == 1) world_pos = apply_water_displacement(world_pos);
#endif
	scene_pos  = world_pos - cameraPosition;
	shadow_view_pos = transform(shadowModelView, scene_pos);

	vec3 shadow_clip_pos = project_ortho(gl_ProjectionMatrix, shadow_view_pos);
	     shadow_clip_pos = distort_shadow_space(shadow_clip_pos);

	gl_Position = vec4(shadow_clip_pos, 1.0);
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec3 shadowcolor0_out;

/* DRAWBUFFERS:0 */

#include "/include/misc/water_normal.glsl"
#include "/include/utility/color.glsl"

const float air_n = 1.000293; // for 0°C and 1 atm
const float water_n = 1.333;  // for 20°C
const float distance_through_water = 5.0;

const vec3 water_absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;
const vec3 water_scattering_coeff = vec3(WATER_SCATTERING);
const vec3 water_extinction_coeff = water_absorption_coeff + water_scattering_coeff;

// using the built-in GLSL refract() seems to cause NaNs on Intel drivers, but with this
// function, which does the exact same thing, it's fine
vec3 refract_safe(vec3 I, vec3 N, float eta) {
	float NoI = dot(N, I);
	float k = 1.0 - eta * eta * (1.0 - NoI * NoI);
	if (k < 0.0) {
		return vec3(0.0);
	} else {
		return eta * I - (eta * NoI + sqrt(k)) * N;
	}
}

float get_water_caustics() {
#ifndef WATER_CAUSTICS
	return 1.0;
#else
	vec2 coord = world_pos.xz;

	bool flowing_water = abs(tbn[2].y) < 0.99;
	vec2 flow_dir = flowing_water ? normalize(tbn[2].xz) : vec2(0.0);

	vec3 normal = tbn * get_water_normal(world_pos, tbn[2], coord, flow_dir, 1.0, flowing_water);

	vec3 old_pos = world_pos;
	vec3 new_pos = world_pos + refract_safe(light_dir, normal, air_n / water_n) * distance_through_water;

	float old_area = length_squared(dFdx(old_pos)) * length_squared(dFdy(old_pos));
	float new_area = length_squared(dFdx(new_pos)) * length_squared(dFdy(new_pos));

	if (old_area == 0.0 || new_area == 0.0) return 1.0;

	return inversesqrt(old_area / new_area);
#endif
}

void main() {
#ifdef SHADOW_COLOR
	if (material_mask == 1) { // Water
		shadowcolor0_out = clamp01(0.25 * exp(-water_extinction_coeff * distance_through_water) * get_water_caustics());
	} else {
		vec4 base_color = textureLod(tex, uv, 0);
		if (base_color.a < 0.1) discard;

		shadowcolor0_out  = mix(vec3(1.0), base_color.rgb * tint, base_color.a);
		shadowcolor0_out  = 0.25 * srgb_eotf_inv(shadowcolor0_out) * rec709_to_rec2020;
		shadowcolor0_out *= step(base_color.a, 1.0 - rcp(255.0));
	}
#else
	if (texture(tex, uv).a < 0.1) discard;
#endif
}

#endif
//----------------------------------------------------------------------------//
