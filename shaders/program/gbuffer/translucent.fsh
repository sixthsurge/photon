#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 0,1 */
layout (location = 0) out vec4 fragColor;
layout (location = 1) out uvec4 encoded;

//--// Inputs //--------------------------------------------------------------//

in vec2 texCoord;
in vec2 lmCoord;
in vec4 tint;

flat in uint blockId;
flat in mat3 tbnMatrix;

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

void main() {
#if TAA_UPSCALING_FACTOR > 1
	vec2 coord = gl_FragCoord.xy * viewTexelSize;
	if (clamp01(coord) != coord) discard;
#endif

	if (blockId == BLOCK_WATER) {
		fragColor = vec4(0.0);
	} else {
		fragColor = texture(gtexture, texCoord, lodBias);

#ifdef MC_NORMAL_MAP
		vec3 normalTex = texture(normals, texCoord, lodBias).xyz;
#endif
#ifdef MC_SPECULAR_MAP
		vec4 specularTex = texture(specular, texCoord, lodBias);
#endif

		fragColor *= tint;
		if (fragColor.a < 0.102) discard;

#ifdef MC_NORMAL_MAP
		float ao; vec3 normal;
		decodeNormalTex(normalTex, normal, ao);

		normal = tbnMatrix * normal;

		// Pack encoded normal in first 24 bits, material AO in next 7 and parallax shadow in final bit
		vec4 normalData = vec4(encodeUnitVector(normal), ao, 1.0);
		encoded.z = packUnormArb(normalData, uvec4(12, 12, 7, 1));
#endif

#ifdef MC_SPECULAR_MAP
		encoded.w = packUnorm4x8(specularTex);
#endif
	}

	float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);

	mat2x4 data;
	data[0].xyz = fragColor.rgb;
	data[0].w   = float(blockId) * rcp(255.0);
	data[1].xy  = encodeUnitVector(tbnMatrix[2]);
	data[1].zw  = dither8Bit(lmCoord, dither);

	encoded.x = packUnorm4x8(data[0]);
	encoded.y = packUnorm4x8(data[1]);
}
