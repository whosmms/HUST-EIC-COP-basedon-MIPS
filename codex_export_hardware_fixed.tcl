set project_dir [pwd]
set bd_file     "$project_dir/vga_snake.srcs/sources_1/bd/vga_snake/vga_snake.bd"
set wrapper_file "$project_dir/vga_snake.srcs/sources_1/bd/vga_snake/hdl/vga_snake_wrapper.v"
set wrapper_dcp  "$project_dir/vga_snake.runs/impl_1/vga_snake_wrapper_routed.dcp"
set hdf_file     "$project_dir/vga_snake.sdk/vga_snake_wrapper.hdf"

if {[catch {current_project} current_project_name]} {
    open_project "$project_dir/vga_snake.xpr"
} else {
    puts "Using already-open project: $current_project_name"
}

set_property is_enabled true [get_files -quiet $bd_file]
set_property is_enabled true [get_files -quiet $wrapper_file]
set_property top vga_snake_wrapper [get_filesets sources_1]
set_property top_lib xil_defaultlib [get_filesets sources_1]
set_property top_file $wrapper_file [get_filesets sources_1]
update_compile_order -fileset sources_1
generate_target all [get_files -quiet $bd_file]
if {[file exists $wrapper_dcp]} {
    open_checkpoint $wrapper_dcp
} else {
    open_run impl_1
}
file mkdir $project_dir/vga_snake.sdk
write_hwdef -force -file $hdf_file
puts "EXPORTED_HDF=[file normalize $hdf_file]"
