set script_dir [file normalize [file dirname [info script]]]
set repo_dir   [file normalize [file join $script_dir ..]]
set proj_name  "basys3_slidepuzzle"
set proj_dir   [file join $repo_dir "vivado_project_basys3"]

create_project -force $proj_name $proj_dir -part xc7a35tcpg236-1

add_files -fileset sources_1 [list \
  $repo_dir/hdl_basys3/top_basys3.v \
  $repo_dir/hdl/pad_input.v \
  $repo_dir/src/puzzle_core.v \
  $repo_dir/src/vga_timing.v \
]

add_files -fileset sources_1 [list \
  $repo_dir/src/image.mem \
  $repo_dir/src/palette.mem \
]
set_property file_type {Memory Initialization Files} \
  [get_files [list $repo_dir/src/image.mem $repo_dir/src/palette.mem]]

set_property top top_basys3 [current_fileset]

add_files -fileset constrs_1 [list $repo_dir/constraints_basys3/basys3_slidepuzzle.xdc]

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_vga
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {100} \
  CONFIG.NUM_OUT_CLKS {1} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25.175} \
] [get_ips clk_wiz_vga]
generate_target {instantiation_template} \
  [get_files $proj_dir/$proj_name.srcs/sources_1/ip/clk_wiz_vga/clk_wiz_vga.xci]

update_compile_order -fileset sources_1

puts "Project '$proj_name' created at $proj_dir"
puts "Open it in Vivado, then run Generate Bitstream."
