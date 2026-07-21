set fp [open "vivado_help.txt" w]
puts $fp "==== update_module_reference ===="
puts $fp [help update_module_reference]
puts $fp "==== get_bd_cells ===="
close $fp
