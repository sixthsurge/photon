#if !defined INCLUDE_ATMOSPHERE_WEATHER
#define INCLUDE_ATMOSPHERE_WEATHER

#include "/include/utility/fastMath.glsl"
#include "/include/utility/random.glsl"

const vec3 weatherBias = vec3(WEATHER_TEMPERATURE_BIAS, WEATHER_HUMIDITY_BIAS, WEATHER_WIND_STRENGTH_BIAS);

// One dimensional value noise
float noise1D(float x) {
	float i, f = modf(x, i);
	f = cubicSmooth(f);
	return hash1(R1(int(i))) * (1.0 - f) + hash1(R1(int(i + 1.0))) * f;
}

vec3 getWeather() {
#ifndef DYNAMIC_WEATHER
	return vec3(0.5) + weatherBias;
#else
	const float dailyTemperatureMin    = 0.0;
	const float dailyTemperatureMax    = 1.0;
	const float dailyHumidityMin       = 0.3;
	const float dailyHumidityMax       = 0.8;
	const float biomeTemperatureWeight = 0.1;
	const float biomeHumidityWeight    = 0.1;

	float weatherTime  = WEATHER_VARIATION_SPEED * (float(worldDay) + rcp(24000.0) * float(worldTime));

	// Daily weather
	float temperature  = noise1D(rcp(goldenRatio) * weatherTime);
	      temperature  = mix(dailyTemperatureMin, dailyTemperatureMax, temperature);
	float humidity     = noise1D(rcp(goldenRatio) * weatherTime + 13.4625);
	      humidity     = mix(dailyHumidityMin, dailyHumidityMax, humidity);
	float windStrength = noise1D(rcp(goldenRatio) * weatherTime + 29.7333);

	// Time-of-day effects
	temperature -= 0.33 * timeSunrise + 0.2 * timeMidnight;
	humidity    -= 0.08 * timeSunset;

	// Biome effects
	temperature += biomeTemperature * biomeTemperatureWeight;
	humidity    += biomeHumidity * biomeHumidityWeight;

	// In-game weather effects
	humidity    += wetness;
	windStrength = 0.6 * windStrength + 0.4 * rainStrength;

	return clamp01(vec3(temperature, humidity, windStrength) + weatherBias);
#endif
}

/* -- clouds -- */

// layer 0 (cumulus, cumulus humilis, stratocumulus, stratus)

// higher humidity -> higher coverage
// very high temperature -> lower coverage
vec2 cloudsLayer0Coverage(vec3 weather) {
	const vec2 localVariation = vec2(-0.2, 0.16);

	float temperatureWeight = 1.0 + 0.4 * (1.0 - linearStep(0.0, 0.21, weather.x));
	float humidityWeight    = 0.2 + 0.8 * sqrt(max0(weather.y));
	float weatherWeight     = 1.0 + 0.15 * wetness;

	float coverage = temperatureWeight * humidityWeight * weatherWeight;
	      coverage = mix(0.5, coverage, CLOUDS_LAYER0_WEATHER_INFLUENCE) * CLOUDS_LAYER0_COVERAGE;

	return coverage + localVariation;
}

// lower temperature -> stratus
// higher temperature + medium-low humidity -> cumulus humilis
vec4 cloudsLayer0CloudType(vec3 weather) {
	const vec2 localVariationSt    = vec2(-0.2, 0.2);
	const vec2 localVariationCuHum = vec2(-0.2, 0.2);
	const vec4 userSetting         = vec4(vec2(CLOUDS_LAYER0_STRATUS_AMOUNT), vec2(CLOUDS_LAYER0_CUMULUS_HUMILIS_AMOUNT)) * 2.0 - 1.0;

	float st = 1.0 - sqr(linearStep(0.0, 0.5, weather.x));
	float cuHum = linearStep(0.65, 0.8, weather.x) * (1.0 - linearStep(0.9, 1.0, weather.y));

	return clamp01(vec4(st + localVariationSt, cuHum + localVariationCuHum) * (1.0 - CLOUDS_LAYER0_WEATHER_INFLUENCE) + userSetting);
}

// allow light to travel further through the cloud when the sun is close to the horizon
float cloudsLayer0Density(vec3 weather) {
	const float cloudsExtinctionCoeff = 0.115;
	return (CLOUDS_LAYER0_DENSITY * cloudsExtinctionCoeff) * (0.5 + 0.5 * abs(lightDir.y));
}

// layer 1 (altocumulus, altostratus)

