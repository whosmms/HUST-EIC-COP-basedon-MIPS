open_project vga_snake.xpr
update_compile_order -fileset sources_1
open_bd_design vga_snake.srcs/sources_1/bd/vga_snake/vga_snake.bd
puts "TOP_SOURCE_FILES=[get_files -quiet *top.v]"
puts "TOP0_PINS=[get_bd_pins -quiet top_0/*]"
