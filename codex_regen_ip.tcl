open_project vga_snake.xpr

set bd_file [get_files vga_snake.srcs/sources_1/bd/vga_snake/vga_snake.bd]
puts ">>> bd_file = $bd_file"

# Step 1: reset BD output products (forces regen of synth/sim wrapper)
puts ">>> reset_target on BD"
reset_target all $bd_file

# Step 2: regenerate BD output products. With the cached IP xml/stub now showing
# gpio_status[21:0], the synth wrapper and AXI GPIO instance should resolve to 22.
puts ">>> generate_target on BD"
generate_target all $bd_file

# Step 3: refresh ip_user_files (sim user files etc.)
puts ">>> export_ip_user_files"
export_ip_user_files -of_objects $bd_file -no_script -sync -force -quiet

# Step 4: reset existing IP synth runs so they re-synthesize the updated IP
set ip_runs [get_runs -quiet -filter {SRCSET == sources_1 && IS_SYNTHESIS}]
foreach r $ip_runs {
    set rn [get_property NAME $r]
    if {[string first "axi_gpio" $rn] >= 0 || [string first "vga_snake_top_0" $rn] >= 0} {
        puts ">>> resetting IP run $rn"
        reset_run $r
    }
}

# Step 5: recreate the HDL wrapper
puts ">>> recreating wrapper"
make_wrapper -files $bd_file -top -force
set wrap_path vga_snake.srcs/sources_1/bd/vga_snake/hdl/vga_snake_wrapper.v
if {[get_files -quiet $wrap_path] eq ""} {
    add_files -norecurse $wrap_path
}
update_compile_order -fileset sources_1
set_property top vga_snake_wrapper [get_filesets sources_1]

puts "REGEN_DONE"
close_project
