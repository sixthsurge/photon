#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  world0/composite1.fsh:
  Shade translucent layer, apply SSR and VL

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:03 */
layout (location = 0) out vec3 scene_color;
layout (location = 1) out float bloomy_fog;

in vec2 uv;

flat in vec3 light_color;
flat in vec3 sun_color;
flat in vec3 moon_color;
flat in vec3 water_fog_color;
flat in mat3 sky_samples;

uniform sampler2D noisetex;

uniform sampler2D colortex0; // Scene color
uniform sampler2D colortex1; // Gbuffer 0
uniform sampler2D colortex2; // Gbuffer 1
uniform sampler2D colortex3; // Blended color
uniform sampler2D colortex4; // Sky capture
uniform sampler2D colortex5; // Scene history
uniform sampler2D colortex6; // Volumetric fog scattering
uniform sampler2D colortex7; // Volumetric fog transmittance

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef SHADOW
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float near;
uniform float far;

uniform float frameTimeCounter;
uniform float sunAngle;

uniform int worldTime;
uniform int frameCounter;

uniform int isEyeInWater;
uniform float blindness;
uniform float nightVision;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float eye_skylight;

uniform float biome_cave;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#define PROGRAM_COMPOSITE1
#define TEMPORAL_REPROJECTION
#define WORLD_OVERWORLD

#ifdef SHADOW_COLOR
	#undef SHADOW_COLOR
#endif

#ifdef SH_SKYLIGHT
	#undef SH_SKYLIGHT
#endif

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/space_conversion.glsl"

#include "/include/diffuse_lighting.glsl"
#include "/include/fog.glsl"
#include "/include/material.glsl"
#include "/include/shadow_mapping.glsl"
#include "/include/specular_lighting.glsl"
#include "/include/water_fog.glsl"

/*
const bool colortex5MipmapEnabled = true;
 */

// https://iquilezles.org/www/articles/texture/texture.htm
vec4 smooth_filter(sampler2D sampler, vec2 coord) {
	vec2 res = vec2(textureSize(sampler, 0));

	coord = coord * res + 0.5;

	vec2 i, f = modf(coord, i);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	coord = i + f;

	coord = (coord - 0.5) / res;
	return texture(sampler, coord);
}

