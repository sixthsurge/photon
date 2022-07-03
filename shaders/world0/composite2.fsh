#version 410 compatibility

/*
 * Program description
 * Apply volumetric fog
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 3 */
layout (location = 0) out vec3 radiance;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex3; // Scene radiance
uniform sampler2D colortex6; // Fog scattering
uniform sampler2D colortex7; // Fog transmittance

//--// Program //-------------------------------------------------------------//

const float fogRenderScale = 0.01 * FOG_RENDER_SCALE;

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	vec3 fogScattering    = textureSmooth(colortex6, coord * fogRenderScale).rgb;
	vec3 fogTransmittance = textureSmooth(colortex7, coord * fogRenderScale).rgb;

	radiance = texelFetch(colortex3, texel, 0).rgb;
	radiance = radiance * fogTransmittance + fogScattering;
}
