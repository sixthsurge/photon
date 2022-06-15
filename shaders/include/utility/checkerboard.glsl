#if !defined INCLUDE_UTILITY_CHECKERBOARD
#define INCLUDE_UTILITY_CHECKERBOARD

const ivec2[2] checkerboardOffsets2x1 = ivec2[2](
	ivec2(0, 0),
	ivec2(1, 0)
);

const ivec2[4] checkerboardOffsets2x2 = ivec2[4](
	ivec2(0, 0),
	ivec2(1, 1),
	ivec2(1, 0),
	ivec2(0, 1)
);

const ivec2[8] checkerboardOffsets4x2 = ivec2[8](
	ivec2(0, 0),
	ivec2(2, 0),
	ivec2(1, 1),
	ivec2(3, 1),
	ivec2(1, 0),
	ivec2(3, 0),
	ivec2(0, 1),
	ivec2(2, 1)
);

const ivec2[16] checkerboardOffsets4x4 = ivec2[16](
	ivec2(0, 0),
	ivec2(2, 0),
	ivec2(0, 2),
	ivec2(2, 2),
	ivec2(1, 1),
	ivec2(3, 1),
	ivec2(1, 3),
	ivec2(3, 3),
	ivec2(1, 0),
	ivec2(3, 0),
	ivec2(1, 2),
	ivec2(3, 2),
	ivec2(0, 1),
	ivec2(2, 1),
	ivec2(0, 3),
	ivec2(2, 3)
);

#endif // INCLUDE_UTILITY_CHECKERBOARD
