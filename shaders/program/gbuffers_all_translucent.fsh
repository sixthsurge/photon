/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_all_translucent:
  Handle translucent terrain, translucent entities (Iris), translucent handheld
  items and gbuffers_textured

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

#ifdef PROGRAM_GBUFFERS_WATER
layout (location = 0) out vec4 refraction_data;
layout (location = 1) out vec4 fragment_color;

/* RENDERTARGETS: 3,13 */
#else 
layout (location = 0) out vec4 fragment_color;

/* RENDERTARGETS: 13 */
#endif

in vec2 uv;
in vec2 light_levels;
in vec3 position_view;
in vec3 position_scene;
in vec4 tint;

flat in vec3 light_color;
flat in vec3 ambient_color;
flat in uint material_mask;
flat in mat3 tbn;

#if defined PROGRAM_GBUFFERS_WATER
in vec2 atlas_tile_coord;
in vec3 position_tangent;
flat in vec2 atlas_tile_offset;
flat in vec2 atlas_tile_scale;
#endif

#if defined WORLD_OVERWORLD 
#include "/include/fog/overworld/parameters.glsl"
flat in OverworldFogParameters fog_params;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform sampler2D colortex4; // Sky map, lighting colors
uniform sampler2D colortex5; // Previous frame image (for reflections)
uniform sampler2D colortex7; // Previous frame fog scattering (for reflections)

#ifdef CLOUD_SHADOWS
uniform sampler2D colortex8; // Cloud shadow map
#endif

uniform sampler2D depthtex1;

#ifdef COLORED_LIGHTS
uniform sampler3D light_sampler_a;
uniform sampler3D light_sampler_b;
#endif

#ifdef SHADOW
#ifdef WORLD_OVERWORLD
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#endif

#ifdef WORLD_END
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;
#endif
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
uniform float rainStrength;
uniform float wetness;

uniform int worldTime;
uniform int moonPhase;
uniform int frameCounter;

uniform int isEyeInWater;
uniform float blindness;
uniform float nightVision;
uniform float darknessFactor;
uniform float eyeAltitude;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform float eye_skylight;

uniform float biome_cave;
uniform float biome_may_rain;
uniform float biome_may_snow;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#if defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT || defined PROGRAM_GBUFFERS_LIGHTNING
uniform int entityId;
uniform vec4 entityColor;
#endif

// ------------
//   Includes
// ------------

#define TEMPORAL_REPROJECTION

#ifdef SHADOW_COLOR
	#undef SHADOW_COLOR
#endif

#if defined PROGRAM_GBUFFERS_TEXTURED || defined PROGRAM_GBUFFERS_PARTICLES_TRANSLUCENT
	#define NO_NORMAL
#endif

#ifdef DIRECTIONAL_LIGHTMAPS
#include "/include/lighting/directional_lightmaps.glsl"
#endif

#include "/include/fog/simple_fog.glsl"
#include "/include/lighting/diffuse_lighting.glsl"
#include "/include/lighting/shadows/sampling.glsl"
#include "/include/lighting/specular_lighting.glsl"
#include "/include/misc/distant_horizons.glsl"
#include "/include/surface/material.glsl"
#include "/include/misc/material_masks.glsl"
#include "/include/misc/purkinje_shift.glsl"
#include "/include/surface/water_normal.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/space_conversion.glsl"

#ifdef CLOUD_SHADOWS
#include "/include/lighting/cloud_shadows.glsl"
#endif

const float lod_bias = log2(taau_render_scale);

#if   TEXTURE_FORMAT == TEXTURE_FORMAT_LAB
void decode_normal_map(vec3 normal_map, out vec3 normal, out float ao) {
	normal.xy = normal_map.xy * 2.0 - 1.0;
	normal.z  = sqrt(clamp01(1.0 - dot(normal.xy, normal.xy)));
	ao        = normal_map.z;
}
#elif TEXTURE_FORMAT == TEXTURE_FORMAT_OLD
void decode_normal_map(vec3 normal_map, out vec3 normal, out float ao) {
	normal  = normal_map * 2.0 - 1.0;
	ao      = length(normal);
	normal *= rcp(ao);
}
#endif

