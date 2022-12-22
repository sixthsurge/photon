#if !defined UTILITY_CHECKERBOARD_INCLUDED
#define UTILITY_CHECKERBOARD_INCLUDED

const ivec2[2] checkerboard_offsets_2x1 = ivec2[2](
	ivec2(0, 0),
	ivec2(1, 0)
);

const ivec2[4] checkerboard_offsets_2x2 = ivec2[4](
	ivec2(0, 0),
	ivec2(1, 1),
	ivec2(1, 0),
	ivec2(0, 1)
);

const ivec2[8] checkerboard_offsets_4x2 = ivec2[8](
	ivec2(0, 0),
	ivec2(2, 0),
	ivec2(1, 1),
	ivec2(3, 1),
	ivec2(1, 0),
	ivec2(3, 0),
	ivec2(0, 1),
	ivec2(2, 1)
);

const ivec2[9] checkerboard_offsets_3x3 = ivec2[9](
	ivec2(0, 0),
	ivec2(2, 0),
	ivec2(0, 2),
	ivec2(2, 2),
	ivec2(1, 1),
	ivec2(1, 0),
	ivec2(1, 2),
	ivec2(0, 1),
	ivec2(2, 1)
);

const ivec2[16] checkerboard_offsets_4x4 = ivec2[16](
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

#endif // UTILITY_CHECKERBOARD_INCLUDED
