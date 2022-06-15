#if !defined INCLUDE_ATMOSPHERE_WEATHER
#define INCLUDE_ATMOSPHERE_WEATHER

#include "/include/utility/random.glsl"

// One dimensional value noise
float noise1D(float x) {
	float i, f = modf(x, i);
	f = cubicSmooth(f);
	return hash1(i) * (1.0 - f) + hash1(1.0 + i) * f;
}

void weatherSetup() {
#ifdef DYNAMIC_WEATHER
#else
	airMieTurbidity       = 1.0;
	cloudsCirrusCoverage  = 1.0;
	cloudsCumulusCoverage = 0.5;
#endif
}

#endif // INCLUDE_ATMOSPHERE_WEATHER