#if defined PROGRAM_GBUFFERS_WATER
Material get_water_material(
	vec3 direction_world,
	vec3 normal,
	float layer_dist,
	out float alpha
) {
	Material material = water_material;
	alpha = 0.01;

	// Water texture

#if WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT || WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT_UNDERGROUND
	vec4 base_color = texture(gtexture, uv, lod_bias);
	float texture_highlight  = dampen(0.5 * sqr(linear_step(0.63, 1.0, base_color.r)) + 0.03 * base_color.r);
#if WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT_UNDERGROUND
		  texture_highlight *= 1.0 - cube(linear_step(0.0, 0.5, light_levels.y));
#endif

	material.albedo     = clamp01(0.5 * exp(-2.0 * water_absorption_coeff) * texture_highlight);
	material.roughness += 0.3 * texture_highlight;
	alpha              += texture_highlight;
#elif WATER_TEXTURE == WATER_TEXTURE_VANILLA
	vec4 base_color = texture(gtexture, uv, lod_bias) * tint;
	material.albedo = srgb_eotf_inv(base_color.rgb * base_color.a) * rec709_to_working_color;
	alpha = base_color.a;
#endif

	// Water edge highlight

#ifdef WATER_EDGE_HIGHLIGHT
	float dist = layer_dist * max(abs(direction_world.y), eps);

#if WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT || WATER_TEXTURE == WATER_TEXTURE_HIGHLIGHT_UNDERGROUND
	float edge_highlight = cube(max0(1.0 - 2.0 * dist)) * (1.0 + 8.0 * texture_highlight);
#else
	float edge_highlight = cube(max0(1.0 - 2.0 * dist));
#endif
	edge_highlight *= WATER_EDGE_HIGHLIGHT_INTENSITY * max0(normal.y) * (1.0 - 0.5 * sqr(light_levels.y));;

	material.albedo += 0.1 * edge_highlight / mix(1.0, max(dot(ambient_color, luminance_weights_rec2020), 0.5), light_levels.y);
	material.albedo  = clamp01(material.albedo);
	alpha += edge_highlight;
#endif

	return material;
}

vec4 water_absorption_approx(
	vec4 color, 
	float sss_depth, 
	float layer_dist, 
	float LoV, 
	float NoV, 
	float cloud_shadows
) {
	vec3 biome_water_color = srgb_eotf_inv(tint.rgb) * rec709_to_working_color;
	vec3 absorption_coeff = biome_water_coeff(biome_water_color);
	float dist = layer_dist * float(isEyeInWater != 1 || NoV >= 0.0);

	mat2x3 water_fog = water_fog_simple(
		light_color * cloud_shadows,
		ambient_color,
		absorption_coeff,
		light_levels,
		dist,
		-LoV,
		sss_depth
	);

	float brightness_control = 1.0 - exp(-0.33 * layer_dist);
		  brightness_control = (1.0 - light_levels.y) + brightness_control * light_levels.y;

	return vec4(
		color.rgb + water_fog[0] * (1.0 + 6.0 * sqr(water_fog[1])) * brightness_control,
		1.0 - water_fog[1].x
	);
}

// Parallax nether portal effect inspired by Complementary Reimagined Shaders by EminGT
// Thanks to Emin for letting me use his idea!

vec2 get_uv_from_local_coord(vec2 local_coord) {
	return atlas_tile_offset + atlas_tile_scale * fract(local_coord);
}

vec2 get_local_coord_from_uv(vec2 uv) {
	return (uv - atlas_tile_offset) * rcp(atlas_tile_scale);
}

vec4 draw_nether_portal(vec3 direction_world, float layer_dist) {
	const int step_count          = 20;
	const float parallax_depth    = 0.2;
	const float portal_brightness = 4.0;
	const float density_threshold = 0.6;
	const float depth_step        = rcp(float(step_count));

	float dither = interleaved_gradient_noise(gl_FragCoord.xy, frameCounter);

	vec3 direction_tangent = -normalize(position_tangent);
	mat2 uv_gradient = mat2(dFdx(uv), dFdy(uv));

	vec3 ray_step = vec3(direction_tangent.xy * rcp(-direction_tangent.z) * parallax_depth, 1.0) * depth_step;
	vec3 pos = vec3(atlas_tile_coord + ray_step.xy * dither, 0.0);

	vec4 result = vec4(0.0);

	for (uint i = 0; i < step_count; ++i) {
		vec4 col = textureGrad(gtexture, get_uv_from_local_coord(pos.xy), uv_gradient[0], uv_gradient[1]);

		float density  = dot(col.rgb, luminance_weights_rec709);
		      density  = linear_step(0.0, density_threshold, density);
			  density  = max(density, 0.23);
			  density *= 1.0 - depth_step * (i + dither);

		result += col * density;

		pos += ray_step;
	}

	// Edge highlight
	float dist = layer_dist * max_of(abs(direction_world));
	float edge_highlight = cube(max0(1.0 - 2.0 * dist));
	result *= 1.0 + 2.0 * edge_highlight;

	return clamp01(result * portal_brightness * depth_step);
}

