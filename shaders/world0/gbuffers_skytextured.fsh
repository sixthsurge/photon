#version 410 compatibility
#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 0 */
layout (location = 0) out vec4 fragColor;

//--// Inputs //--------------------------------------------------------------//

in vec2 texCoord;

flat in vec3 tint;

//--// Uniforms //------------------------------------------------------------//

#if MC_VERSION < 11700
	#define gtexture gcolor
#endif

uniform sampler2D gtexture;

uniform int renderStage;

//--// Includes //------------------------------------------------------------//

#include "/include/atmospherics/atmosphere.glsl"

#include "/include/utility/color.glsl"

//--// Functions //-----------------------------------------------------------//

void main() {
	vec2 adjustedCoord = texCoord;
	vec2 offset;

	switch (renderStage) {
#ifdef VANILLA_SUN
	case MC_RENDER_STAGE_SUN:
	 	// alpha of 3 <=> sun
		fragColor.a = 3.0 / 255.0;

		// Cut out the sun itself (discard the halo around it)
		offset = texCoord * 2.0 - 1.0;
		if (maxOf(abs(offset)) > 0.25) discard;

		break;
#endif

#ifdef VANILLA_MOON
	case MC_RENDER_STAGE_MOON:
	 	// alpha of 3 <=> moon
		fragColor.a = 3.0 / 255.0;

		// Cut out the moon itself (discard the halo around it) and flip moon texture along the
		// diagonal
		offset = fract(vec2(4.0, 2.0) * texCoord);
		adjustedCoord = adjustedCoord + vec2(0.25, 0.5) * ((1.0 - offset.yx) - offset);
		offset = offset * 2.0 - 1.0;
		if (maxOf(abs(offset)) > 0.25) discard;

		break;
#endif

	case MC_RENDER_STAGE_CUSTOM_SKY:
	 	// alpha of 4 <=> custom sky
		fragColor.a = 4.0 / 255.0;
		break;

	default:
		discard;
	}

	fragColor.rgb = texture(gtexture, adjustedCoord).rgb;
}
