/*
(included by final.fsh)

const int colortex0Format  = R11F_G11F_B10F; // full res    | vanilla sun and moon (skytextured -> d4), scene color (d4 -> temporal), bloom tiles (c5 -> c14), final color (c14 -> final)
const int colortex1Format  = RGBA16;         // full res    | gbuffer data 0 (solid -> c1), TAAU min color for AABB clipping (c3 -> c4)
const int colortex2Format  = RGBA16;         // full res    | gbuffer data 1 (solid -> c1), TAAU max color for AABB clipping (c3 -> c4)
const int colortex3Format  = RGBA8;          // full res    | OF damage overlay/enchantment glint (solid -> d4), refraction data (translucent -> c1), bloomy fog amount (c1 -> c14)
const int colortex4Format  = RGBA16F;        // 192x108     | sky map + light colors/sky SH (d0 -> c1)
const int colortex5Format  = RGBA16F;        // full res    | scene history (always)
const int colortex6Format  = RGBA16;         // quarter res | ambient occlusion history (always), fog transmittance (c0 -> c1 +flip) 
const int colortex7Format  = RGB16F;         // quarter res | fog scattering (always)
const int colortex8Format  = RGB8;           // 256x256     | cloud coverage map and shadow map (p0 -> c1)
const int colortex9Format  = RGBA16F;        // clouds res  | low-res clouds (d1 -> d2)
const int colortex10Format = RG16F;          // clouds res  | low-res clouds apparent distance and indirect scattering (d1 -> d2)
const int colortex11Format = RGBA16F;        // full res    | clouds history (always)
const int colortex12Format = RGB16F;         // full res    | clouds pixel age, apparent distance, indirect scattering (always)
const int colortex13Format = RGBA16F;        // full res    | rendered translucent layer (translucent -> c1)
const int colortex14Format = RG16F;          // quarter res | ambient occlusion history data (always)
const int colortex15Format = R32F;           // full res    | DH combined depth buffer (d1 -> c2)

const bool colortex0Clear  = true;
const bool colortex1Clear  = false;
const bool colortex2Clear  = false;
const bool colortex3Clear  = true;
const bool colortex4Clear  = false;
const bool colortex5Clear  = false;
const bool colortex6Clear  = false;
const bool colortex7Clear  = false;
const bool colortex8Clear  = false;
const bool colortex9Clear  = false;
const bool colortex10Clear = false;
const bool colortex11Clear = false;
const bool colortex12Clear = false;
const bool colortex13Clear = true;
const bool colortex14Clear = false;
const bool colortex15Clear = false;

const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex13ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 shadowcolor0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
