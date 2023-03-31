/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffers/translucent.glsl:
  Handle translucent terrain, translucent entities (Iris), translucent handheld
  items and gbuffers_textured

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


//----------------------------------------------------------------------------//
#if defined vsh

out vec2 uv;
out vec2 light_levels;
out vec4 tint;

flat out uint material_mask;
flat out mat3 tbn;

#if defined PROGRAM_GBUFFERS_WATER
out vec2 atlas_tile_coord;
out vec3 tangent_pos;
flat out vec2 atlas_tile_offset;
flat out vec2 atlas_tile_scale;
#endif

#if defined DIRECTIONAL_LIGHTMAPS
out vec3 scene_pos;
#endif

// --------------
//   Attributes
// --------------

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform ivec2 atlasSize;

uniform int frameCounter;
uniform float frameTimeCounter;
uniform float rainStrength;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform vec3 light_dir;

#if defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT
uniform int entityId;
#endif

#include "/include/utility/space_conversion.glsl"
#include "/include/vertex/displacement.glsl"

void main() {
	uv           = gl_MultiTexCoord0.xy;
	light_levels = clamp01(gl_MultiTexCoord1.xy * rcp(240.0));
	tint         = gl_Color;

#if   defined PROGRAM_GBUFFERS_WATER
	material_mask = uint(max0(mc_Entity.x - 10000.0));
#elif defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT
	material_mask = uint(max(entityId - 10000, 0));
#else
	material_mask = 0;
#endif

#if defined PROGRAM_GBUFFERS_WATER
	tint.a = 1.0;

	// from fayer3
	vec2 uv_minus_mid = uv - mc_midTexCoord;
	atlas_tile_offset = min(uv, mc_midTexCoord - uv_minus_mid);
	atlas_tile_scale = abs(uv_minus_mid) * 2.0;
	atlas_tile_coord = sign(uv_minus_mid) * 0.5 + 0.5;
#endif

	tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
	tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);

	bool is_top_vertex = uv.y < mc_midTexCoord.y;

	vec3 pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
	     pos = view_to_scene_space(pos);
	     pos = pos + cameraPosition;
	     pos = animate_vertex(pos, is_top_vertex, light_levels.y, material_mask);
		 pos = pos - cameraPosition;

#if defined DIRECTIONAL_LIGHTMAPS
	scene_pos = pos;
#endif

#if defined PROGRAM_GBUFFERS_WATER
	tangent_pos = (pos - gbufferModelViewInverse[3].xyz) * tbn;
#endif

	vec3 view_pos = scene_to_view_space(pos);
	vec4 clip_pos = project(gl_ProjectionMatrix, view_pos);

#if defined PROGRAM_GBUFFERS_TEXTURED
	// Make nether particles glow
	if (gl_Color.r > gl_Color.g && gl_Color.g < 0.6 && gl_Color.b > 0.4) material_mask = 14;
#endif

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.66;
#endif

	gl_Position = clip_pos;
}

#endif
//----------------------------------------------------------------------------//



//----------------------------------------------------------------------------//
#if defined fsh

layout (location = 0) out vec4 base_color;
layout (location = 1) out vec4 gbuffer_data_0; // albedo, block ID, flat normal, light levels
layout (location = 2) out vec4 gbuffer_data_1; // detailed normal, specular map (optional)

/* DRAWBUFFERS:31 */

#ifdef NORMAL_MAPPING
/* DRAWBUFFERS:312 */
#endif

#ifdef SPECULAR_MAPPING
/* DRAWBUFFERS:312 */
#endif

in vec2 uv;
in vec2 light_levels;
in vec4 tint;

flat in uint material_mask;
flat in mat3 tbn;

#if defined PROGRAM_GBUFFERS_WATER
in vec2 atlas_tile_coord;
in vec3 tangent_pos;
flat in vec2 atlas_tile_offset;
flat in vec2 atlas_tile_scale;
#endif

#if defined DIRECTIONAL_LIGHTMAPS
in vec3 scene_pos;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform int frameCounter;
uniform float frameTimeCounter;
uniform float rainStrength;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform vec3 light_dir;

#if defined PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT
uniform vec4 entityColor;
#endif

#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/encoding.glsl"

#if defined PROGRAM_GBUFFERS_WATER && defined POM
	#define read_tex(x) textureGrad(x, parallax_uv, uv_gradient[0], uv_gradient[1])
#else
	#define read_tex(x) texture(x, uv, lod_bias)
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
#include "/include/misc/parallax.glsl"

// Parallax nether portal effect inspired by Complementary Reimagined Shaders by EminGT
// Thanks to Emin for letting me use his idea!
vec4 draw_nether_portal() {
	const int step_count          = 20;
	const float parallax_depth    = 0.2;
	const float portal_brightness = 4.0;
	const float density_threshold = 0.6;
	const float depth_step        = rcp(float(step_count));

	float dither = interleaved_gradient_noise(gl_FragCoord.xy, frameCounter);

	vec3 tangent_dir = -normalize(tangent_pos);
	mat2 uv_gradient = mat2(dFdx(uv), dFdy(uv));

	vec3 ray_step = vec3(tangent_dir.xy * rcp(-tangent_dir.z) * parallax_depth, 1.0) * depth_step;
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

	return clamp01(result * portal_brightness * depth_step);
}
#endif

void main() {
#if defined TAA && defined TAAU
	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(coord) != coord) discard;
