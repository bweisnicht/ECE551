// Compile with gcc -std=c99 -lm angles.c
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

const double pi = 3.14159265359;

int atTable[] = {
	0x200,
	0x12E,
	0x0A0,
	0x051,
	0x029,
	0x014,
	0x00A,
	0x005,
	0x003,
	0x001,
	0x001,
	0x000
	};

int angle_accum, iter, temp, c, s;

static inline int sat(int i)
{
	if (i < -2048)
		return -2048;
	else if (i > 2047)
		return 2047;
	else
		return i;
}

static inline void monitor(int state)
{
	printf("# State: %2d, iter: %2d, cos: %03x, sin: %03x, tmp: %03x, accum: %03x\n",
		state, iter, c & 0xfff, s & 0xfff, temp & 0xfff, angle_accum & 0xfff);
}

int cordic()
{
	if (c < 0) {
		if (s < 0) {
			monitor(7);
			angle_accum = -2048;
		}
		else {
			monitor(7);
			angle_accum = 2047;
		}

		monitor(8);
		c = sat(-c);
		monitor(9);
		s = sat(-s);
	}
	else {
		monitor(7);
		angle_accum = 0;
	}

	for (iter = 0; iter < 12; ++iter) {
		if (s >= 0) {
			monitor(10);
			angle_accum = sat(angle_accum + atTable[iter]);
			monitor(11);
			temp = sat(c + (s >> iter));
			monitor(12);
			s = sat(s - (c >> iter));
			monitor(13);
			c = temp;
		}
		else {
			monitor(10);
			angle_accum = sat(angle_accum - atTable[iter]);
			monitor(11);
			temp = sat(c - (s >> iter));
			monitor(12);
			s = sat(s + (c >> iter));
			monitor(13);
			c = temp;
		}
	}
	return angle_accum;
}

int main(int argc, char** argv)
{
	int cosine;
	int sine;
	c =  cosine = -2047;
	s =  sine = (int)0xfffffffffffffff4;
	assert(s < 0 && (s & 0xfff) == 0xff4);
	int cord = cordic();
	printf("%03x, %03x,  %03x\n", cosine & 0xfff, sine & 0xfff, cord & 0xfff);
	return 0;
}
