/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/solid.fsh:
  Handle terrain, entities, the hand, beacon beams and spider eyes

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:1 */

#ifdef NORMAL_MAPPING
/* DRAWBUFFERS:12 */
#endif

#ifdef SPECULAR_MAPPING
/* DRAWBUFFERS:12 */
#endif

layout (location = 0) out vec4 gbuffer0; // albedo, block ID, flat normal, light levels
layout (location = 1) out vec4 gbuffer1; // detailed normal, specular map (optional)

in vec2 texCoord;
in vec2 lmCoord;

flat in uint blockId;
flat in vec4 tint;
flat in mat3 tbnMatrix;

#ifdef POM
flat in vec2 atlasTileOffset;
flat in vec2 atlasTileScale;
#endif

#ifdef PROGRAM_TERRAIN
in float vanillaAo;
#endif

uniform sampler2D gtexture;

#ifdef NORMAL_MAPPING
uniform sampler2D normals;
#endif

#ifdef SPECULAR_MAPPING
uniform sampler2D specular;
#endif

uniform vec4 entityColor;

uniform int frameCounter;

uniform vec2 texelSize;

#include "/include/utility/dithering.glsl"
#include "/include/utility/encoding.glsl"

const float lodBias = log2(taauRenderScale);

#if   TEXTURE_FORMAT == TEXTURE_FORMAT_LAB
void decodeNormalTexture(vec3 normalTex, out vec3 normal, out float ao) {
	normal.xy = normalTex.xy * 2.0 - 1.0;
	normal.z  = sqrt(clamp01(1.0 - dot(normal.xy, normal.xy)));
	ao        = normalTex.z;
}
#elif TEXTURE_FORMAT == TEXTURE_FORMAT_OLD
void decodeNormalTexture(vec3 normalTex, out vec3 normal, out float ao) {
	normal  = normalTex * 2.0 - 1.0;
	ao      = length(normal);
	normal *= rcp(ao);
}
#endif

void main() {
#if defined TAA && defined TAAU
	vec2 uv = gl_FragCoord.xy * texelSize * rcp(taauRenderScale);
	if (clamp01(uv) != uv) discard;
#endif

	vec4 baseTex     = texture(gtexture, texCoord, lodBias) * tint;
#ifdef NORMAL_MAPPING
	vec3 normalTex   = texture(normals, texCoord, lodBias).xyz;
#endif
#ifdef SPECULAR_MAPPING
	vec4 specularTex = texture(specular, texCoord, lodBias);
#endif

	if (baseTex.a < 0.1) discard;

#ifdef WHITE_WORLD
	baseTex.rgb = vec3(1.0);
#endif

#ifdef PROGRAM_TERRAIN
	const float vanillaAoStrength = 0.65;
	const float vanillaAoLift     = 1.0;
	baseTex.rgb *= lift(vanillaAo, vanillaAoLift) * vanillaAoStrength + (1.0 - vanillaAoStrength);
#endif

#ifdef PROGRAM_ENTITIES
	baseTex.rgb = mix(baseTex.rgb, entityColor.rgb, entityColor.a);
#endif

#ifdef NORMAL_MAPPING
	vec3 normal; float ao;
	decodeNormalTexture(normalTex, normal, ao);

	normal = tbnMatrix * normal;
#endif

	float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);

	gbuffer0.x  = packUnorm2x8(baseTex.rg);
	gbuffer0.y  = packUnorm2x8(baseTex.b, float(blockId) * rcp(255.0));
	gbuffer0.z  = packUnorm2x8(encodeUnitVector(tbnMatrix[2]));
	gbuffer0.w  = packUnorm2x8(dither8Bit(lmCoord, dither));

#ifdef NORMAL_MAPPING
	gbuffer1.xy = encodeUnitVector(normal);
#endif

#ifdef SPECULAR_MAPPING
	gbuffer1.z  = packUnorm2x8(specularTex.xy);
	gbuffer1.w  = packUnorm2x8(specularTex.zw);
#endif

#if defined PROGRAM_GBUFFERS_BEACONBEAM
	// Discard the translucent edge part of the beam
	if (baseTex.a < 0.99) discard;
#endif
 }
