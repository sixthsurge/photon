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

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform vec4 entityColor;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform vec2 viewSize;
uniform vec2 texelSize;
uniform vec2 taaOffset;

#include "/include/utility/dithering.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/random.glsl"
#include "/include/utility/spaceConversion.glsl"

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

uniform sampler2D noisetex;

#ifdef PROGRAM_BLOCK
vec3 parallaxEndPortal() {
	const int   layerCount = 8;   // number of layers
	const float depthScale = 0.3; // distance between layers
	const float depthFade  = 0.5;
	const float threshold  = 0.99;
	const vec3  color0     = pow(vec3(0.80, 0.90, 0.99), vec3(2.2));
	const vec3  color1     = pow(vec3(0.20, 0.90, 0.75), vec3(2.2));
	const vec3  color2     = pow(vec3(0.20, 0.70, 0.90), vec3(2.2));

	vec3 screenPos = vec3(gl_FragCoord.xy * texelSize * rcp(taauRenderScale), gl_FragCoord.z);
	vec3 viewPos = screenToViewSpace(screenPos, true);
	vec3 scenePos = viewToSceneSpace(viewPos);

	vec3 worldPos = scenePos + cameraPosition;
	vec3 worldDir = normalize(scenePos - gbufferModelViewInverse[3].xyz);

	vec2 tangentPos, tangentDir;
	if (abs(tbnMatrix[2].x) > 0.5) {
		tangentPos = worldPos.yz;
		tangentDir = worldDir.yz;
	} else if (abs(tbnMatrix[2].y) > 0.5) {
		tangentPos = worldPos.xz;
		tangentDir = worldDir.xz;
	} else {
		tangentPos = worldPos.xy;
		tangentDir = worldDir.xy;
	}

	vec3 portalColor = vec3(0.0);

	for (int i = 0; i < layerCount; ++i) {
		// Random layer offset
		vec2 layerOffset = R2(i) * 512.0;

		// Make layers drift over time
		float angle = i * goldenAngle;
		vec2 drift = 0.02 * vec2(cos(angle), sin(angle)) * frameTimeCounter * R1(i);

		// Snap tangentPos to 16x16 grid
		ivec2 gridPos = ivec2((tangentPos + drift) * 32.0 + layerOffset);
		uint seed = uint(80000 * gridPos.y + gridPos.x);

		vec3 random = randNextVec3(seed);

		float intensity = cube(linearStep(threshold, 1.0, random.x));

		vec3 color = mix(color0, color1, random.y);
		     color = mix(color, color2, random.z);

		float fade = exp2(-depthFade * float(i));

		portalColor += color * intensity * exp2(3.0 * (1.0 - fade) * (color - 1.0)) * fade;

		tangentPos += tangentDir * depthScale * gbufferProjection[1][1] * rcp(1.37);
	}

	return sqrt(portalColor);
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

#if defined PROGRAM_ENTITIES
	if (baseTex.a < 0.1 && blockId != 101) discard; // Save transparent quad in boats, which masks out water
#else
	if (baseTex.a < 0.1) discard;
#endif

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

#ifdef PROGRAM_BLOCK
	// Parallax end portal
	if (blockId == 250) baseTex.rgb = parallaxEndPortal();
#endif

#ifdef NORMAL_MAPPING
	vec3 normal; float ao;
	decodeNormalTexture(normalTex, normal, ao);

	normal = tbnMatrix * normal;
#endif

	float dither = interleavedGradientNoise(gl_FragCoord.xy, frameCounter);

	gbuffer0.x  = packUnorm2x8(baseTex.rg);
	gbuffer0.y  = packUnorm2x8(baseTex.b, clamp01(float(blockId) * rcp(255.0)));
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
