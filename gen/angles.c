// Compile with gcc -std=c99 -lm angles.c
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

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

static inline int sat(int i)
{
	if (i < -2048)
		return -2048;
	else if (i > 2047)
		return 2047;
	else
		return i;
}

int cordic(int c, int s)
{
	int angle_accum;
	if (c < 0) {
		if (s < 0)
			angle_accum = -2048;
		else
			angle_accum = 2047;

		c = sat(-c);
		s = sat(-s);
	}
	else {
		angle_accum = 0;
	}

	for (int iter = 0; iter < 12; ++iter) {
		if (s >= 0) {
			angle_accum = sat(angle_accum + atTable[iter]);
			int temp = sat(c + (s >> iter));
			s = sat(s - (c >> iter));
			c = temp;
		}
		else {
			angle_accum = sat(angle_accum - atTable[iter]);
			int temp = sat(c - (s >> iter));
			s = sat(s + (c >> iter));
			c = temp;
		}
	}
	return angle_accum;
}

int main(int argc, char** argv)
{
	printf("   deg, fixed, cos, sin, cord\n");
	for (int a = -2048; a < 2048; ++a) {
		double rads = (double)a / 2048.0 * pi;
		double degs = rads / pi * 180.0;
		int cosine = (int)(cos(rads) * 2048.0);
		int sine = (int)(sin(rads) * 2048.0);
		int cord = cordic(cosine, sine);
		printf("% 06.1f,   %03x, %03x, %03x,  %03x\n", degs, a & 0xfff, cosine & 0xfff, sine & 0xfff, cord & 0xfff);
	}
	return 0;
}
