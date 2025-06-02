/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c2_dof
  Calculate depth of field

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 scene_color;

/* RENDERTARGETS: 0 */

in vec2 uv;

// ------------
//   Uniforms
// ------------

uniform sampler2D noisetex;

uniform sampler2D colortex0;

uniform sampler2D depthtex0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float near, far;

uniform float aspectRatio;
uniform float centerDepthSmooth;

uniform int frameCounter;

uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

#include "/include/misc/distant_horizons.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/sampling.glsl"
#include "/include/utility/space_conversion.glsl"

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	float depth = texelFetch(depthtex0, texel, 0).x;

#ifdef DISTANT_HORIZONS
	float depth_dh = texelFetch(dhDepthTex, texel, 0).x;

	if (is_distant_horizons_terrain(depth, depth_dh)) {
		depth = view_to_screen_space_depth(
			gbufferProjection,
			screen_to_view_space_depth(dhProjectionInverse, depth_dh)
		);
	}
#endif

	if (depth < hand_depth) {
		scene_color = texelFetch(colortex0, texel, 0).rgb;
		return;
	};

	// Calculate vogel disk rotation
	float theta  = texelFetch(noisetex, texel & 511, 0).b;
	      theta  = r1(frameCounter, theta);
	      theta *= tau;

	// Calculate circle of confusion
	float focus = DOF_FOCUS < 0.0 ? centerDepthSmooth : view_to_screen_space_depth(gbufferProjection, DOF_FOCUS);
	vec2 CoC = min(abs(depth - focus), 0.1) * (DOF_INTENSITY * 0.2 / 1.37) * vec2(1.0, aspectRatio) * gbufferProjection[1][1];

	scene_color = vec3(0.0);

	for (int i = 0; i < DOF_SAMPLES; ++i) {
		vec2 offset = vogel_disk_sample(i, DOF_SAMPLES, theta);
		scene_color += textureLod(colortex0, clamp(vec2(uv + offset * CoC), vec2(0.0), vec2(1.0 - 2.0 * view_pixel_size * rcp(taau_render_scale))) * taau_render_scale, 0).rgb;
	}

	scene_color *= rcp(DOF_SAMPLES);
}

#ifndef DOF 
	#error "This program should be disabled if Depth of Field is disabled"
#endif
