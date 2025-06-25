/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_basic:
  Handle lines

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec4 scene_color;
layout (location = 1) out vec4 gbuffer_data_0; // albedo, block ID, flat normal, light levels
layout (location = 2) out vec4 gbuffer_data_1; // detailed normal, specular map (optional)

/* RENDERTARGETS: 0,1,2 */

flat in vec2 light_levels;
flat in vec4 tint;

// ------------
//   Uniforms
// ------------

uniform vec2 view_res;
uniform vec2 view_pixel_size;

uniform int renderStage;
uniform float frameTimeCounter;

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"

const vec3 normal = vec3(0.0, 1.0, 0.0);

// gbuffers_basic is abused by mods for rendering overlays and the like, for now we mostly just
// want to reduce the intensity of these translucent overlays. This shader and vanilla are still
// both affected by Z-fighting in some areas, we could attempt to fix this in the vertex
// shader but this would require mods to send correct normals for their geometry which unfortunately
// doesn't happen often.
float fixup_translucent(float alpha) {
    return mix(alpha * 0.25, alpha, step(0.9, alpha));
}

void main() {
#if defined TAA && defined TAAU
	vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
	if (clamp01(coord) != coord) discard;
#endif

	// I have yet to see anything render something transparent but we assume it can happen.
	if (tint.a < 0.1)
		discard;

	vec4 base_color = tint;
	vec2 adjusted_light_levels = light_levels;

#if defined PROGRAM_GBUFFERS_LINE && BOX_MODE != BOX_MODE_NONE
	if (renderStage == MC_RENDER_STAGE_OUTLINE) {
	#if BOX_MODE == BOX_MODE_COLOR
		base_color.rgb = vec3(BOX_COLOR_R, BOX_COLOR_G, BOX_COLOR_B);
	#else // BOX_MODE_RAINBOW
		vec2 uv = gl_FragCoord.xy * view_pixel_size;
		base_color.rgb = hsl_to_rgb(vec3(fract(uv.y + uv.x * uv.y + frameTimeCounter * 0.1), 1.0, 1.0));
	#endif

		adjusted_light_levels.x = clamp01(adjusted_light_levels.x + BOX_EMISSION);
	} 
#endif

#if defined IS_IRIS && defined USE_SEPARATE_ENTITY_DRAWS
	scene_color.rgb = srgb_eotf_inv(base_color.rgb) * rec709_to_working_color;
	// see note in function
	scene_color.a = fixup_translucent(tint.a);

	if (renderStage == MC_RENDER_STAGE_OUTLINE) {
		scene_color.rgb *= 1.0 + BOX_EMISSION;
	}
#endif

	vec2 encoded_normal = encode_unit_vector(normal);

	gbuffer_data_0.x = pack_unorm_2x8(base_color.rg);
	gbuffer_data_0.y = pack_unorm_2x8(base_color.b, 0.0);
	gbuffer_data_0.z = pack_unorm_2x8(encode_unit_vector(normal));
	gbuffer_data_0.w = pack_unorm_2x8(adjusted_light_levels);

#ifdef NORMAL_MAPPING
	gbuffer_data_1.xy = encoded_normal;
#endif

#ifdef SPECULAR_MAPPING
	const vec4 specular_map = vec4(0.0);
	gbuffer_data_1.z = pack_unorm_2x8(specular_map.xy);
	gbuffer_data_1.w = pack_unorm_2x8(specular_map.zw);
#endif
}

