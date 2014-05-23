#!/bin/sh
if [ $# -ne 1 ]
then
	echo "Usage: synthesize <synth_script.dc>"
	exit 1
fi
yes 'exit' | design_vision -no_gui -f $1
