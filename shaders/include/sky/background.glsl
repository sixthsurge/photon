#if !defined INCLUDE_SKY_BACKGROUND
#define INCLUDE_SKY_BACKGROUND

// Celestial background of the overworld sky: galaxy, skytextured output
// (vanilla sun/moon, custom skies) and stars. Split out of draw_sky so that
// the Apple Silicon deferred4 split can draw it in an earlier pass (see
// program/d4_split.glsl)

#include "/include/sky/stars.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"

// Trick to make stars rotate with sun and moon
vec3 get_celestial_dir(vec3 ray_dir) {
#if defined SHADOW
    mat3 rot = (sunAngle < 0.5)
        ? mat3(shadowModelViewInverse)
        : mat3(
              -shadowModelViewInverse[0].xyz,
              shadowModelViewInverse[1].xyz,
              -shadowModelViewInverse[2].xyz
          );

    return ray_dir * rot;
#else
    return ray_dir;
#endif
}

#ifdef GALAXY
vec3 draw_galaxy(vec3 ray_dir, out float galaxy_luminance) {
    const vec3 galaxy_tint = vec3(0.75, 0.66, 1.0) * GALAXY_INTENSITY;

    float galaxy_intensity = 0.05 + 1.0 * linear_step(-0.1, 0.25, -sun_dir.y);

    float lon = atan(ray_dir.x, ray_dir.z);
    float lat = fast_acos(-ray_dir.y);

    vec3 galaxy
        = texture(galaxy_sampler, vec2(lon * rcp(tau) + 0.5, lat * rcp(pi)))
              .rgb;

    galaxy = srgb_eotf_inv(galaxy) * rec709_to_working_color;

    galaxy *= galaxy_intensity * galaxy_tint;

    galaxy_luminance = dot(galaxy, luminance_weights_rec709);

    galaxy = mix(vec3(galaxy_luminance), galaxy, 2.0);

    return max0(galaxy);
}
#endif

vec3 draw_sky_background(vec3 ray_dir, vec3 skytextured_output) {
    vec3 celestial_dir = get_celestial_dir(ray_dir);

    // Galaxy

#ifdef GALAXY
    float galaxy_luminance;
    vec3 sky = draw_galaxy(celestial_dir, galaxy_luminance);
#else
    const float galaxy_luminance = 0.0;
    vec3 sky = vec3(0.0);
#endif

    // Sun, moon, custom sky from skytextured

    sky += skytextured_output;

#ifdef STARS
    // Stars
    float stars_visibility
        = clamp01(1.0 - dot(skytextured_output, vec3(0.33) * 256.0));
    sky += draw_stars(celestial_dir, galaxy_luminance) * stars_visibility;
#endif

    return sky;
}

#endif // INCLUDE_SKY_BACKGROUND
