#!/bin/zsh
# Builds all testbench files in the verilog directory and synthesized verilog in the synth directory,
# then attempts to run the specified testbench
if [ $# -ne 1 ]
then
	echo "Usage: post_test.sh [testbench]"
	exit 1
fi
cd ../scratch/
vlog -work work ../verilog/*_tb.v
vlog -work work ../synth/*.vg
if [ $? -ne 0 ]
then
	echo "Compilation of verilog files failed."
	exit $?
fi
yes $'run -all \n exit' | vsim -c +notimingchecks -L /filespace/people/m/mrkline/Public/ece551/TSMC_lib -t ns -novopt "work.$1"
