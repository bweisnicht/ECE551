#!/bin/sh
gcc -std=c99 -lm -o angles angles.c
rm -fv ../scratch/angle_table.txt
./angles > ../scratch/angle_table.txt
rm -fv ../scratch/cordic.mem
./angles | cut -c 16-18,21-23,27-29 | sed 1d > ../scratch/cordic.mem
