#version 400 compatibility

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

//--// Functions //-----------------------------------------------------------//

const float fogRenderScale = 0.01 * FOG_RENDER_SCALE;

// Source: https://iquilezles.org/www/articles/texture/texture.htm
vec4 textureSmooth(sampler2D sampler, vec2 coord) {
	vec2 res = vec2(textureSize(sampler, 0));

	coord = coord * res + 0.5;

	vec2 i, f = modf(coord, i);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	coord = i + f;

	coord = (coord - 0.5) / res;
	return texture(sampler, coord);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	vec3 fogScattering    = textureSmooth(colortex6, coord * fogRenderScale).rgb;
	vec3 fogTransmittance = textureSmooth(colortex7, coord * fogRenderScale).rgb;

	radiance = texelFetch(colortex3, texel, 0).rgb;
	radiance = radiance * fogTransmittance + fogScattering;
}
