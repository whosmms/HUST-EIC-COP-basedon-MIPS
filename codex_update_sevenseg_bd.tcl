open_project vga_snake.xpr

set board_top_file [get_files -quiet D:/Xilinx/vga_snake/vga_snake.srcs/sources_1/new/board_top.v]
if {[llength $board_top_file] == 0} {
  add_files -norecurse vga_snake.srcs/sources_1/new/board_top.v
}
update_compile_order -fileset sources_1
open_bd_design vga_snake.srcs/sources_1/bd/vga_snake/vga_snake.bd

foreach net_name {top_0_seg top_0_dp top_0_an} {
  if {[llength [get_bd_nets -quiet $net_name]] != 0} {
    delete_bd_objs [get_bd_nets $net_name]
  }
}

foreach port_name {seg dp an} {
  if {[llength [get_bd_ports -quiet $port_name]] != 0} {
    delete_bd_objs [get_bd_ports $port_name]
  }
}

if {[llength [get_bd_ports -quiet gpio_status_ext]] == 0} {
  create_bd_port -dir O -from 21 -to 0 gpio_status_ext
}
if {[llength [get_bd_nets -quiet top_0_gpio_status]] == 0} {
  connect_bd_net -net top_0_gpio_status [get_bd_pins axi_gpio_0/gpio2_io_i] [get_bd_pins top_0/gpio_status]
}
if {[llength [get_bd_nets -quiet -of_objects [get_bd_ports gpio_status_ext]]] == 0} {
  connect_bd_net -net top_0_gpio_status [get_bd_ports gpio_status_ext] [get_bd_pins top_0/gpio_status]
}

validate_bd_design
save_bd_design
generate_target all [get_files vga_snake.srcs/sources_1/bd/vga_snake/vga_snake.bd]
update_compile_order -fileset sources_1
