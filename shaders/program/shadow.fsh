#include "/include/global.glsl"

/* DRAWBUFFERS:0 */
layout (location = 0) out vec3 shadowcolor0Out;

in vec2 uv;

flat in uint blockId;
flat in vec3 tint;
flat in mat3 tbnMatrix;

uniform sampler2D tex;

#include "/include/aces/matrices.glsl"

#include "/include/utility/color.glsl"

void main() {
#ifdef SHADOW_COLOR
	if (blockId == 2) { // Water
		shadowcolor0Out = vec3(1.0);
	} else {
		vec4 baseTex = textureLod(tex, uv, 0);
		if (baseTex.a < 0.1) discard;

		shadowcolor0Out  = mix(vec3(1.0), baseTex.rgb * tint, baseTex.a);
		shadowcolor0Out  = 0.25 * srgbToLinear(shadowcolor0Out) * rec709_to_rec2020;
		shadowcolor0Out *= step(baseTex.a, 1.0 - rcp(255.0));
	}
#else
	if (texture(tex, uv).a < 0.1) discard;
#endif
}
