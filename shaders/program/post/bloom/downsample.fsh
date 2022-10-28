/*
--------------------------------------------------------------------------------

  Photon Shaders by SixthSurge

  program/post/bloom/downsample.fsh
  Progressively downsample bloom tiles
  You must define BLOOM_TILE_INDEX before including this file

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

/* DRAWBUFFERS:0 */
layout (location = 0) out vec3 bloomTile;

in vec2 uv;

#if BLOOM_TILE_INDEX == 0
// Initial tile reads TAA output directly
uniform sampler2D colortex5;
#define SRC_SAMPLER colortex5
#else
// Subsequent tiles read from colortex0
uniform sampler2D colortex0;
#define SRC_SAMPLER colortex0
#endif

uniform vec2 texelSize;

const float srcTileSize   = 0.5 * exp2(-(BLOOM_TILE_INDEX - 1.0));
const float srcTileOffset = 1.0 - exp2(-max0(BLOOM_TILE_INDEX - 1.0));

void main() {
	vec2 padAmount = 2.0 * texelSize * rcp(srcTileSize);
	vec2 uvSrc = clamp(uv, padAmount, 1.0 - padAmount) * srcTileSize + srcTileOffset;

	// 6x6 downsampling filter made from overlapping 4x4 box kernels
	// As described in "Next Generation Post-Processing in Call of Duty Advanced Warfare"
	bloomTile  = textureLod(SRC_SAMPLER, uvSrc + vec2( 0.0,  0.0) * texelSize, 0).rgb * 0.125;

	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2( 1.0,  1.0) * texelSize, 0).rgb * 0.125;
	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2(-1.0,  1.0) * texelSize, 0).rgb * 0.125;
	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2( 1.0, -1.0) * texelSize, 0).rgb * 0.125;
	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2(-1.0, -1.0) * texelSize, 0).rgb * 0.125;

	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2( 2.0,  0.0) * texelSize, 0).rgb * 0.0625;
	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2(-2.0,  0.0) * texelSize, 0).rgb * 0.0625;
	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2( 0.0,  2.0) * texelSize, 0).rgb * 0.0625;
	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2( 0.0, -2.0) * texelSize, 0).rgb * 0.0625;

	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2( 2.0,  2.0) * texelSize, 0).rgb * 0.03125;
	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2(-2.0,  2.0) * texelSize, 0).rgb * 0.03125;
	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2( 2.0, -2.0) * texelSize, 0).rgb * 0.03125;
	bloomTile += textureLod(SRC_SAMPLER, uvSrc + vec2(-2.0, -2.0) * texelSize, 0).rgb * 0.03125;
}
