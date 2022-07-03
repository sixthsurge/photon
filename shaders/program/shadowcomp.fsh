/*
 * Program description:
 * Prepare shadowcolor0 for colored shadows, calculate projected caustics
 */

#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

layout (location = 0) out vec3 shadowcolor0Out;

//--// Inputs //--------------------------------------------------------------//

in vec2 coord;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D noisetex;

uniform sampler2D shadowcolor0;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

//--// Camera uniforms

uniform float near;
uniform float far;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Shadow uniforms

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

//--// Time uniforms

uniform float frameTimeCounter;

//--// Custom uniforms

uniform vec2 taaOffset;

uniform vec3 lightDir;

//--// Includes //------------------------------------------------------------//

#include "/include/fragment/waterNormal.glsl"
#include "/include/fragment/waterVolume.glsl"

#include "/include/lighting/shadowDistortion.glsl"

#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"

//--// Program //-------------------------------------------------------------//

const float airN   = 1.000293; // for 0°C and 1 atm
const float waterN = 1.333;    // for 20°C

// https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
float getWaterCaustics(vec3 scenePos, vec3 geometryNormal, float distanceTraveled) {
	mat3 tbnMatrix = getTbnMatrix(geometryNormal);
	vec3 normal = tbnMatrix * getWaterNormal(geometryNormal, scenePos + cameraPosition);

	vec3 oldPos = scenePos;
	vec3 newPos = scenePos + refract(lightDir, normal, airN / waterN) * distanceTraveled;

	float oldArea = lengthSquared(dFdx(oldPos)) * lengthSquared(dFdy(oldPos));
	float newArea = lengthSquared(dFdx(newPos)) * lengthSquared(dFdy(newPos));

	if (oldArea == 0.0 || newArea == 0.0) return 1.0;

	return inversesqrt(oldArea * rcp(newArea));
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	float frontDepth = texelFetch(shadowtex0, texel, 0).x;
	float backDepth  = texelFetch(shadowtex1, texel, 0).x;

	if (backDepth <= frontDepth + 5e-4) { shadowcolor0Out = vec3(1.0); return; } // Solid

	vec3 data = texelFetch(shadowcolor0, texel, 0).xyz;

	if (data.x == 1.0) {
		// Water
		vec3 shadowViewPos0 = vec3(coord, frontDepth) * 2.0 - 1.0;
		     shadowViewPos0 = undistortShadowSpace(shadowViewPos0);
			 shadowViewPos0 = projectOrtho(shadowProjectionInverse, shadowViewPos0);

		vec3 shadowViewPos1 = vec3(coord, backDepth) * 2.0 - 1.0;
		     shadowViewPos1 = undistortShadowSpace(shadowViewPos1);
			 shadowViewPos1 = projectOrtho(shadowProjectionInverse, shadowViewPos1);

		float distanceTraveled = distance(shadowViewPos0, shadowViewPos1); // distance traveled through the volume

		vec3 scenePos = transform(shadowModelViewInverse, shadowViewPos1);
		vec3 geometryNormal = decodeUnitVector(data.yz);

		shadowcolor0Out = getWaterCaustics(scenePos, geometryNormal, distanceTraveled) * exp(-waterExtinctionCoeff * distanceTraveled);
	} else {
		// Translucents
		shadowcolor0Out = data;
	}
}
