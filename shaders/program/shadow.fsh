#include "/include/global.glsl"

//--// Outputs //-------------------------------------------------------------//

layout (location = 0) out vec3 shadowcolor0Out;

//--// Inputs //--------------------------------------------------------------//

in vec2 texCoord;
in vec3 worldPos;

flat in uint blockId;
flat in vec3 normal;
flat in vec4 tint;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D tex;
uniform sampler2D noisetex;

//--// Camera uniforms

uniform float near;
uniform float far;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Time uniforms

uniform float frameTimeCounter;

//--// Custom uniforms

uniform vec2 taaOffset;

uniform vec3 lightDir;

//--// Includes //-----------------------------------------------------------//

#include "/block.properties"

#include "/include/fragment/aces/matrices.glsl"
#include "/include/fragment/waterNormal.glsl"

#include "/include/utility/color.glsl"

//--// Functions //----------------------------------------------------------//

const float airN   = 1.000293; // for 0°C and 1 atm
const float waterN = 1.333;    // for 20°C

// using the built-in GLSL refract() seems to cause NaNs on Intel drivers, but this with this
// function, which does the exact same thing, is fine
vec3 refractSafe(vec3 I, vec3 N, float eta) {
	float NoI = dot(N, I);
	float k = 1.0 - eta * eta * (1.0 - NoI * NoI);
	if (k < 0.0) {
		return vec3(0.0);
	} else {
		return eta * I - (eta * NoI + sqrt(k)) * N;
	}
}

// https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
float getWaterCaustics(vec3 worldPos, vec3 geometryNormal) {
	const float distanceTraveled = 2.0; // distance for which caustics are calculated

	mat3 tbnMatrix = getTbnMatrix(geometryNormal);
	vec3 normal = tbnMatrix * getWaterNormal(geometryNormal, worldPos);

	vec3 oldPos = worldPos;
	vec3 newPos = worldPos + refractSafe(lightDir, normal, airN / waterN) * distanceTraveled;

	float oldArea = lengthSquared(dFdx(oldPos)) * lengthSquared(dFdy(oldPos));
	float newArea = lengthSquared(dFdx(newPos)) * lengthSquared(dFdy(newPos));

	if (oldArea == 0.0 || newArea == 0.0) return 1.0;

	return inversesqrt(oldArea * rcp(newArea));
}

void main() {
	if (blockId == BLOCK_WATER) { // Water
		shadowcolor0Out.x = 1.0; // Red value of 1.0 signifies water
		shadowcolor0Out.y = getWaterCaustics(worldPos, normal);
	} else {
		vec4 baseTex = texture(tex, texCoord) * tint;
		if (baseTex.a < 0.1) discard;

		shadowcolor0Out = mix(vec3(1.0), baseTex.rgb, baseTex.a);
		shadowcolor0Out = srgbToLinear(shadowcolor0Out) * r709ToAp1Unlit;
		shadowcolor0Out.x = shadowcolor0Out.x == 1.0 ? 254.0 / 255.0 : shadowcolor0Out.x;
	}
}
