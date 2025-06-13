/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_skytextured:
  Handle vanilla sun and moon and custom skies

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 frag_color;

/* RENDERTARGETS: 0 */

in vec2 uv;
in vec3 view_pos;

flat in vec3 tint;
flat in vec3 sun_color;
flat in vec3 moon_color;

// ------------
//   Uniforms
// ------------

uniform sampler2D gtexture;
uniform sampler2D noisetex;

uniform int moonPhase;
uniform int renderStage;

uniform vec3 view_sun_dir;

#include "/include/sky/atmosphere.glsl"
#include "/include/utility/color.glsl"

const float vanilla_sun_luminance = 10.0; 
const float moon_luminance = 10.0; 

void main() {
	vec2 new_uv = uv;
	vec2 offset;

	if (renderStage == MC_RENDER_STAGE_CUSTOM_SKY) {
#ifdef CUSTOM_SKY
		frag_color  = texture(gtexture, new_uv).rgb;
		frag_color  = srgb_eotf_inv(frag_color) * rec709_to_working_color;
		frag_color *= CUSTOM_SKY_BRIGHTNESS;
#else
		frag_color  = vec3(0.0);
#endif
	} else if (dot(view_pos, view_sun_dir) > 0.0) {
		// Sun

		// NB: not using renderStage to distinguish sun and moon because it's broken in Iris for 
		// Minecraft 1.21.4

		// Cut out the sun itself (discard the halo around it)
		if (max_of(abs(offset)) > 0.25) discard;
		offset = uv * 2.0 - 1.0;

#ifdef VANILLA_SUN
		frag_color  = texture(gtexture, new_uv).rgb;
		frag_color  = srgb_eotf_inv(frag_color) * rec709_to_working_color;
		frag_color *= dot(frag_color, luminance_weights) * (sunlight_color * vanilla_sun_luminance) * sun_color;
#else 
		frag_color  = vec3(0.0);
#endif
	} else {
	 	// Moon
#ifdef VANILLA_MOON
		// Cut out the moon itself (discard the halo around it) and flip moon texture along the
		// diagonal
		offset = fract(vec2(4.0, 2.0) * uv);
		new_uv = new_uv + vec2(0.25, 0.5) * ((1.0 - offset.yx) - offset);
		offset = offset * 2.0 - 1.0;
		if (max_of(abs(offset)) > 0.25) discard;

		frag_color = texture(gtexture, new_uv).rgb * vec3(MOON_R, MOON_G, MOON_B);
#else
		// Shader moon
		const float angle      = 0.7;
		const mat2  rot        = mat2(cos(angle), sin(angle), -sin(angle), cos(angle));

		const vec3  lit_color  = vec3(MOON_R, MOON_G <= 0.03 ? 0.0 : MOON_G - 0.03, MOON_B);
		const vec3  glow_color = vec3(MOON_R <= 0.05 ? 0.0 : MOON_R - 0.05, MOON_G, MOON_B);

		offset = ((fract(vec2(4.0, 2.0) * uv) - 0.5) * rcp(0.15)) / MOON_ANGULAR_RADIUS;
		offset = rot * offset;

		float dist = length(offset);
		float moon_shadow = 1.0;
		float a = sqrt(1.0 - offset.x * offset.x);

		vec3 noise = texture(noisetex, 0.93 * fract(vec2(4.0, 2.0) * uv)).xyz;
		float moon_texture = pow1d5(noise.x) * 0.75 + 0.6 * cube(noise.y) - 0.1 * noise.z;

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

		frag_color = max(
			moon_shadow * lit_color,
			0.5 * glow_color * (0.2 + 0.1 * pulse(dist, 0.95, 0.3)) // Moon glow
		) * (0.25 + 0.75 * moon_texture);

		if (dist > 1.0) {
			discard;
		}
#endif

		frag_color  = srgb_eotf_inv(frag_color) * rec709_to_working_color;
		frag_color *= sunlight_color * moon_luminance;
	}	
}

