#if !defined INCLUDE_MISC_WATER_NORMAL
#define INCLUDE_MISC_WATER_NORMAL

#include "/include/utility/space_conversion.glsl"

float gerstner_wave(
    vec2 coord,
    vec2 wave_dir,
    float t,
    float noise,
    float wavelength
) {
    // Gerstner wave function from Belmu in #snippets, modified
    const float g = 9.8;

    float k = tau / wavelength;
    float w = sqrt(g * k);

    float x = w * t - k * (dot(wave_dir, coord) + noise);

    return sqr(sin(x) * 0.5 + 0.5);
}

void water_waves_setup(
    bool flowing_water,
    vec2 flow_dir,
    out vec2 wave_dir,
    out mat2 wave_rot,
    out float t
) {
    const float wave_speed_still = 0.5 * WATER_WAVE_SPEED_STILL;
    const float wave_speed_flowing = 0.7 * WATER_WAVE_SPEED_FLOWING;
    const float wave_angle = 30.0 * degree;

    t = (flowing_water ? wave_speed_flowing : wave_speed_still)
        * frameTimeCounter;

    wave_dir
        = flowing_water ? flow_dir : vec2(cos(wave_angle), sin(wave_angle));
    wave_rot = flowing_water
        ? mat2(1.0)
        : mat2(
              cos(golden_angle),
              sin(golden_angle),
              -sin(golden_angle),
              cos(golden_angle)
          );
}

float get_water_height(vec2 coord, vec2 wave_dir, mat2 wave_rot, float t) {
    // Parameters

    // Gerstner waves
    const float wave_frequency = 0.7 * WATER_WAVE_FREQUENCY;
    const float persistence = 0.5 * WATER_WAVE_PERSISTENCE;
    const float lacunarity = 1.7 * WATER_WAVE_LACUNARITY;

    // Noise
    const float noise_frequency = 0.007;
    const float noise_strength = 2.0;

    // Height variation
    const float height_variation_frequency = 0.001;
    const float min_height = 0.4;
    const float height_variation_scale = 2.0;
    const float height_variation_offset = -0.5;
    const float height_variation_scroll_speed = 0.1;

    // Reciprical of sum of amplitudes of all waves
    // This is a geometric series with initial value of 1 and common ratio of
    // `persistence`
    const float amplitude_normalization_factor = (1.0 - persistence)
        / (1.0 - pow(persistence, float(WATER_WAVE_ITERATIONS)));

    // Sample noise textures first (latency hiding)

    float[WATER_WAVE_ITERATIONS] wave_noise;
    vec2 noise_coord = (coord + vec2(0.0, 0.25 * t)) * noise_frequency;
    for (uint i = 0u; i < WATER_WAVE_ITERATIONS; ++i) {
        wave_noise[i] = texture(noisetex, noise_coord).y;
        noise_coord *= 2.5;
    }

#ifdef WATER_WAVES_HEIGHT_VARIATION
    float height_variation_noise
        = texture(
              noisetex,
              (coord + vec2(0.0, height_variation_scroll_speed * t))
                  * height_variation_frequency
        )
              .y;
#endif

    // Calculate wave height

    float height = 0.0;
    float amplitude_sum = 0.0;

    float wave_length = 1.0;
    float amplitude = 1.0;
    float frequency = wave_frequency;

    for (uint i = 0u; i < WATER_WAVE_ITERATIONS; ++i) {
        height += gerstner_wave(
                      coord * frequency,
                      wave_dir,
                      t,
                      wave_noise[i] * noise_strength,
                      wave_length
                  )
            * amplitude;

        amplitude *= persistence;
        frequency *= lacunarity;
        wave_length *= 1.5;

        wave_dir *= wave_rot;
    }

#ifdef WATER_WAVES_HEIGHT_VARIATION
    height *= max(
        min_height,
        height_variation_noise * height_variation_scale
            + height_variation_offset
    );
#endif

    return height * amplitude_normalization_factor;
}

vec3 get_water_normal(
    vec3 world_pos,
    vec3 flat_normal,
    vec2 coord,
    vec2 flow_dir,
    float skylight,
    bool flowing_water
) {
    vec2 wave_dir;
    mat2 wave_rot;
    float t;
    water_waves_setup(flowing_water, flow_dir, wave_dir, wave_rot, t);

    const float h = 0.1;
    float wave0 = get_water_height(coord, wave_dir, wave_rot, t);
    float wave1 = get_water_height(coord + vec2(h, 0.0), wave_dir, wave_rot, t);
    float wave2 = get_water_height(coord + vec2(0.0, h), wave_dir, wave_rot, t);

#if defined WORLD_OVERWORLD
    float normal_influence = flowing_water
        ? 0.1
        : mix(0.01, 0.04 + 0.15 * rainStrength, dampen(skylight));
#else
    float normal_influence = 0.04;
#endif
    normal_influence *= smoothstep(
        0.0,
        0.15,
        abs(dot(flat_normal, normalize(world_pos - cameraPosition)))
    ); // prevent noise when looking horizontally
    normal_influence *= WATER_WAVE_STRENGTH;

    vec3 normal = vec3(wave1 - wave0, wave2 - wave0, h);
    normal.xy *= normal_influence;

    return normalize(normal);
}

