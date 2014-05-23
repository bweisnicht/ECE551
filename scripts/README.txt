- build_all.sh builds all verilog files. You can use it as a quick and dirty check that things compile.

- synthesize.sh takes the name of a Design Vision (.dc) script to build.
  Design Vision scripts should write their .vg files to the synth directory.

- pre_test.sh takes the name of a testbench module and does pre-synthesis testing.

- post_test.sh takes the name of a testbench and does post-syntheis testing. It assumes you have already synthesized
  the modules and that the synthesized .vg files are in the synth directory.
