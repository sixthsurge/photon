/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/gbuffer/translucent.fsh:
  Handle translucent terrain, translucent handheld items, water and particles

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:31 */

#ifdef NORMAL_MAPPING
/* DRAWBUFFERS:312 */
#endif

#ifdef SPECULAR_MAPPING
/* DRAWBUFFERS:312 */
#endif

layout (location = 0) out vec4 blendCol;
layout (location = 1) out vec4 gbuffer0; // albedo, block ID, flat normal, light levels
layout (location = 2) out vec4 gbuffer1; // detailed normal, specular map (optional)

in vec2 texCoord;
in vec2 lmCoord;

flat in uint blockId;
flat in vec4 tint;
flat in mat3 tbnMatrix;

#ifdef POM
flat in vec2 atlasTileOffset;
flat in vec2 atlasTileScale;
#endif

uniform sampler2D gtexture;

#ifdef NORMAL_MAPPING
uniform sampler2D normals;
#endif

#ifdef SPECULAR_MAPPING
uniform sampler2D specular;
#endif

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

	blendCol         = texture(gtexture, texCoord, lodBias) * tint;
#ifdef NORMAL_MAPPING
	vec3 normalTex   = texture(normals, texCoord, lodBias).xyz;
#endif
#ifdef SPECULAR_MAPPING
	vec4 specularTex = texture(specular, texCoord, lodBias);
#endif

	if (blendCol.a < 0.1) discard;

#ifdef NORMAL_MAPPING
	vec3 normal; float ao;
	decodeNormalTexture(normalTex, normal, ao);

	normal = tbnMatrix * normal;
#endif

	float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);

	gbuffer0.x  = packUnorm2x8(blendCol.rg);
	gbuffer0.y  = packUnorm2x8(blendCol.b, float(blockId) * rcp(255.0));
	gbuffer0.z  = packUnorm2x8(encodeUnitVector(tbnMatrix[2]));
	gbuffer0.w  = packUnorm2x8(dither8Bit(lmCoord, dither));

#ifdef NORMAL_MAPPING
	gbuffer1.xy = encodeUnitVector(normal);
#endif

#ifdef SPECULAR_MAPPING
	gbuffer1.z  = packUnorm2x8(specularTex.xy);
	gbuffer1.w  = packUnorm2x8(specularTex.zw);
#endif

#ifdef PROGRAM_TEXTURED
	// Kill the little rain splash particles
	if (blendCol.r < 0.29 && blendCol.g < 0.45 && blendCol.b > 0.75) discard;
#endif
 }
