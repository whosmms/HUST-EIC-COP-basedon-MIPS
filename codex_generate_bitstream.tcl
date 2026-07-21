open_project vga_snake.xpr
if {[llength [get_files -quiet vga_snake.srcs/sources_1/new/board_top.v]] == 0} {
  add_files -norecurse vga_snake.srcs/sources_1/new/board_top.v
}
set_property is_enabled true [get_files vga_snake.srcs/sources_1/bd/vga_snake/vga_snake.bd]
set_property is_enabled true [get_files vga_snake.srcs/sources_1/bd/vga_snake/hdl/vga_snake_wrapper.v]
set_property top board_top [get_filesets sources_1]
set_property top_lib xil_defaultlib [get_filesets sources_1]
set_property top_file vga_snake.srcs/sources_1/new/board_top.v [get_filesets sources_1]
update_compile_order -fileset sources_1

set bd_file [get_files vga_snake.srcs/sources_1/bd/vga_snake/vga_snake.bd]
open_bd_design $bd_file
set_property -dict [list CONFIG.ENEMY_MIN_LEN {4} CONFIG.ENEMY_MAX_LEN {8}] [get_bd_cells top_0]
validate_bd_design
save_bd_design
generate_target all $bd_file
export_ip_user_files -of_objects $bd_file -no_script -sync -force -quiet

foreach top_ip_run [get_runs -quiet vga_snake_top_*_synth_1] {
  reset_run $top_ip_run
  launch_runs $top_ip_run -jobs 2
  wait_on_run $top_ip_run
  set top_ip_status [get_property STATUS [get_runs $top_ip_run]]
  puts "TOP_IP_SYNTH_STATUS($top_ip_run)=$top_ip_status"
  if {[string first "Complete" $top_ip_status] < 0} {
    error "$top_ip_run did not complete"
  }
}
reset_run synth_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
set synth_status [get_property STATUS [get_runs synth_1]]
set impl_status [get_property STATUS [get_runs impl_1]]
puts "SYNTH_STATUS=$synth_status"
puts "IMPL_STATUS=$impl_status"
if {[string first "Complete" $synth_status] < 0} {
  error "synth_1 did not complete"
}
if {[string first "Complete" $impl_status] < 0} {
  error "impl_1 did not complete"
}
