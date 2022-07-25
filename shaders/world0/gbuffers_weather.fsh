#version 410 compatibility
#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 0,1 */
layout (location = 0) out vec4 fragColor;
layout (location = 1) out uvec4 encoded;

//--// Inputs //--------------------------------------------------------------//

in vec2 uv;
in vec4 tint;

//--// Uniforms //------------------------------------------------------------//

#if MC_VERSION < 11700
	#define gtexture gcolor
#endif

uniform sampler2D gtexture;

uniform sampler2D colortex4; // Sky capture

//--// Time uniforms

uniform int frameCounter;

//--// Custom uniforms

uniform float eyeSkylight;

uniform vec2 viewTexelSize;

//--// Includes //------------------------------------------------------------//

#include "/block.properties"
#include "/entity.properties"

#include "/include/fragment/aces/matrices.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/encoding.glsl"

//--// Functions //-----------------------------------------------------------//

const float lodBias = log2(renderScale);
const float rainId  = 253.0;
const float snowId  = 254.0;

const vec3 rainColor = vec3(0.8, 0.9, 1.0);
const float rainOpacity = 0.15;

const float snowOpacity = 0.8;

void main() {
#if TAA_UPSCALING_FACTOR > 1
	vec2 coord = gl_FragCoord.xy * viewTexelSize;
	if (clamp01(coord) != coord) discard;
#endif

	vec4 baseTex = texture(gtexture, uv);

	if (baseTex.a < 0.1) discard;

	/* -- fetch lighting palette -- */

	vec3 directIrradiance  = texelFetch(colortex4, ivec2(255, 1), 0).rgb;
	vec3 skyIrradiance     = texelFetch(colortex4, ivec2(255, 2), 0).rgb;

	/* -- lighting -- */

	bool isSnow = abs(baseTex.r - baseTex.b) < eps;

	fragColor = isSnow ? baseTex : vec4(rainColor, rainOpacity);
	fragColor.rgb  = srgbToLinear(fragColor.rgb) * r709ToAp1 * baseTex.a;
	fragColor.rgb *= (directIrradiance + skyIrradiance) * eyeSkylight * rcpPi;

	mat2x4 data;
	data[0].xyz = vec3(0.0);
	data[0].w   = (isSnow ? snowId : rainId) * rcp(255.0);
	data[1].xy  = encodeUnitVector(vec3(0.0, 1.0, 0.0));
	data[1].zw  = vec2(1.0);

	encoded.x = packUnorm4x8(data[0]);
	encoded.y = packUnorm4x8(data[1]);
}
