#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

/* RENDERTARGETS: 1 */
layout (location = 0) out uvec4 encoded;

#ifdef GBUFFERS_ENTITIES
/* RENDERTARGETS: 1,2 */
layout (location = 1) out vec3 velocityOut;
#endif

//--// Inputs //--------------------------------------------------------------//

in vec2 texCoord;
in vec2 lmCoord;
in vec4 tint;

flat in uint blockId;
flat in mat3 tbnMatrix;

#if defined GBUFFERS_ENTITIES
in vec3 velocity;
#endif

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

#ifdef GBUFFERS_ENTITIES
uniform vec4 entityColor;
uniform int entityId;
#endif

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

	vec4 baseTex = texture(gtexture, texCoord, lodBias);
#ifdef MC_NORMAL_MAP
	vec3 normalTex = texture(normals, texCoord, lodBias).xyz;
#endif
#ifdef MC_SPECULAR_MAP
	vec4 specularTex = texture(specular, texCoord, lodBias);
#endif

	baseTex *= tint;
#ifdef GBUFFERS_ENTITIES
	if (baseTex.a < 0.1 && entityId != ENTITY_BOAT && entityId != ENTITY_LIGHTNING_BOLT) discard;
#else
	if (baseTex.a < 0.1) discard;
#endif

#if defined GBUFFERS_ENTITIES
	baseTex.rgb = mix(baseTex.rgb, entityColor.rgb, entityColor.a);
	baseTex.rgb = mix(baseTex.rgb, vec3(1.0), float(entityId == ENTITY_LIGHTNING_BOLT));
#endif

#ifdef MC_NORMAL_MAP
	vec3 normal; float ao;
	decodeNormalTex(normalTex, normal, ao);

	normal = tbnMatrix * normal;
#endif

	float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);

	mat2x4 data;
	data[0].xyz = baseTex.rgb;
#if defined GBUFFERS_ENTITIES
	data[0].w   = float(entityId) * rcp(255.0);
#else
	data[0].w   = float(blockId) * rcp(255.0);
#endif
	data[1].xy  = encodeUnitVector(tbnMatrix[2]);
	data[1].zw  = dither8Bit(lmCoord, dither);

	encoded.x = packUnorm4x8(data[0]);
	encoded.y = packUnorm4x8(data[1]);

#ifdef MC_NORMAL_MAP
	// Pack encoded normal in first 24 bits, material AO in next 7 and parallax shadow in final bit
	vec4 normalData = vec4(encodeUnitVector(normal), ao, 1.0);
	encoded.z = packUnormArb(normalData, uvec4(12, 12, 7, 1));
#endif

#ifdef MC_SPECULAR_MAP
	encoded.w = packUnorm4x8(specularTex);
#endif

#if defined GBUFFERS_ENTITIES
	velocityOut = velocity;
#endif

#if defined GBUFFERS_BEACONBEAM
	// Discard the translucent edge part of the beam
	if (baseTex.a < 0.99) discard;
#endif
}
