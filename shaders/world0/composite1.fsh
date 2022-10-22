#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/composite1.fsh:


--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:0 */
layout (location = 0) out vec3 fragColor;

in vec2 uv;

uniform sampler2D colortex0; // Scene color
uniform sampler2D colortex3; // Vol. fog transmittance
uniform sampler2D colortex5; // Vol. fog scattering

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	fragColor = texelFetch(colortex0, texel, 0).rgb;

	vec3 fogScattering = texture(colortex5, 0.5 * uv).rgb;
	vec3 fogTransmittance = texture(colortex3, 0.5 * uv).rgb;

	fragColor = fragColor * fogTransmittance + fogScattering;
}