#else
vec4 draw_nether_portal(vec3 direction_world, float layer_dist) { return vec4(0.0); }
#endif

void main() {
	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);

	// Clip to TAAU viewport

#if defined TAA && defined TAAU
	if (clamp01(coord) != coord) discard;
#endif

	// Space conversions

	float depth0 = gl_FragCoord.z;
	float depth1 = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).x;

	vec3 world_pos = position_scene + cameraPosition;
	vec3 direction_world = normalize(position_scene - gbufferModelViewInverse[3].xyz);

	vec3 view_back_pos = screen_to_view_space(vec3(coord, depth1), true);

#ifdef DISTANT_HORIZONS
	float depth1_dh = texelFetch(dhDepthTex1, ivec2(gl_FragCoord.xy), 0).x;

	if (is_distant_horizons_terrain(depth1, depth1_dh)) {
		view_back_pos = screen_to_view_space(vec3(coord, depth1_dh), true, true);
	}
#endif

	vec3 scene_back_pos = view_to_scene_space(view_back_pos);

	float layer_dist = distance(position_scene, scene_back_pos); // distance to solid layer along view ray

	// Get material and normal

	Material material;
	vec3 normal = tbn[2];
	vec3 normal_tangent = vec3(0.0, 0.0, 1.0);

	bool is_water         = material_mask == MATERIAL_WATER;
	bool is_nether_portal = material_mask == MATERIAL_NETHER_PORTAL;

	vec2 adjusted_light_levels = light_levels;


#ifdef NO_NORMAL
	// No normal vector => make one from screen-space partial derivatives
	// NB: It is important to do this before the alpha discard, otherwise it creates issues on the
	// outline of things
	normal = normalize(cross(dFdx(position_scene), dFdy(position_scene)));
#endif

	//------------------------------------------------------------------------//
	if (is_water) {
#ifdef PROGRAM_GBUFFERS_WATER
		material = get_water_material(
			direction_world,
			normal,
			layer_dist,
			fragment_color.a
		);

	#ifdef WATER_WAVES
		if (abs(normal.y) > eps) {
			vec3 flat_normal = tbn[2];

		#ifdef DISTANT_HORIZONS
			mat3 tbn_fixed = tbn;
			if (normal.y > 0.99) {
				// Top surface: Use hardcoded TBN matrix pointing upwards that is the same for DH water and regular water
				tbn_fixed = mat3(
					vec3(1.0, 0.0, 0.0),
					vec3(0.0, 0.0, 1.0),
					vec3(0.0, 1.0, 0.0)
				);
			}
		#else
			#define tbn_fixed tbn
		#endif

			vec3 world_pos = position_scene + cameraPosition;

			vec2 coord = -(world_pos * tbn_fixed).xy;

			bool flowing_water = abs(flat_normal.y) < 0.99;
			vec2 flow_dir = flowing_water ? normalize(flat_normal.xz) : vec2(0.0);

		#ifdef WATER_PARALLAX
			vec3 direction_tangent = direction_world * tbn_fixed;
			coord = get_water_parallax_coord(direction_tangent, coord, flow_dir, flowing_water);
		#endif

			normal_tangent = get_water_normal(world_pos, flat_normal, coord, flow_dir, light_levels.y, flowing_water);
			normal = tbn_fixed * normal_tangent;
		}
	#endif
#endif
	//------------------------------------------------------------------------//
	} else {
		// Sample textures

		fragment_color    = texture(gtexture, uv, lod_bias) * tint;
#ifdef NORMAL_MAPPING
		vec3 normal_map   = texture(normals, uv, lod_bias).xyz;
#endif
#ifdef SPECULAR_MAPPING
		vec4 specular_map = texture(specular, uv, lod_bias);
#endif

#ifdef FANCY_NETHER_PORTAL
		if (is_nether_portal) {
			fragment_color = draw_nether_portal(direction_world, layer_dist);
		}
#endif

#if defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT
		// Lightning (old versions)
		if (material_mask == MATERIAL_LIGHTNING_BOLT) fragment_color = vec4(1.0);

		// Hit mob tint
		fragment_color.rgb = mix(fragment_color.rgb, entityColor.rgb, entityColor.a);
#endif

		if (fragment_color.a < 0.1) { discard; return; }

		material = material_from(fragment_color.rgb, material_mask, world_pos, tbn[2], adjusted_light_levels);

#if defined PROGRAM_GBUFFERS_LIGHTNING
		if (material_mask == MATERIAL_DRAGON_BEAM) {
			material.albedo *= tint.a;
		} else {
			material.albedo   = vec3(1.0);
			material.emission = vec3(1.0);
		}
#endif

		//--//

#if defined NORMAL_MAPPING && !defined NO_NORMAL
		float material_ao;
		decode_normal_map(normal_map, normal_tangent, material_ao);

		normal = tbn * normal_tangent;

		adjusted_light_levels *= mix(0.7, 1.0, material_ao);

	#ifdef DIRECTIONAL_LIGHTMAPS
		adjusted_light_levels *= get_directional_lightmaps(position_scene, normal);
	#endif
#endif

#ifdef SPECULAR_MAPPING
		decode_specular_map(specular_map, material);
#endif
	}

	// Shadows

