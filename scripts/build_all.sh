#!/bin/zsh
# Builds all verilog files in the project
cd ../scratch/
vlog -work work ../verilog/*.v
if [ $? -ne 0 ]
then
	echo "Compilation of verilog files failed."
	exit $?
fi
