/*
0  | rgba8   | Fullscreen        | Overlays, vanilla sky (solid -> deferred), translucent albedo (translucent -> composite)
1  | rg32ui  | Fullscreen        | Gbuffer data (solid -> composite)
2  | rgb16f  | Fullscreen        | Velocity vectors (solid -> composite), post-processing color (composite)
3  | rgb11f  | TAA render scale  | Scene radiance (deferred -> composite)
4  | rgb11f  | 256x128           | Sky capture, lighting color palette, dynamic weather properties (deferred -> composite)
5  | rgba16  | TAA render scale  | Low-res clouds (deferred), indirect lighting data (deferred), responsive aa flag and depth min/max (composite)
6  | rgb16f  | TAA render scale  | Atmosphere scattering (deferred -> composite), volumetric fog scattering (composite), taa min color (composite)
7  | rgb16f  | TAA render scale  | Volumetric fog transmittance (composite), taa max color (composite)
8  | rgba16f | Fullscreen        | Scene history
9  | rgba16f | SSPT render scale | SSR history
10 | rgba16f | SSPT render scale | Indirect lighting history
11 | rgb16f  | TAA render scale  | Clouds history
12 | rg8     | TAA render scale  | Clouds pixel age
13 | rg16f   | TAA render scale  | Previous frame depth
14 | r32f    | Fullscreen        | Temporally stable linear depth
15 | rgb11f  | 960x1080          | Cloud shadow map, bloom buffer

const int colortex0Format  = RGBA8;
const int colortex2Format  = RGB16F;
const int colortex3Format  = R11F_G11F_B10F;
const int colortex4Format  = R11F_G11F_B10F;
const int colortex5Format  = RGBA16;
const int colortex6Format  = RGBA16F;
const int colortex7Format  = RGB16F;
const int colortex8Format  = RGBA16F;
const int colortex9Format  = RGBA16F;
const int colortex10Format = RGBA16;
const int colortex11Format = RGBA16F;
const int colortex12Format = R8I;
const int colortex13Format = RG16F;
const int colortex14Format = R32F;
const int colortex15Format = R11F_G11F_B10F;

const int shadowcolor0Format = R11F_G11F_B10F;

const bool colortex0Clear  = true;
const bool colortex1Clear  = true;
const bool colortex2Clear  = true;
const bool colortex3Clear  = false;
const bool colortex4Clear  = false;
const bool colortex5Clear  = false;
const bool colortex6Clear  = false;
const bool colortex7Clear  = false;
const bool colortex8Clear  = false;
const bool colortex9Clear  = false;
const bool colortex10Clear = false;
const bool colortex11Clear = false;
const bool colortex12Clear = false;
const bool colortex13Clear = false;
const bool colortex14Clear = false;
const bool colortex15Clear = false;

const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

// Select texture format for colortex1 based on how much data is required
// This is formatted like this because OF doesn't detect #if defined so I can't use #elif or ||
#ifdef MC_GL_VENDOR_INTEL
	// Use floating point texture format for colortex1, even though it stores unsigned integers
	// This really shouldn't work, but it seems to be required to work properly on Intel and Mesa drivers
	#ifdef SPECULAR_MAP
		const int colortex1Format = RGBA32F;
	#else
		#ifdef NORMAL_MAP
			const int colortex1Format = RGB32F;
		#else
			const int colortex1Format = RG32F;
		#endif
	#endif
#else
	#ifdef MC_GL_VENDOR_MESA
	 	// Mesa drivers also require the floating point texture format hack
		#ifdef SPECULAR_MAP
			const int colortex1Format = RGBA32F;
		#else
			#ifdef NORMAL_MAP
				const int colortex1Format = RGB32F;
			#else
				const int colortex1Format = RG32F;
			#endif
		#endif
	#else
		// Use the correct texture format for colortex1
		#ifdef SPECULAR_MAP
			const int colortex1Format = RGBA32UI;
		#else
			#ifdef NORMAL_MAP
				const int colortex1Format = RGB32UI;
			#else
				const int colortex1Format = RG32UI;
			#endif
		#endif
	#endif
#endif
*/
