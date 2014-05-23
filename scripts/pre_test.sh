#!/bin/zsh
# Builds all verilog files in the verilog directory, then attempts to run the specified testbench
if [ $# -ne 1 ]
then
	echo "Usage: pre_test.sh [testbench]"
	exit 1
fi
cd ../scratch/
vlog -work work ../verilog/*.v
if [ $? -ne 0 ]
then
	echo "Compilation of verilog files failed."
	exit $?
fi
yes $'run -all \n exit' | vsim -c -novopt "work.$1"
