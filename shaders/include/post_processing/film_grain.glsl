/*
--------------------------------------------------------------------------------

  Photon Shader Custom by bonbox

  include/post_processing/film_grain.glsl:
  Film grain effect

--------------------------------------------------------------------------------
*/

#if !defined INCLUDE_POST_PROCESSING_FILM_GRAIN
#define INCLUDE_POST_PROCESSING_FILM_GRAIN

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 443.897);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

float film_grain_noise(vec2 coord, float frameTimeCounter) {
    float scale = FILM_GRAIN_SIZE * 64.0; 
    
    vec2 scaled_coord = coord * scale;
    
#ifdef FILM_GRAIN_ANIMATION
    float time_factor = frameTimeCounter * 0.03; 
    vec2 animated_coord = scaled_coord + vec2(time_factor * 23.1, time_factor * 17.3);
#else
    vec2 animated_coord = scaled_coord;
#endif
    
    float noise = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    
    for (int i = 0; i < 3; i++) {
        noise += hash(animated_coord * frequency + vec2(i * 31.4, i * 17.9)) * amplitude;
        frequency *= 2.1;
        amplitude *= 0.5;
    }
    
    noise = (noise / 1.875) - 0.5; 
    noise *= 2.0;
    
    noise = sign(noise) * pow(abs(noise), 0.7);
    
    return noise;
}

vec3 apply_film_grain(vec3 color, vec2 uv, float frameTimeCounter) {
    #ifndef FILM_GRAIN
    return color;
    #endif
    
    float grain_intensity = FILM_GRAIN_INTENSITY * 0.80; 
    
    float noise = film_grain_noise(uv, frameTimeCounter);
    
    float luminance = dot(color, luminance_weights);
    
    float grain_modulation = 4.0 * luminance * (1.0 - luminance);
    grain_modulation = max(grain_modulation, 0.3); 
    
    float grain_factor = grain_intensity * grain_modulation;
    
    vec3 additive_grain = color + vec3(noise * grain_factor * 0.5);
    vec3 multiplicative_grain = color * (1.0 + noise * grain_factor * 0.5);
    
    vec3 final_grain = mix(additive_grain, multiplicative_grain, 0.6);
    
    return final_grain;
}

#endif // INCLUDE_POST_PROCESSING_FILM_GRAIN
