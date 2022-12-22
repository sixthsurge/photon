#include "/include/global.glsl"

/* DRAWBUFFERS:0 */
layout (location = 0) out vec3 shadowcolor0_out;

in vec2 uv;

flat in uint object_id;
flat in vec3 tint;
flat in mat3 tbn;

uniform sampler2D tex;

#include "/include/aces/matrices.glsl"

#include "/include/utility/color.glsl"

void main() {
#ifdef SHADOW_COLOR
	if (object_id == 2) { // Water
		shadowcolor0_out = vec3(1.0);
	} else {
		vec4 base_color = textureLod(tex, uv, 0);
		if (base_color.a < 0.1) discard;

		shadowcolor0_out  = mix(vec3(1.0), base_color.rgb * tint, base_color.a);
		shadowcolor0_out  = 0.25 * srgb_transfer_function_inverse(shadowcolor0_out) * rec709_to_rec2020;
		shadowcolor0_out *= step(base_color.a, 1.0 - rcp(255.0));
	}
#else
	if (texture(tex, uv).a < 0.1) discard;
#endif
}
