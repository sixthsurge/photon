#if !defined INCLUDE_ACES_MATRICES
#define INCLUDE_ACES_MATRICES

#include "/include/utility/color.glsl"

const mat3 ap0_to_xyz = mat3(
	 0.9525523959,  0.0000000000,  0.0000936786,
	 0.3439664498,  0.7281660966, -0.0721325464,
	 0.0000000000,  0.0000000000,  1.0088251844
);
const mat3 xyz_to_ap0 = mat3(
	 1.0498110175,  0.0000000000, -0.0000974845,
	-0.4959030231,  1.3733130458,  0.0982400361,
	 0.0000000000,  0.0000000000,  0.9912520182
);

const mat3 ap1_to_xyz = mat3(
	 0.6624541811,  0.1340042065,  0.1561876870,
	 0.2722287168,  0.6740817658,  0.0536895174,
	-0.0055746495,  0.0040607335,  1.0103391003
);
const mat3 xyz_to_ap1 = mat3(
	 1.6410233797, -0.3248032942, -0.2364246952,
	-0.6636628587,  1.6153315917,  0.0167563477,
	 0.0117218943, -0.0082844420,  0.9883948585
);

// Bradford chromatic adaptation matrix from d60 (ACES white point) to d65 (rec. 709 white point)
const mat3 d60_to_d65 = mat3(
	 0.9872240000, -0.0061132700,  0.0159533000,
	-0.0075983600,  1.0018600000,  0.0053300200,
	 0.0030725700, -0.0050959500,  1.0816800000
);
const mat3 d65_to_d60 = mat3(
	 1.0130349240,  0.0061053089, -0.0149709632,
	 0.0076982300,  0.9981648318, -0.0050320341,
	-0.0028413125,  0.0046851556,  0.9245066529
);

const mat3 ap0_to_ap1 = ap0_to_xyz * xyz_to_ap1;
const mat3 ap1_to_ap0 = ap1_to_xyz * xyz_to_ap0;

const mat3 rec709_to_ap0  = rec709_to_xyz * d65_to_d60 * xyz_to_ap0;
const mat3 ap0_to_rec709  = ap0_to_xyz * d60_to_d65 * xyz_to_rec709;
const mat3 rec709_to_ap1  = rec709_to_xyz * d65_to_d60 * xyz_to_ap1;
const mat3 ap1_to_rec709  = ap1_to_xyz * d60_to_d65 * xyz_to_rec709;
const mat3 rec2020_to_ap0 = rec2020_to_xyz * d65_to_d60 * xyz_to_ap0;
const mat3 ap0_to_rec2020 = ap0_to_xyz * d60_to_d65 * xyz_to_rec2020;
const mat3 rec2020_to_ap1 = rec2020_to_xyz * d65_to_d60 * xyz_to_ap1;
const mat3 ap1_to_rec2020 = ap1_to_xyz * d60_to_d65 * xyz_to_rec2020;

// Used for quantities that are multiplied by an illuminant, like the diffuse albedo. These take
// the white point of the light source
const mat3 rec709_to_ap1_unlit = rec709_to_xyz * xyz_to_ap1;
const mat3 rec2020_to_ap1_unlit = rec2020_to_xyz * xyz_to_ap1;

#endif // INCLUDE_ACES_MATRICES
