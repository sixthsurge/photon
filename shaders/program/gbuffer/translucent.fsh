/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/translucent.fsh:
  Handle translucent terrain, translucent handheld items, water and particles

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:31 */

#ifdef NORMAL_MAPPING
/* DRAWBUFFERS:312 */
#endif

#ifdef SPECULAR_MAPPING
/* DRAWBUFFERS:312 */
#endif

layout (location = 0) out vec4 base_color;
layout (location = 1) out vec4 gbuffer_data_0; // albedo, block ID, flat normal, light levels
layout (location = 2) out vec4 gbuffer_data_1; // detailed normal, specular map (optional)

in vec2 uv;
in vec2 light_access;

flat in uint object_id;
flat in vec4 tint;
flat in mat3 tbn;

#ifdef POM
flat in vec2 atlas_tile_offset;
flat in vec2 atlas_tile_scale;
#endif

uniform sampler2D gtexture;

#ifdef NORMAL_MAPPING
uniform sampler2D normals;
#endif

#ifdef SPECULAR_MAPPING
uniform sampler2D specular;
#endif

uniform int frameCounter;

uniform vec2 view_pixel_size;

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

void main() {
#if defined TAA && defined TAAU
	vec2 uv = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(uv) != uv) discard;
#endif

	base_color         = texture(gtexture, uv, lod_bias) * tint;
#ifdef NORMAL_MAPPING
	vec3 normal_map   = texture(normals, uv, lod_bias).xyz;
#endif
#ifdef SPECULAR_MAPPING
	vec4 specular_map = texture(specular, uv, lod_bias);
#endif

	if (base_color.a < 0.1) discard;

#ifdef NORMAL_MAPPING
	vec3 normal; float ao;
	decode_normal_map(normal_map, normal, ao);

	normal = tbn * normal;
#endif

	float dither = interleaved_gradient_noise(gl_FragCoord.xy, frameCounter);

	gbuffer_data_0.x  = pack_unorm_2x8(base_color.rg);
	gbuffer_data_0.y  = pack_unorm_2x8(base_color.b, float(object_id) * rcp(255.0));
	gbuffer_data_0.z  = pack_unorm_2x8(encode_unit_vector(tbn[2]));
	gbuffer_data_0.w  = pack_unorm_2x8(dither_8bit(light_access, dither));

#ifdef NORMAL_MAPPING
	gbuffer_data_1.xy = encode_unit_vector(normal);
#endif

#ifdef SPECULAR_MAPPING
	gbuffer_data_1.z  = pack_unorm_2x8(specular_map.xy);
	gbuffer_data_1.w  = pack_unorm_2x8(specular_map.zw);
#endif

#ifdef PROGRAM_TEXTURED
	// Kill the little rain splash particles
	if (base_color.r < 0.29 && base_color.g < 0.45 && base_color.b > 0.75) discard;
#endif
 }
