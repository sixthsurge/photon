/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_skytextured:
  Handle vanilla sun and moon and custom skies

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


layout (location = 0) out vec4 scene_color;

/* RENDERTARGETS: 3 */

in vec2 uv;
in vec3 view_pos;

flat in vec3 tint;

// ------------
//   Uniforms
// ------------

uniform sampler2D gtexture;

uniform int moonPhase;
uniform int renderStage;

uniform vec3 view_sun_dir;

void main() {
	vec2 new_uv = uv;
	vec2 offset;

	if (renderStage == MC_RENDER_STAGE_CUSTOM_SKY) {
	 	// Alpha of 4 <=> custom sky
		scene_color.a = 4.0 / 255.0;
		scene_color.rgb = texture(gtexture, new_uv).rgb;
	} else if (dot(view_pos, view_sun_dir) > 0.0) {
		// NB: not using renderStage to distinguish sun and moon because it's broken in Iris for 
		// Minecraft 1.21.4
		
	 	// Alpha of 2 <=> sun
		scene_color.a = 2.0 / 255.0;

		// Cut out the sun itself (discard the halo around it)
		// offset = uv * 2.0 - 1.0;
		// if (max_of(abs(offset)) > 0.25) discard;

		scene_color.rgb = texture(gtexture, new_uv).rgb;
	} else {
	 	// Alpha of 3 <=> moon
		scene_color.a = 3.0 / 255.0;

#ifdef VANILLA_MOON
		// Cut out the moon itself (discard the halo around it) and flip moon texture along the
		// diagonal
		/*
		offset = fract(vec2(4.0, 2.0) * uv);
		new_uv = new_uv + vec2(0.25, 0.5) * ((1.0 - offset.yx) - offset);
		offset = offset * 2.0 - 1.0;
		if (max_of(abs(offset)) > 0.25) discard;
		*/

		scene_color.rgb = texture(gtexture, new_uv).rgb * vec3(MOON_R, MOON_G, MOON_B);
#else
		// Shader moon
		const float angle      = 0.7;
		const mat2  rot        = mat2(cos(angle), sin(angle), -sin(angle), cos(angle));

		const vec3  lit_color  = vec3(MOON_R, MOON_G <= 0.03 ? 0.0 : MOON_G - 0.03, MOON_B);
		const vec3  glow_color = vec3(MOON_R <= 0.05 ? 0.0 : MOON_R - 0.05, MOON_G, MOON_B);

		offset = ((fract(vec2(4.0, 2.0) * uv) - 0.5) * rcp(0.15)) / MOON_ANGULAR_RADIUS;
		offset = rot * offset;

		float dist = length(offset);
		float moon = 1.0 - linear_step(0.85, 1.0, dist);
		float moon_shadow = 1.0;
		float a = sqrt(1.0 - offset.x * offset.x);

		switch (moonPhase) {
		case 0: // Full moon
			break;

		case 1: // Waning gibbous
			moon_shadow = 1.0 - linear_step(a * 0.6 - 0.12, a * 0.6 + 0.12, -offset.y); break;

		case 2: // Last quarter
			moon_shadow = 1.0 - linear_step(a * 0.1 - 0.15, a * 0.1 + 0.15, -offset.y); break;

		case 3: // Waning crescent
			moon_shadow = linear_step(a * 0.5 - 0.12, a * 0.5 + 0.12, offset.y); break;

		case 4: // New moon
			moon_shadow = 0.0; break;

		case 5: // Waxing crescent
			moon_shadow = linear_step(a * 0.6 - 0.12, a * 0.5 + 0.12, -offset.y); break;

		case 6: // First quarter
			moon_shadow = linear_step(a * 0.1 - 0.15, a * 0.1 + 0.15, -offset.y); break;

		case 7: // Waxing gibbous
			moon_shadow = 1.0 - linear_step(a * 0.6 - 0.12, a * 0.6 + 0.12, offset.y); break;
		}

		scene_color.rgb = max(
			moon * moon_shadow * lit_color,
			(0.1 * glow_color) * pulse(dist, 0.95, 0.3) // Moon glow
		);

		if (dist > 1.3) discard;
#endif
	}	
}

