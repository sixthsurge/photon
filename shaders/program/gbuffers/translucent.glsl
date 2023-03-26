/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffers/translucent.glsl:
  Handle translucent terrain, translucent entities (Iris), translucent handheld
  items and gbuffers_textured

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

varying vec2 uv;
varying vec2 light_levels;

flat varying uint material_mask;
flat varying vec4 tint;
flat varying mat3 tbn;

#if defined PROGRAM_GBUFFERS_WATER
varying vec2 atlas_tile_coord;
varying vec3 tangent_pos;
flat varying vec2 atlas_tile_offset;
flat varying vec2 atlas_tile_scale;
#endif

// ------------
//   uniforms
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
uniform vec4 entityColor;
#endif


//----------------------------------------------------------------------------//
#if defined STAGE_VERTEX

attribute vec4 at_tangent;
attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;

#include "/include/utility/space_conversion.glsl"

float gerstner_wave(vec2 coord, vec2 wave_dir, float t, float noise, float wavelength) {
	// Gerstner wave function from Belmu in #snippets, modified
	const float g = 9.8;

	float k = tau / wavelength;
	float w = sqrt(g * k);

	float x = w * t - k * (dot(wave_dir, coord) + noise);

	return sqr(sin(x) * 0.5 + 0.5);
}

vec3 apply_water_displacement(vec3 view_pos) {
	const float wave_frequency = 0.3 * WATER_WAVE_FREQUENCY;
	const float wave_speed     = 0.37 * WATER_WAVE_SPEED_STILL;
	const float wave_angle     = 0.5;
	const float wavelength     = 1.0;
	const vec2  wave_dir       = vec2(cos(wave_angle), sin(wave_angle));

	if (material_mask != 1) return view_pos;

	vec3 scene_pos = view_to_scene_space(view_pos);

	vec2 wave_coord = (scene_pos.xz + cameraPosition.xz) * wave_frequency;

	scene_pos.y += gerstner_wave(wave_coord, wave_dir, frameTimeCounter * wave_speed, 0.0, wavelength) * 0.05 - 0.025;

	return scene_to_view_space(scene_pos);
}

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

	tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
	tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
	tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);

	vec3 view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);
#ifdef WATER_DISPLACEMENT
	     view_pos = apply_water_displacement(view_pos);
#endif

	vec4 clip_pos = project(gl_ProjectionMatrix, view_pos);

#if defined PROGRAM_GBUFFERS_WATER
	tint.a = 1.0;

	tangent_pos = transform(gbufferModelViewInverse, view_pos) * tbn;

	// from fayer3
	vec2 uv_minus_mid = uv - mc_midTexCoord;
	atlas_tile_offset = min(uv, mc_midTexCoord - uv_minus_mid);
	atlas_tile_scale = abs(uv_minus_mid) * 2.0;
	atlas_tile_coord = sign(uv_minus_mid) * 0.5 + 0.5;
#endif

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
#if defined STAGE_FRAGMENT

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

#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/encoding.glsl"

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

	bool is_water = material_mask == 1;
	bool is_nether_portal = material_mask == 251;

	if (is_water) { // Water
#ifdef VANILLA_WATER_TEXTURE
		base_color = texture(gtexture, uv, lod_bias);
#else
		base_color = vec4(0.0);
#endif
#if defined PROGRAM_GBUFFERS_WATER && defined FANCY_NETHER_PORTAL
	} else if (is_nether_portal) {
		base_color = draw_nether_portal();
#endif
	} else {
		base_color        = texture(gtexture, uv, lod_bias) * tint;
#ifdef SPECULAR_MAPPING
		vec4 specular_map = texture(specular, uv, lod_bias);
#endif

#ifdef NORMAL_MAPPING
		vec3 normal_map   = texture(normals, uv, lod_bias).xyz;

		vec3 normal; float ao;
		decode_normal_map(normal_map, normal, ao);
		normal = tbn * normal;

		gbuffer_data_1.xy = encode_unit_vector(normal);
#endif

#ifdef SPECULAR_MAPPING
		gbuffer_data_1.z  = pack_unorm_2x8(specular_map.xy);
		gbuffer_data_1.w  = pack_unorm_2x8(specular_map.zw);
#endif

		if (base_color.a < 0.1) discard;
	}

#ifdef PROGRAM_GBUFFERS_ENTITIES_TRANSLUCENT
	base_color.rgb = mix(base_color.rgb, entityColor.rgb, entityColor.a);
#endif

	float dither = interleaved_gradient_noise(gl_FragCoord.xy, frameCounter);

	gbuffer_data_0.x  = pack_unorm_2x8(base_color.rg);
	gbuffer_data_0.y  = pack_unorm_2x8(base_color.b, float(material_mask) * rcp(255.0));
	gbuffer_data_0.z  = pack_unorm_2x8(encode_unit_vector(tbn[2]));
	gbuffer_data_0.w  = pack_unorm_2x8(dither_8bit(light_levels, dither));

#ifdef VANILLA_WATER_TEXTURE
	if (is_water) base_color = vec4(0.0);
#endif

#ifdef PROGRAM_GBUFFERS_TEXTURED
	// Kill the little rain splash particles
	if (base_color.r < 0.29 && base_color.g < 0.45 && base_color.b > 0.75) discard;
#endif
}

#endif
//----------------------------------------------------------------------------//
