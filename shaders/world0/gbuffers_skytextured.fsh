#version 400 compatibility
#include "/include/global.glsl"

/* DRAWBUFFERS:3 */
layout (location = 0) out vec4 scene_color;

in vec2 uv;

flat in vec3 tint;

#if MC_VERSION < 11700
	#define gtexture gcolor
#endif

uniform sampler2D gtexture;

uniform int renderStage;

void main() {
	vec2 new_uv = uv;
	vec2 offset;

	switch (renderStage) {
#ifdef VANILLA_SUN
	case MC_RENDER_STAGE_SUN:
	 	// alpha of 2 <=> sun
		scene_color.a = 2.0 / 255.0;

		// Cut out the sun itself (discard the halo around it)
		offset = uv * 2.0 - 1.0;
		if (max_of(abs(offset)) > 0.25) discard;

		break;
#endif

#ifdef VANILLA_MOON
	case MC_RENDER_STAGE_MOON:
	 	// alpha of 3 <=> moon
		scene_color.a = 3.0 / 255.0;

		// Cut out the moon itself (discard the halo around it) and flip moon texture along the
		// diagonal
		offset = fract(vec2(4.0, 2.0) * uv);
		new_uv = new_uv + vec2(0.25, 0.5) * ((1.0 - offset.yx) - offset);
		offset = offset * 2.0 - 1.0;
		if (max_of(abs(offset)) > 0.25) discard;

		break;
#endif

	case MC_RENDER_STAGE_CUSTOM_SKY:
	 	// alpha of 4 <=> custom sky
		scene_color.a = 4.0 / 255.0;
		break;

	default:
		discard;
	}

	scene_color.rgb = texture(gtexture, new_uv).rgb;
}
