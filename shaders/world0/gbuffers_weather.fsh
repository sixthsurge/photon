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

#ifdef MC_NORMAL_MAP
uniform sampler2D normals;
#endif

#ifdef MC_SPECULAR_MAP
uniform sampler2D specular;
#endif

uniform vec4 entityColor;

//--// Time uniforms

uniform int frameCounter;

//--// Custom uniforms

uniform vec2 viewTexelSize;

//--// Includes //------------------------------------------------------------//

#include "/block.properties"
#include "/entity.properties"

#include "/include/fragment/textureFormat.glsl"

#include "/include/utility/dithering.glsl"
#include "/include/utility/encoding.glsl"

//--// Program //-------------------------------------------------------------//

const float lodBias = log2(renderScale);
const float rainId  = 253.0;
const float snowId  = 254.0;

void main() {
#if TAA_UPSCALING_FACTOR > 1
	vec2 coord = gl_FragCoord.xy * viewTexelSize;
	if (clamp01(coord) != coord) discard;
#endif

	fragColor  = texture(gtexture, uv, lodBias);
	fragColor *= tint;

	bool isSnow = abs(fragColor.r - fragColor.b) < eps;

	if (fragColor.a < 0.102) discard;

	mat2x4 data;
	data[0].xyz = fragColor.rgb;
	data[0].w   = (isSnow ? snowId : rainId) * rcp(255.0);
	data[1].xy  = encodeUnitVector(vec3(0.0, 1.0, 0.0));
	data[1].zw  = vec2(1.0);

	encoded.x = packUnorm4x8(data[0]);
	encoded.y = packUnorm4x8(data[1]);
}
