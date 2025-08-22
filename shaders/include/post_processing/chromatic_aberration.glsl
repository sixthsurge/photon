/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  include/post_processing/chromatic_aberration.glsl:
  Chromatic aberration effect

--------------------------------------------------------------------------------
*/

#if !defined INCLUDE_POST_PROCESSING_CHROMATIC_ABERRATION
#define INCLUDE_POST_PROCESSING_CHROMATIC_ABERRATION

vec3 chromatic_aberration(sampler2D sampler, vec2 coord, float intensity) {
    #ifndef CHROMATIC_ABERRATION
    return texture(sampler, coord).rgb;
    #endif
    
    vec2 center_offset = coord - 0.5;
    float distance_from_center = length(center_offset);

    float aberration_scale = intensity * distance_from_center * 0.01;
    
    float r = texture(sampler, coord + center_offset * aberration_scale * 1.0).r;
    float g = texture(sampler, coord + center_offset * aberration_scale * 0.0).g;
    float b = texture(sampler, coord + center_offset * aberration_scale * -1.0).b;
    
    return vec3(r, g, b);
}

#endif // INCLUDE_POST_PROCESSING_CHROMATIC_ABERRATION