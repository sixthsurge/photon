#version 400 compatibility

/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  world0/deferred1.vsh:
  Get lighting colors for clouds

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec3 lightColor;
flat out vec3 skyColor;

uniform sampler3D depthtex0; // Atmospheric scattering LUT

uniform float sunAngle;

uniform int worldTime;

uniform float rainStrength;

uniform vec3 lightDir;
uniform vec3 sunDir;
uniform vec3 moonDir;

uniform float timeSunrise;
uniform float timeNoon;
uniform float timeSunset;
uniform float timeMidnight;

uniform bool cloudsMoonlit;

#define ATMOSPHERE_SCATTERING_LUT depthtex0
#define WORLD_OVERWORLD

#include "/include/atmosphere.glsl"
#include "/include/palette.glsl"

void main() {
	vec3 sunColor = getSunBrightness() * getSunTint();
	vec3 moonColor = getMoonBrightness() * getMoonTint();
	lightColor = mix(sunColor, moonColor, float(cloudsMoonlit));

	const vec3 skyDir = normalize(vec3(0.0, 1.0, -0.8)); // don't point direcly upwards to avoid the sun halo when the sun path rotation is 0
	skyColor = atmosphereScattering(skyDir, sunDir) * sunColor + atmosphereScattering(skyDir, moonDir) * moonColor;
	skyColor = tau * mix(skyColor, vec3(skyColor.b) * sqrt(2.0), rcpPi);

	vec2 vertexPos = gl_Vertex.xy * CLOUDS_RENDER_SCALE;
	gl_Position = vec4(vertexPos * 2.0 - 1.0, 0.0, 1.0);
}
