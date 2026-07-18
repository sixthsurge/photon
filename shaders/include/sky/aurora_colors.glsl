#if !defined INCLUDE_SKY_AURORA_COLORS
#define INCLUDE_SKY_AURORA_COLORS

#include "/include/utility/random.glsl"

// [0] - bottom color
// [1] - top color
// [2] - bottom color amount
mat2x3 get_aurora_colors() {
    const mat2x3[] aurora_colors = mat2x3[](
        mat2x3(                                     
            vec3(0.85, 0.28, 1.00), // purple
            vec3(0.00, 1.00, 0.04) // green
        ),
        mat2x3(                                     // Inspired by Euphoria Patches
            vec3(0.7, 1.00, 0.85), // light cyan
            vec3(1.00, 0.55, 0.95) // dull magenta
        ),
        mat2x3(                                     // Inspired by Euphoria Patches
            vec3(0.35, 0.4, 1.00), // light blue
            vec3(0.35, 0.4, 1.00) // light blue
        ),
        mat2x3(                                     // Inspired by Euphoria Patches
            vec3(0.58, 1.0, 0.58), // light green
            vec3(0.4, 0.6, 0.4) // gray light green
        ),
        mat2x3(                                     // Inspired by Euphoria Patches
            vec3(1, 0.18, 0.15), // red
            vec3(0.12, 0.9, 0.9) // cyan
        ),
        mat2x3(                                     
            vec3(0.2, 0.76, 0.8), // cyan
            vec3(0.7, 0.04, 1.00) // deep purple
        ),
        mat2x3(                                     
            vec3(0.29, 1.0, 0.32), // light green
            vec3(1.15, 0.1, 0.15) // red
        ),
        mat2x3(                                     
            vec3(0.08, 0.4, 1.0), // electric blue
            vec3(1, 0.16, 0.23) // deep pink
        ),
        mat2x3(                                     
            vec3(0.29, 1.0, 0.32), // light green
            vec3(1, 0.11, 0.16) // deep pink
        ),
        mat2x3(                                     
            vec3(0.9, 0.65, 0.05), // orange
            vec3(0.9, 0.105, 0.0) // burnt orange
        )
    );

    uint day_index = uint(worldDay);
    day_index = lowbias32(day_index) % aurora_colors.length();

    return aurora_colors[day_index];
}

// 0.0 - no aurora
// 1.0 - full aurora
float get_aurora_amount() {
    float night = smoothstep(0.0, 0.2, -sun_dir.y);

#if AURORA_NORMAL == AURORA_NEVER
    float aurora_normal = 0.0;
#elif AURORA_NORMAL == AURORA_RARELY
    float aurora_normal = float(lowbias32(uint(worldDay)) % 5 == 1);
#elif AURORA_NORMAL == AURORA_ALWAYS
    float aurora_normal = 1.0;
#endif

#if AURORA_SNOW == AURORA_NEVER
    float aurora_snow = 0.0;
#elif AURORA_SNOW == AURORA_RARELY
    float aurora_snow = float(lowbias32(uint(worldDay)) % 5 == 1);
#elif AURORA_SNOW == AURORA_ALWAYS
    float aurora_snow = 1.0;
#endif

    return night * mix(aurora_normal, aurora_snow, biome_may_snow);
}

#endif // INCLUDE_SKY_AURORA_COLORS