vec2 get_water_parallax_coord(
    vec3 tangent_dir,
    vec2 coord,
    vec2 flow_dir,
    bool flowing_water
) {
    const int step_count = 4;
    const float parallax_depth = 0.2;

    vec2 wave_dir;
    mat2 wave_rot;
    float t;
    water_waves_setup(flowing_water, flow_dir, wave_dir, wave_rot, t);

    vec2 ray_step = tangent_dir.xy * rcp(-tangent_dir.z) * parallax_depth
        * rcp(float(step_count));

    float depth_value = get_water_height(coord, wave_dir, wave_rot, t);
    float depth_march = 0.0;
    float depth_previous;

    while (depth_march < depth_value) {
        coord += ray_step;
        depth_previous = depth_value;
        depth_value = get_water_height(coord, wave_dir, wave_rot, t);
        depth_march += rcp(float(step_count));
    }

    // Interpolation step

    float depth_before = depth_previous - depth_march + rcp(float(step_count));
    float depth_after = depth_value - depth_march;

    return mix(
        coord,
        coord - ray_step,
        depth_after / (depth_after - depth_before)
    );
}

// Water trail - continuous ripples following player through water
// Creates chain of wave emitters along the player's path
#ifdef WATER_TRAIL

// Animated concentric ripples from a point source
float water_trail_ripples(float dist, float time, float max_dist) {
    if (dist > max_dist || dist < 0.08) return 0.0;

    // Concentric rings - moderate animation speed
    float ripple = 0.0;
    ripple += sin(dist * 6.0  - time * 3.0) * 0.50;
    ripple += sin(dist * 10.0 - time * 2.5) * 0.30;
    ripple += sin(dist * 15.0 - time * 3.5) * 0.20;

    // Concentrated near source, fades toward max radius
    float atten = 1.0 / (1.0 + dist * 0.7)
                * smoothstep(max_dist, max_dist * 0.25, dist)
                * smoothstep(0.08, 0.30, dist);

    return ripple * atten;
}

// Apply trail ripples from a single source point onto the water normal
// Water detection is handled by Y proximity check in the main shader
vec3 apply_water_trail_at(
    vec3 normal_tangent,
    vec3 world_pos,
    vec3 source_pos,
    float strength,
    float max_dist,
    float time
) {
    vec2 delta = world_pos.xz - source_pos.xz;
    float dist = length(delta);
    float y_diff = abs(world_pos.y - source_pos.y);

    if (dist < max_dist && dist > 0.08 && y_diff < 20.0) {
        float y_factor = smoothstep(20.0, 1.0, y_diff);
        float ripple = water_trail_ripples(dist, time * WATER_TRAIL_SPEED, max_dist);

        vec2 radial = delta / dist;
        normal_tangent.xy -= radial * ripple * strength * y_factor;
    }

    return normal_tangent;
}

// Splash: single expanding ring that decays over time
vec3 apply_water_splash(
    vec3 normal_tangent,
    vec3 world_pos,
    vec3 splash_pos,
    float splash_time,
    float splash_velocity,
    float strength,
    float max_dist
) {
    vec2 delta = world_pos.xz - splash_pos.xz;
    float dist = length(delta);
    float y_diff = abs(world_pos.y - splash_pos.y);

    if (dist > max_dist || y_diff > 2.0) return normal_tangent;

    float elapsed = frameTimeCounter - splash_time;
    if (elapsed < 0.0 || elapsed > 6.0) return normal_tangent;

    // Ring expands outward over time
    float ring_pos = elapsed * 1.8;
    float ring_width = 0.4 + elapsed * 0.15;

    // Ring shape: peaks at ring_pos, width grows with time
    float ring = exp(-0.5 * pow((dist - ring_pos) / ring_width, 2.0));

    // Intensity from impact velocity + decay over time
    float impact_str = 0.3 + 0.7 * smoothstep(2.0, 15.0, abs(splash_velocity));
    float decay = exp(-elapsed * 0.7);

    // Concentric waves within the ring
    float wave = sin(dist * 8.0 - elapsed * 4.0) * ring * decay * impact_str;

    vec2 radial = delta / max(dist, 0.1);
    normal_tangent.xy -= radial * wave * strength * smoothstep(2.0, 0.0, y_diff);

    return normal_tangent;
}

#endif

#endif // INCLUDE_MISC_WATER_NORMAL