#ifndef NO_NORMAL
	float NoL = dot(normal, light_dir);
#else
	float NoL = 1.0;
#endif
	float NoV = clamp01(dot(normal, -direction_world));
	float LoV = dot(light_dir, -direction_world);
	float halfway_norm = inversesqrt(2.0 * LoV + 2.0);
	float NoH = (NoL + NoV) * halfway_norm;
	float LoH = LoV * halfway_norm + halfway_norm;

#if defined WORLD_OVERWORLD && defined CLOUD_SHADOWS
	float cloud_shadows = get_cloud_shadows(colortex8, position_scene);
#else
	#define cloud_shadows 1.0
#endif

#if defined SHADOW && (defined WORLD_OVERWORLD || defined WORLD_END)
	float sss_depth;
	float shadow_distance_fade;
	vec3 shadows = calculate_shadows(position_scene, tbn[2], adjusted_light_levels.y, cloud_shadows, material.sss_amount, shadow_distance_fade, sss_depth);
#else
	#define sss_depth 0.0
	#define shadow_distance_fade 0.0
	vec3 shadows = vec3(pow8(adjusted_light_levels.y));
#endif

	// Diffuse lighting

	fragment_color.rgb  = get_diffuse_lighting(
		material,
		position_scene,
		normal,
		tbn[2],
		tbn[2],
		shadows,
		adjusted_light_levels,
		1.0,
		0.0,
		sss_depth,
#ifdef CLOUD_SHADOWS
		cloud_shadows,
#endif
		shadow_distance_fade,
		NoL,
		NoV,
		NoH,
		LoV
	) * fragment_color.a;

	// Specular highlight

#if (defined WORLD_OVERWORLD || defined WORLD_END) && !defined NO_NORMAL
	fragment_color.rgb += get_specular_highlight(material, NoL, NoV, NoH, LoV, LoH) * light_color * shadows * cloud_shadows;
#endif

	// Specular reflections

#if defined ENVIRONMENT_REFLECTIONS || defined SKY_REFLECTIONS
	if (material.ssr_multiplier > eps) {
		vec3 position_screen = vec3(gl_FragCoord.xy * rcp(taau_render_scale) * view_pixel_size, gl_FragCoord.z);

		mat3 new_tbn = get_tbn_matrix(normal);

		fragment_color.rgb += get_specular_reflections(
			material,
			new_tbn,
			position_screen,
			position_view,
			world_pos,
			normal,
			tbn[2],
			direction_world,
			direction_world * new_tbn,
			light_levels.y,
			is_water
		);
	}
#endif

	// Blending

#if defined PROGRAM_GBUFFERS_WATER
	if (is_water) {
		fragment_color = water_absorption_approx(
			fragment_color, 
			sss_depth, 
			layer_dist, 
			LoV, 
			dot(tbn[2], direction_world), 
			cloud_shadows
		);

	#ifdef SNELLS_WINDOW
		if (isEyeInWater == 1) {
			fragment_color.a = mix(
				fragment_color.a,
				1.0,
				fresnel_dielectric_n(NoV, air_n / water_n).x
			);
		}
	#endif
	} 
#endif 

	// Fog

	vec4 fog = common_fog(length(position_scene), false);
	fragment_color.rgb  = fragment_color.rgb * fog.a + fog.rgb;
	
	// Purkinje shift

	fragment_color.rgb = purkinje_shift(fragment_color.rgb, adjusted_light_levels);

	// Refraction data

#if defined PROGRAM_GBUFFERS_WATER
	refraction_data.xy = split_2x8(normal_tangent.x * 0.5 + 0.5);
	refraction_data.zw = split_2x8(normal_tangent.y * 0.5 + 0.5);
#endif
}
