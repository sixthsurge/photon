#if !defined INCLUDE_ATMOSPHERE_WEATHER
#define INCLUDE_ATMOSPHERE_WEATHER

#include "/include/utility/fastMath.glsl"
#include "/include/utility/random.glsl"

// One dimensional value noise
float noise1D(float x) {
	float i, f = modf(x, i);
	f = cubicSmooth(f);
	return hash1(R1(int(i))) * (1.0 - f) + hash1(R1(int(i + 1.0))) * f;
}

vec3 getWeather() {
#ifdef DYNAMIC_WEATHER
	float weatherTime  = float(worldDay) + rcp(24000.0) * float(worldTime);
#else
	const float weatherTime  = 0.0;
#endif

	float temperature  = noise1D(rcp(goldenRatio) * weatherTime);
		  temperature += 0.2 * biomeTemperature;

	float humidity     = noise1D(rcp(goldenRatio) * weatherTime + 13.4625);
	      humidity     = mix(0.25, 0.80, humidity);
		  humidity    += 0.2 * biomeHumidity;
		  humidity    += 0.8 * wetness;

	float windStrength = noise1D(rcp(goldenRatio) * weatherTime + 29.7333);
	      windStrength = mix(0.4, 0.6, windStrength) + 0.4 * rainStrength;

	return vec3(temperature, humidity, windStrength) + vec3(TEMPERATURE_BIAS, HUMIDITY_BIAS, WIND_STRENGTH_BIAS);
}

/* -- clouds -- */

// volumetric layer 0 (cumulus/stratocumulus)

float vcloudLayer0Coverage(vec3 weather) {
	float temperatureWeight = 1.0 - 0.2 * linearStep(0.8, 1.0, weather.x);
	float humidityWeight    = sqrt(max0(weather.y));
	return 0.7 * VCLOUD_LAYER0_COVERAGE * temperatureWeight * humidityWeight;
}

float vcloudLayer0Density(vec3 weather) {
	const float vcloudExtinctionCoeff = 0.1;
	return (VCLOUD_LAYER0_DENSITY * vcloudExtinctionCoeff) * (0.5 + 0.5 * abs(lightDir.y));
}

float vcloudLayer0TypeBlend(vec3 weather) {
	return 1.0 - linearStep(0.25, 0.45, weather.x);
}

float vcloudLayer0DetailMultiplier(vec3 weather) {
	return VCLOUD_LAYER0_WISPINESS;
}

float vcloudLayer0CurlMultiplier(vec3 weather) {
	return VCLOUD_LAYER0_SWIRLINESS;
}

// volumetric layer 1 (altocumulus/altostratus)

float vcloudLayer1Coverage(vec3 weather) {
	float temperatureWeight = linearStep(0.3, 0.6, weather.x);
	float humidityWeight    = linearStep(0.4, 0.6, weather.y);
	return VCLOUD_LAYER1_COVERAGE * temperatureWeight * humidityWeight;
}

float vcloudLayer1TypeBlend(vec3 weather) {
	return 0.5 - linearStep(0.15, 0.35, weather.x) + VCLOUD_LAYER0_TYPE_BLEND;
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
	vec3 worldPos,
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

	float puddle = texture(noiseSampler, worldPos.xz * puddleFrequency).w;
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
	float ripple0 = getRippleHeightmap(noiseSampler, worldPos.xz);
	float ripple1 = getRippleHeightmap(noiseSampler, worldPos.xz + vec2(h, 0.0));
	float ripple2 = getRippleHeightmap(noiseSampler, worldPos.xz + vec2(0.0, h));

	vec3 rippleNormal     = vec3(ripple1 - ripple0, ripple2 - ripple0, h);
	     rippleNormal.xy *= 0.05 * smoothstep(0.0, 0.1, abs(dot(geometryNormal, normalize(worldPos - cameraPosition))));
	     rippleNormal     = normalize(rippleNormal);
		 rippleNormal     = rippleNormal.xzy; // convert to world space

	normal = mix(normal, geometryNormal, puddle);
	normal = mix(normal, rippleNormal, puddle * rainStrength);
	normal = normalizeSafe(normal);
}

#endif // INCLUDE_ATMOSPHERE_WEATHER
