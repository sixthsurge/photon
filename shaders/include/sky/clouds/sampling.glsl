#if !defined INCLUDE_SKY_CLOUDS_SAMPLING
#define INCLUDE_SKY_CLOUDS_SAMPLING

// Sample filtered clouds
vec4 read_clouds_and_aurora(vec2 uv, out float apparent_distance) {
#if defined WORLD_OVERWORLD
	// Soften clouds for new pixels
	float pixel_age = texelFetch(colortex12, ivec2(uv * view_res * taau_render_scale), 0).y;
	float ld = 2.0 * dampen(max0(1.0 - 0.1 * pixel_age));

	apparent_distance = min_of(textureGather(colortex12, uv * taau_render_scale, 0));
	vec4 result = textureLod(colortex11, uv * taau_render_scale, ld);

	if (LIGHTNING_FLASH_UNIFORM > 0.01) {
		float ambient_scattering = texture(colortex12, uv * taau_render_scale).z;
		result.xyz += LIGHTNING_FLASH_UNIFORM * lightning_flash_intensity * ambient_scattering;
	}

	result.xyz *= clamp01(1.0 - blindness - darknessFactor);

	return result;
#else
	return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

#endif // INCLUDE_SKY_CLOUDS_SAMPLING