// http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
vec3 purkinje_shift(vec3 rgb, float purkinje_intensity) {
	const vec3 purkinje_tint = vec3(0.57, 0.71, 1.0);
	const vec3 rod_response = vec3(7.15e-5, 4.81e-1, 3.28e-1) * rec709_to_rec2020;

	if (purkinje_intensity == 0.0) return rgb;

	vec3 xyz = rgb * rec2020_to_xyz;

	vec3 scotopic_luminance = xyz * (1.33 * (1.0 + (xyz.y + xyz.z) / xyz.x) - 1.68);

	float purkinje = dot(rod_response, scotopic_luminance * xyz_to_rec2020);

	rgb = mix(rgb, purkinje * purkinje_tint, exp2(-rcp(purkinje_intensity) * purkinje));

	return max0(rgb);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	// Texture fetches

	float depth0        = texelFetch(depthtex0, texel, 0).x;
	float depth1        = texelFetch(depthtex1, texel, 0).x;
	vec4 gbuffer_data_0 = texelFetch(colortex1, texel, 0);
#if defined NORMAL_MAPPING || defined SPECULAR_MAPPING
	vec4 gbuffer_data_1 = texelFetch(colortex2, texel, 0);
#endif
	vec4 blend_color    = texelFetch(colortex3, texel, 0);

	vec2 fog_uv = clamp(uv * VL_RENDER_SCALE, vec2(0.0), floor(view_res * VL_RENDER_SCALE - 1.0) * view_pixel_size);

	vec3 fog_scattering    = smooth_filter(colortex6, fog_uv).rgb;
	vec3 fog_transmittance = smooth_filter(colortex7, fog_uv).rgb;

	// Transformations

	depth0 += 0.38 * float(depth0 < hand_depth); // Hand lighting fix from Capt Tatsu

	vec3 screen_pos = vec3(uv, depth0);
	vec3 view_pos   = screen_to_view_space(screen_pos, true);
	vec3 scene_pos  = view_to_scene_space(view_pos);
	vec3 world_pos  = scene_pos + cameraPosition;

	vec3 world_dir; float view_dist;
	length_normalize(scene_pos - gbufferModelViewInverse[3].xyz, world_dir, view_dist);

	// Unpack gbuffer data

	bool is_translucent = depth0 != depth1;

	mat4x2 data = mat4x2(
		unpack_unorm_2x8(gbuffer_data_0.x),
		unpack_unorm_2x8(gbuffer_data_0.y),
		unpack_unorm_2x8(gbuffer_data_0.z),
		unpack_unorm_2x8(gbuffer_data_0.w)
	);

	vec3 albedo       = is_translucent ? blend_color.rgb : vec3(data[0], data[1].x);
	uint object_id    = uint(255.0 * data[1].y);
	vec3 flat_normal  = decode_unit_vector(data[2]);
	vec2 light_access = data[3];

	Material material;
	vec3 normal = flat_normal;

	mat3 tbn = get_tbn_matrix(flat_normal);

	// Get material

	bool is_water = object_id == 1;
	bool is_rain_particle = object_id == 253;
	bool is_snow_particle = object_id == 254;

	if (is_water) {
		material.albedo             = srgb_eotf_inv(albedo) * rec709_to_rec2020;
		material.emission           = vec3(0.0);
		material.f0                 = vec3(0.02);
		material.roughness          = 0.002;
		material.sss_amount         = 1.0;
		material.sheen_amount       = 0.0;
		material.porosity           = 0.0;
		material.is_metal           = false;
		material.is_hardcoded_metal = false;
		material.has_reflections    = true;
	} else {
		material = material_from(albedo, object_id, world_pos, light_access);

#ifdef NORMAL_MAPPING
		normal = decode_unit_vector(gbuffer_data_1.xy);
#endif

#ifdef SPECULAR_MAPPING
		vec4 specular_map = vec4(unpack_unorm_2x8(gbuffer_data_1.z), unpack_unorm_2x8(gbuffer_data_1.w));

#if defined POM && defined POM_SHADOW
		// Specular map alpha > 0.5 => inside parallax shadow
		bool parallax_shadow = specular_map.a > 0.5;
		specular_map.a -= 0.5 * float(parallax_shadow);
		specular_map.a *= 2.0;
#endif

		decode_specular_map(specular_map, material);
#endif
	}

	// Refraction

#if REFRACTION == REFRACTION_OFF
	scene_color = texelFetch(colortex0, texel, 0).rgb;
#else
	vec2 refracted_uv = uv;

#if REFRACTION == REFRACTION_WATER_ONLY
	if (is_water) {
#elif REFRACTION == REFRACTION_ALL
	if (is_translucent) {
#endif
		vec3 tangent_normal = normal * tbn;
		refracted_uv = uv + 0.5 * tangent_normal.xy * rcp(view_dist);
	}

	scene_color = texture(colortex0, refracted_uv * taau_render_scale).rgb;
	depth1      = texture(depthtex1, refracted_uv * taau_render_scale).x;

	vec3 view_back_pos = screen_to_view_space(vec3(refracted_uv, depth1), true);
#endif

	// Shade translucent layer

	if (is_translucent) {
		float nol = dot(normal, light_dir);
		float nov = clamp01(dot(normal, -world_dir));
		float lov = dot(light_dir, -world_dir);
		float halfway_norm = inversesqrt(2.0 * lov + 2.0);
		float noh = (nol + nov) * halfway_norm;
		float loh = lov * halfway_norm + halfway_norm;

		float sss_depth;
		vec3 shadows = calculate_shadows(scene_pos, flat_normal, light_access.y, material.sss_amount, sss_depth);

		vec3 translucent_color = get_diffuse_lighting(
			material,
			normal,
			flat_normal,
			shadows,
			light_access,
			material.sss_amount,
			sss_depth,
			nol,
			nov,
			noh,
			lov
		);

		translucent_color += get_specular_highlight(material, nol, nov, noh, lov, loh) * light_color * shadows;

		// Blend with background

		if (is_water) {
			float dist = (isEyeInWater == 1) ? 0.0 : distance(view_pos, view_back_pos);
			float lov = dot(world_dir, light_dir);
			float water_n = isEyeInWater == 1 ? air_n / water_n : water_n / air_n;

			mat2x3 water_fog = get_simple_water_fog(dist, lov, sss_depth, light_access.y);

			scene_color *= water_fog[1];
			scene_color += water_fog[0];
			scene_color *= 1.0 - fresnel_dielectric_n(nov, water_n);
		} else {
			vec3 tint = material.albedo;
			float alpha = blend_color.a;
			scene_color *= (1.0 - alpha) + tint * alpha;
			scene_color *= 1.0 - alpha;
		}

		scene_color += translucent_color;
	}

	// Specular reflections

#ifdef SSR
	if (material.has_reflections && depth0 < 1.0) {
		scene_color += get_specular_reflections(
			material,
			tbn,
			screen_pos,
			view_pos,
			normal,
			world_dir,
			world_dir * tbn,
			light_access.y
		);
	}
#endif

	// Apply fog to translucents

	if (is_translucent) {
		apply_fog(scene_color, scene_pos, world_dir, false);
	}

	// Apply volumetric lighting

#ifdef VL
	scene_color = scene_color * fog_transmittance + fog_scattering;
#endif

	// Purkinje shift

#ifdef PURKINJE_SHIFT
	light_access = (depth0 == 1.0) ? vec2(0.0, 1.0) : light_access;

	float purkinje_intensity  = 0.066 * PURKINJE_SHIFT_INTENSITY;
	      purkinje_intensity *= 1.0 - smoothstep(-0.12, -0.06, sun_dir.y) * light_access.y;
		  purkinje_intensity *= 0.1 + 0.9 * light_access.y;
	      purkinje_intensity *= clamp01(1.0 - light_access.x);

	scene_color = purkinje_shift(scene_color, purkinje_intensity);
#endif

	// Calculate bloomy fog amount

#ifdef BLOOMY_FOG
	#ifdef VL
	bloomy_fog = clamp01(dot(fog_transmittance, vec3(0.33)));
	#else
	bloomy_fog = 1.0;
	#endif

	#ifdef CAVE_FOG
	bloomy_fog *= spherical_fog(view_dist, 0.0, 0.005 * biome_cave * float(depth0 != 1.0));
	#endif
#endif

}
