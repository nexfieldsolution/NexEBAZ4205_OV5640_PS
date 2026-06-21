# NexEBAZ4205_OV5640_PS - Vivado project creation
# 실행: vivado -mode batch -source vivado/build.tcl
# 출력: vivado/project_1/

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set ROOT_DIR   [file normalize [file join $SCRIPT_DIR ..]]
set PROJ_DIR   [file join $SCRIPT_DIR project_1]

create_project -force ov5640_ps $PROJ_DIR -part xc7z020clg400-1
set_property target_language Verilog [current_project]

# Source files
add_files [glob $ROOT_DIR/src/*.v]
add_files [glob $ROOT_DIR/src/i2c_master/*.v]

# VHDL: rgb2dvi
add_files [glob $ROOT_DIR/src/rgb2dvi/*.vhd]
set_property file_type VHDL [get_files $ROOT_DIR/src/rgb2dvi/*.vhd]

# Constraints
add_files -fileset constrs_1 $ROOT_DIR/constraints/ebaz4205_ov5640.xdc

# Top module
set_property top top_ov5640_ps [current_fileset]
update_compile_order -fileset sources_1

puts "INFO: project created → $PROJ_DIR"
puts "INFO: run synthesis: launch_runs synth_1 -jobs 4"
