#if !defined WINDANIMATION_INCLUDED
#define WINDANIMATION_INCLUDED

vec3 getWindOffset(vec3 worldPos, float windSpeed, float windStrength, bool isTallPlantTopVertex) {
	const float windAngle = 30.0 * degree;
	const vec2 windDir = vec2(cos(windAngle), sin(windAngle));

	float t = windSpeed * frameTimeCounter;

	float gustAmount  = texture(noisetex, 0.05 * (worldPos.xz + windDir * t)).y;
	      gustAmount *= gustAmount;

	vec3 gust = vec3(windDir * gustAmount, 0.1 * gustAmount).xzy;

	worldPos = 32.0 * worldPos + 3.0 * t + vec3(0.0, goldenAngle, 2.0 * goldenAngle);
	vec3 wobble = sin(worldPos) + 0.5 * sin(2.0 * worldPos) + 0.25 * sin(4.0 * worldPos);

	if (isTallPlantTopVertex) { gust *= 2.0; wobble *= 0.5; }

	return windStrength * (gust + 0.1 * wobble);
}

vec3 animateVertex(vec3 worldPos, bool isTopVertex, float skylight, uint blockId) {
	float windSpeed = 0.3;
	float windStrength = sqr(skylight) * (0.25 + 0.5 * rainStrength);

	switch (blockId) {
#ifdef WAVING_PLANTS
	case 16:
		return getWindOffset(worldPos, windSpeed, windStrength, false) * float(isTopVertex);

	case 17:
		return getWindOffset(worldPos, windSpeed, windStrength, false) * float(isTopVertex);

	case 18:
		return getWindOffset(worldPos, windSpeed, windStrength, isTopVertex);
#endif

#ifdef WAVING_LEAVES
	case 19:
		return getWindOffset(worldPos, windSpeed, windStrength * 0.5, false);
#endif

	default:
		return vec3(0.0);

	// prevent game crash caused by potentially empty switch statement
	case -1:
		return vec3(0.0);
	}
}

#endif // WINDANIMATION_INCLUDED
