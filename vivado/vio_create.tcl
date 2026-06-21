# vio_create.tcl
# VIO (Virtual I/O) IP 생성: probe_out0 1bit (soft reset)
# Usage (Ubuntu 터미널):
#   vivado -mode batch -source vivado/vio_create.tcl
# Usage (Vivado TCL Console):
#   source {vivado/vio_create.tcl}

set PROJ [file normalize [file join [file dirname [info script]] \
          project_1/ov5640_hdmi.xpr]]

set opened_here 0
if {[current_project -quiet] eq ""} {
    open_project $PROJ
    set opened_here 1
}

create_ip -name vio \
          -vendor xilinx.com \
          -library ip \
          -version 3.0 \
          -module_name vio_0

set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN  {0} \
    CONFIG.C_NUM_PROBE_OUT {1} \
    CONFIG.C_PROBE_OUT0_WIDTH      {1} \
    CONFIG.C_PROBE_OUT0_INIT_VAL   {0x0} \
] [get_ips vio_0]

generate_target all [get_ips vio_0]

puts "INFO: vio_0 IP generated. Rerun compile order."
update_compile_order -fileset sources_1
save_project

if {$opened_here} {
    close_project
}
