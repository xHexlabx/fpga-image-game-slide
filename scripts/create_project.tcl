set script_dir [file normalize [file dirname [info script]]]
set repo_dir   [file normalize [file join $script_dir ..]]
set proj_name  "ax7010_slidepuzzle"
set proj_dir   [file join $repo_dir "vivado_project"]

create_project -force $proj_name $proj_dir -part xc7z010clg400-1

add_files -fileset sources_1 [glob $repo_dir/hdl/*.v]
add_files -fileset sources_1 [list \
  $repo_dir/src/puzzle_core.v \
  $repo_dir/src/vga_timing.v \
]

add_files -fileset sources_1 [list \
  $repo_dir/src/image.mem \
  $repo_dir/src/palette.mem \
]
set_property file_type {Memory Initialization Files} \
  [get_files [list $repo_dir/src/image.mem $repo_dir/src/palette.mem]]

set_property top top [current_fileset]

add_files -fileset constrs_1 [glob $repo_dir/constraints/*.xdc]

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_video
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {50} \
  CONFIG.NUM_OUT_CLKS {2} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25.175} \
  CONFIG.CLKOUT2_USED {true} \
  CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {125.875} \
] [get_ips clk_wiz_video]
generate_target {instantiation_template} \
  [get_files $proj_dir/$proj_name.srcs/sources_1/ip/clk_wiz_video/clk_wiz_video.xci]

update_compile_order -fileset sources_1

puts "Project '$proj_name' created at $proj_dir"
puts "Open it in Vivado, then run Synthesis -> Implementation -> Generate Bitstream."
