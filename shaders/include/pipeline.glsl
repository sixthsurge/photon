/*
(gbuffers and post-processing)
0  | rgba8   | fullscreen        | overlays, vanilla sky (solid -> deferred), translucent albedo (translucent -> composite)
1  | rg32ui  | fullscreen        | gbuffer data (solid -> composite)
2  | rgb16f  | fullscreen        | velocity vectors (solid -> composite), post-processing color (composite)

(lighting)
3  | rgb11f  | taa render scale  | scene radiance (deferred -> composite)
4  | rgb11f  | 256x128           | sky capture, lighting color palette, dynamic weather properties (deferred -> composite)
5  | rgba16  | taa render scale  | low-res clouds (deferred), indirect lighting data (deferred), responsive aa flag (composite)
6  | rgb16f  | taa render scale  | atmosphere scattering (deferred -> composite), volumetric fog scattering (composite), taa min color (composite)
7  | rgb16f  | taa render scale  | cloud shadow map (deferred -> composite), volumetric fog transmittance (composite), taa max color (composite)

(history buffers)
8  | rgba16f | fullscreen        | scene history
9  | rgb16f  | sspt render scale | indirect lighting history 0
10 | rgba16f | sspt render scale | indirect lighting history 1
11 | rgb16f  | taa render scale  | clouds history
12 | rg8     | taa render scale  | clouds pixel age
13 | rg16f   | taa render scale  | previous frame depth

const int colortex0Format  = RGBA8;
const int colortex2Format  = RGB16F;
const int colortex3Format  = R11F_G11F_B10F;
const int colortex4Format  = R11F_G11F_B10F;
const int colortex5Format  = RGBA16;
const int colortex6Format  = RGBA16F;
const int colortex7Format  = RGB16F;
const int colortex8Format  = RGBA16F;
const int colortex10Format = RGBA16;
const int colortex11Format = RGBA16F;
const int colortex12Format = R8I;
const int colortex13Format = RG16F;

#ifdef SPECULAR_MAP
	const int colortex1Format = RGBA32UI;
#else
	#ifdef NORMAL_MAP
		const int colortex1Format = RGB32UI;
	#else
		const int colortex1Format = RG32UI;
	#endif
#endif

const bool colortex0Clear  = true;
const bool colortex1Clear  = true;
const bool colortex2Clear  = true;
const bool colortex3Clear  = false;
const bool colortex4Clear  = false;
const bool colortex5Clear  = false;
const bool colortex6Clear  = false;
const bool colortex7Clear  = false;
const bool colortex8Clear  = false;
const bool colortex11Clear = false;
const bool colortex12Clear = false;
const bool colortex13Clear = false;

const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

const int shadowcolor0Format = RGB8;
*/