#endif

	float dither = interleaved_gradient_noise(gl_FragCoord.xy, frameCounter);

	vec2 adjusted_light_levels = light_levels;

	bool is_water = material_mask == 1;
	bool is_nether_portal = material_mask == 251;

	if (is_water) { //--------------------------------------------------------//
		// Water
#if defined VANILLA_WATER_TEXTURE
		base_color = texture(gtexture, uv, lod_bias);
#else
		base_color = vec4(0.0);
#endif
#if defined PROGRAM_GBUFFERS_WATER && defined FANCY_NETHER_PORTAL
	} else if (is_nether_portal) { //-----------------------------------------//
		// Nether portal
		base_color = draw_nether_portal();
#endif
	} else { //---------------------------------------------------------------//
		// Other translucent stuff
		bool parallax_shadow = false;

#if defined PROGRAM_GBUFFERS_WATER && defined POM
		float view_distance = length(tangent_pos);

		bool has_pom = view_distance < POM_DISTANCE; // Only calculate POM for close terrain
			 has_pom = has_pom && material_mask != 1 && material_mask != 8; // Do not calculate POM for water or lava

		vec3 tangent_dir = -normalize(tangent_pos);
		mat2 uv_gradient = mat2(dFdx(uv), dFdy(uv));

		vec2 parallax_uv;

		if (has_pom) {
			float pom_depth;
			vec3 shadow_trace_pos;

			parallax_uv = get_parallax_uv(tangent_dir, uv_gradient, view_distance, dither, shadow_trace_pos, pom_depth);
		} else {
			parallax_uv = uv;
			parallax_shadow = false;
		}
#endif

		base_color        = read_tex(gtexture) * tint;
#ifdef NORMAL_MAPPING
		vec3 normal_map   = read_tex(normals).xyz;
#endif
#ifdef SPECULAR_MAPPING
		vec4 specular_map = read_tex(specular);
#endif

		if (base_color.a < 0.1) { discard; return; }

#ifdef NORMAL_MAPPING
		vec3 normal; float material_ao;
		decode_normal_map(normal_map, normal, material_ao);
		normal = tbn * normal;

		gbuffer_data_1.xy = encode_unit_vector(normal);

		adjusted_light_levels *= mix(0.7, 1.0, material_ao);

	#ifdef DIRECTIONAL_LIGHTMAPS
		// Based on Ninjamike's implementation in #snippets
		vec2 lightmap_gradient; vec3 lightmap_dir;
		mat2x3 pos_gradient = mat2x3(dFdx(scene_pos), dFdy(scene_pos));

		// Blocklight

		lightmap_gradient = vec2(dFdx(light_levels.x), dFdy(light_levels.x));
		lightmap_dir = pos_gradient * lightmap_gradient;

		if (length_squared(lightmap_gradient) > 1e-12) {
			adjusted_light_levels.x *= (clamp01(dot(normalize(lightmap_dir), normal) + 0.8) * DIRECTIONAL_LIGHTMAPS_INTENSITY + (1.0 - DIRECTIONAL_LIGHTMAPS_INTENSITY)) * inversesqrt(sqrt(light_levels.x) + eps);
		}

		// Skylight

		lightmap_gradient = vec2(dFdx(light_levels.y), dFdy(light_levels.y));
		lightmap_dir = pos_gradient * lightmap_gradient;

		if (length_squared(lightmap_gradient) > 1e-12) {
			adjusted_light_levels.y *= (clamp01(dot(normalize(lightmap_dir), normal) + 0.8) * DIRECTIONAL_LIGHTMAPS_INTENSITY + (1.0 - DIRECTIONAL_LIGHTMAPS_INTENSITY)) * inversesqrt(sqrt(light_levels.y) + eps);
		}
	#endif
#endif

#ifdef SPECULAR_MAPPING
	#if defined POM && defined POM_SHADOW
		// Pack parallax shadow in alpha component of specular map
		// Specular map alpha >= 0.5 => parallax shadow
		specular_map.a *= step(specular_map.a, 0.999);
		specular_map.a  = clamp01(specular_map.a * 0.5 + 0.5 * float(parallax_shadow));
	#endif

		gbuffer_data_1.z  = pack_unorm_2x8(specular_map.xy);
		gbuffer_data_1.w  = pack_unorm_2x8(specular_map.zw);
#else
	#if defined POM && defined POM_SHADOW
		gbuffer_data_1.z  = float(parallax_shadow);
	#endif
#endif
	}

#ifdef PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT
	base_color.rgb = mix(base_color.rgb, entityColor.rgb, entityColor.a);
#endif

	vec3 color_to_store = is_water ? tint.rgb : base_color.rgb;

	gbuffer_data_0.x  = pack_unorm_2x8(color_to_store.rg);
	gbuffer_data_0.y  = pack_unorm_2x8(color_to_store.b, float(material_mask) * rcp(255.0));
	gbuffer_data_0.z  = pack_unorm_2x8(encode_unit_vector(tbn[2]));
	gbuffer_data_0.w  = pack_unorm_2x8(dither_8bit(adjusted_light_levels, dither));

#ifdef PROGRAM_GBUFFERS_TEXTURED
	// Kill the little rain splash particles
	if (base_color.r < 0.29 && base_color.g < 0.45 && base_color.b > 0.75) discard;
#endif
}

#endif
//----------------------------------------------------------------------------//
