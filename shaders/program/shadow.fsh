/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/shadow:
  Render shadow map

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 shadowcolor0_out;

/* RENDERTARGETS: 0 */

in vec2 uv;

flat in uint material_mask;
flat in vec3 tint;

#ifdef WATER_CAUSTICS
in vec3 scene_pos;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D tex;
uniform sampler2D noisetex;

#ifdef SHADOW_COLOR
uniform sampler2D shadowtex1;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform float frameTimeCounter;
uniform float rainStrength;

uniform vec2 taa_offset;
uniform vec3 light_dir;

#include "/include/surface/water_normal.glsl"
#include "/include/utility/color.glsl"

const float air_n = 1.000293; // for 0°C and 1 atm
const float water_n = 1.333;  // for 20°C

const vec3 water_absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;
const vec3 water_scattering_coeff = vec3(WATER_SCATTERING);
const vec3 water_extinction_coeff = water_absorption_coeff + water_scattering_coeff;

const float distance_through_water = 5.0; // m

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

vec3 biome_water_coeff(vec3 biome_water_color) {
	const float density_scale = 0.15;
	const float biome_color_contribution = 0.33;

	const vec3 base_absorption_coeff = vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * rec709_to_working_color;
	const vec3 forest_absorption_coeff = -density_scale * log(vec3(0.1245, 0.1797, 0.7108));

#ifdef BIOME_WATER_COLOR
	vec3 biome_absorption_coeff = -density_scale * log(biome_water_color + eps) - forest_absorption_coeff;

	return max0(base_absorption_coeff + biome_absorption_coeff * biome_color_contribution);
#else
	return base_absorption_coeff;
#endif
}

float get_water_caustics() {
#ifndef WATER_CAUSTICS
	return 1.0;
#else
	// TBN matrix for a face pointing directly upwards
	const mat3 tbn = mat3(
		-1.0, 0.0, 0.0,
		0.0, 0.0, -1.0,
		0.0, 1.0, 0.0
	);

	const bool flowing_water = false;
	const vec2 flow_dir = vec2(0.0);

	vec3 world_pos = scene_pos + cameraPosition;

	vec2 coord = -world_pos.xz;
	vec3 normal = tbn * get_water_normal(world_pos, tbn[2], coord, flow_dir, 1.0, flowing_water);

	vec3 old_pos = world_pos;
	vec3 new_pos = world_pos + refract_safe(light_dir, normal, air_n / water_n) * (distance_through_water * WATER_CAUSTICS_INTENSITY);

	float old_area = length_squared(dFdx(old_pos)) * length_squared(dFdy(old_pos));
	float new_area = length_squared(dFdx(new_pos)) * length_squared(dFdy(new_pos));

	if (old_area == 0.0 || new_area == 0.0) return 1.0;

	return 0.25 * inversesqrt(old_area / new_area);
#endif
}

void main() {
	if (material_mask == 1) { // Water
		#if defined PROGRAM_SHADOW_WATER || defined PROGRAM_SHADOW_FALLBACK
		vec3 biome_water_color = srgb_eotf_inv(tint) * rec709_to_working_color;
		vec3 absorption_coeff = biome_water_coeff(biome_water_color);

		shadowcolor0_out = clamp01(0.25 * exp(-absorption_coeff * distance_through_water) * get_water_caustics());
		#endif
	} else {
		vec4 base_color = textureLod(tex, uv, 0);
		if (base_color.a < 0.1) discard;

		shadowcolor0_out  = mix(vec3(1.0), base_color.rgb * tint, base_color.a);
		shadowcolor0_out  = 0.25 * srgb_eotf_inv(shadowcolor0_out) * rec709_to_rec2020;
		shadowcolor0_out *= step(base_color.a, 1.0 - rcp(255.0));
	}
}
