/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/dh_water:
  Translucent Distant Horizons terrain

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 light_levels;
out vec3 scene_pos;
out vec3 normal;
out vec4 tint;

flat out uint is_water;
flat out vec3 light_color;
flat out vec3 ambient_color;

#if defined WORLD_OVERWORLD 
#include "/include/fog/overworld/parameters.glsl"
flat out OverworldFogParameters fog_params;
#endif

// ------------
//   Uniforms
// ------------

uniform sampler2D colortex4; // Sky map, lighting colors

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 dhProjection;
uniform mat4 dhProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

uniform ivec2 atlasSize;

uniform int worldTime;
uniform int worldDay;
uniform int frameCounter;
uniform float frameTimeCounter;

uniform float sunAngle;
uniform float rainStrength;
uniform float wetness;

uniform vec2 view_res;
uniform vec2 view_pixel_size;
uniform vec2 taa_offset;

uniform vec3 light_dir;
uniform vec3 sun_dir;

uniform float eye_skylight;

uniform float biome_temperate;
uniform float biome_arid;
uniform float biome_snowy;
uniform float biome_taiga;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_may_rain;
uniform float biome_may_snow;
uniform float biome_temperature;
uniform float biome_humidity;

uniform float world_age;
uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

uniform float desert_sandstorm;

#if defined WORLD_OVERWORLD 
#include "/include/weather/fog.glsl"
#endif

void main() {
	light_levels = linear_step(
        vec2(1.0 / 32.0),
        vec2(31.0 / 32.0),
        (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy
    );
	tint          = gl_Color;
    normal        = mat3(gbufferModelViewInverse) * (mat3(gl_ModelViewMatrix) * gl_Normal);

	light_color   = texelFetch(colortex4, ivec2(191, 0), 0).rgb;
#if defined WORLD_OVERWORLD && defined SH_SKYLIGHT
	ambient_color = texelFetch(colortex4, ivec2(191, 11), 0).rgb;
#else
	ambient_color = texelFetch(colortex4, ivec2(191, 1), 0).rgb;
#endif

	is_water = uint(dhMaterialId == DH_BLOCK_WATER);

    vec3 camera_offset = fract(cameraPosition);

    vec3 pos = gl_Vertex.xyz;
         pos = floor(pos + camera_offset + 0.5) - camera_offset;
         pos = transform(gl_ModelViewMatrix, pos);

    scene_pos = transform(gbufferModelViewInverse, pos);

    vec4 clip_pos = dhProjection * vec4(pos, 1.0);

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.66;
#endif

#if defined WORLD_OVERWORLD
    fog_params = get_fog_parameters(get_weather());
#endif

    gl_Position = clip_pos;
}
