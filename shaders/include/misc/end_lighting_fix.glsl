#if !defined INCLUDE_MISC_END_LIGHTING_FIX
#define INCLUDE_MISC_END_LIGHTING_FIX

// On OptiFine, sunPosition is provided in world space in the End dimension, when it is normally in view space
// Since I convert sunPosition to world space in shaders.properties, I must undo this conversion in the End dimension on OF

#if defined WORLD_END && !defined IS_IRIS
	#define light_dir view_sun_dir
	#define sun_dir view_sun_dir

	uniform vec3 view_sun_dir;
#endif

#endif // INCLUDE_MISC_END_LIGHTING_FIX
