#if !defined INCLUDE_VERTEX_ANIMATION
#define INCLUDE_VERTEX_ANIMATION

vec3 getWindDisplacement(vec3 positionWorld, float windSpeed, float windStrength, bool isTallPlantTopVertex) {
	const float windAngle = 30.0 * degree;
	const vec2 windDir = vec2(cos(windAngle), sin(windAngle));

	float t = windSpeed * frameTimeCounter;

	float gustAmount  = texture(noisetex, 0.05 * (positionWorld.xz + windDir * t)).y;
	      gustAmount *= gustAmount;

	vec3 gust = vec3(windDir * gustAmount, 0.1 * gustAmount).xzy;

	positionWorld = 32.0 * positionWorld + 3.0 * t + vec3(0.0, goldenAngle, 2.0 * goldenAngle);
	vec3 wobble = sin(positionWorld) + 0.5 * sin(2.0 * positionWorld) + 0.25 * sin(4.0 * positionWorld);

	if (isTallPlantTopVertex) { gust *= 2.0; wobble *= 0.5; }

	return windStrength * (gust + 0.1 * wobble);
}

vec3 animateVertex(vec3 positionWorld, bool isTopVertex, float skylight, uint blockId) {
	float windSpeed = 0.3;
	float windStrength = sqr(skylight) * (0.25 + 0.5 * rainStrength);

	switch (blockId) {
#ifdef WAVING_PLANTS
	case BLOCK_SMALL_PLANT:
		return getWindDisplacement(positionWorld, windSpeed, windStrength, false) * float(isTopVertex);

	case BLOCK_TALL_PLANT_LOWER:
		return getWindDisplacement(positionWorld, windSpeed, windStrength, false) * float(isTopVertex);

	case BLOCK_TALL_PLANT_UPPER:
		return getWindDisplacement(positionWorld, windSpeed, windStrength, isTopVertex);
#endif

#ifdef WAVING_LEAVES
	case BLOCK_LEAVES:
		return getWindDisplacement(positionWorld, windSpeed, windStrength * 0.5, false);
#endif

	default:
		return vec3(0.0);

	// prevent game crash caused by potentially empty switch statement
	case -1:
		return vec3(0.0);
	}
}

#endif // INCLUDE_VERTEX_ANIMATION