// high humidity -> high coverage
// medium-high temperature -> high coverage
vec2 cloudsLayer1Coverage(vec3 weather) {
	const vec2 localVariation = vec2(-0.08, 0.08);

	float temperatureWeight = 0.4 + 0.6 * linearStep(0.4, 0.63, weather.x) * (1.0 - 0.25 * linearStep(0.81, 1.0, weather.x));
	float humidityWeight    = linearStep(0.4, 0.6, weather.y);
	float weatherWeight     = 1.0 + 0.2 * wetness;

	float coverage = temperatureWeight * humidityWeight * weatherWeight;
	      coverage = mix(0.5, coverage, CLOUDS_LAYER1_WEATHER_INFLUENCE) * CLOUDS_LAYER1_COVERAGE;

	return coverage + localVariation;
}

vec4 cloudsLayer1CloudType(vec3 weather) {
	return vec4(0.0);
}

// planar clouds

// higher humidity -> higher coverage
// lower temperature -> higher coverage
float cloudsCirrusCoverage(vec3 weather) {
	float temperatureWeight = 0.6 + 0.4 * sqr(linearStep(0.5, 0.9, weather.x))
	                        + 0.4 * (1.0 - linearStep(0.0, 0.2, weather.x));
	float humidityWeight    = 1.0 - 0.33 * linearStep(0.5, 0.75, weather.y);

	return temperatureWeight * humidityWeight;
}

// higher temperature -> higher coverage
// higher humidity -> higher coverage
float cloudsCirrocumulusCoverage(vec3 weather) {
	float temperatureWeight = 0.4 + 0.6 * linearStep(0.5, 0.8, weather.x);
	float humidityWeight    = linearStep(0.4, 0.6, weather.y);
	float weatherWeight     = 1.0 + 0.2 * wetness;

	return temperatureWeight * humidityWeight * weatherWeight;
}

/* -- fog -- */

/* -- puddles -- */

float getRippleHeightmap(sampler2D noiseSampler, vec2 coord) {
	const float rippleFrequency = 0.3;
	const float rippleSpeed     = 0.1;
	const vec2 rippleDir0       = vec2( 3.0,   4.0) / 5.0;
	const vec2 rippleDir1       = vec2(-5.0, -12.0) / 13.0;

	float rippleNoise1 = texture(noiseSampler, coord * rippleFrequency + frameTimeCounter * rippleSpeed * rippleDir0).y;
	float rippleNoise2 = texture(noiseSampler, coord * rippleFrequency + frameTimeCounter * rippleSpeed * rippleDir1).y;

	return mix(rippleNoise1, rippleNoise2, 0.5);
}

void getRainPuddles(
	sampler2D noiseSampler,
	float porosity,
	vec2 lmCoord,
	vec3 positionWorld,
	vec3 geometryNormal,
	inout vec3 normal,
	inout vec3 albedo,
	inout vec3 f0,
	inout float roughness
) {
	const float puddleFrequency             = 0.025;
	const float puddleF0                    = 0.02;
	const float puddleRoughness             = 0.002;
	const float puddleDarkeningFactor       = 0.2;
	const float puddleDarkeningFactorPorous = 0.4;

#ifndef RAIN_PUDDLES
	return;
#endif

	if (wetness < 0.0 || biomeMayRain < 0.0) return;

	float puddle = texture(noiseSampler, positionWorld.xz * puddleFrequency).w;
	      puddle = linearStep(0.45, 0.55, puddle) * wetness * biomeMayRain * max0(geometryNormal.y);

	// prevent puddles from appearing indoors
	puddle *= (1.0 - cube(lmCoord.x)) * pow5(lmCoord.y);

	if (puddle < eps) return;

	albedo   *= 1.0 - puddleDarkeningFactorPorous * porosity * puddle;
	puddle   *= 1.0 - porosity;

	albedo   *= 1.0 - puddleDarkeningFactor * puddle;
	f0        = max(f0, mix(f0, vec3(puddleF0), puddle));
	roughness = min(roughness, mix(roughness, puddleRoughness, puddle));

	const float h = 0.1;
	float ripple0 = getRippleHeightmap(noiseSampler, positionWorld.xz);
	float ripple1 = getRippleHeightmap(noiseSampler, positionWorld.xz + vec2(h, 0.0));
	float ripple2 = getRippleHeightmap(noiseSampler, positionWorld.xz + vec2(0.0, h));

	vec3 rippleNormal     = vec3(ripple1 - ripple0, ripple2 - ripple0, h);
	     rippleNormal.xy *= 0.05 * smoothstep(0.0, 0.1, abs(dot(geometryNormal, normalize(positionWorld - cameraPosition))));
	     rippleNormal     = normalize(rippleNormal);
		 rippleNormal     = rippleNormal.xzy; // convert to world space

	normal = mix(normal, geometryNormal, puddle);
	normal = mix(normal, rippleNormal, puddle * rainStrength);
	normal = normalizeSafe(normal);
}

#endif // INCLUDE_ATMOSPHERE_WEATHER
