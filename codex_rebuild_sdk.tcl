# Rebuild SDK BSP + app after hardware export.
set project_dir [pwd]
set workspace   "$project_dir/vga_snake.sdk"
set hdf_file    "$workspace/vga_snake_wrapper.hdf"
set hw_proj     "VGA_SNAKE"
set bsp_proj    "vga_snake_app_bsp"
set app_proj    "vga_snake_app"

setws $workspace
puts ">>> workspace: $workspace"

# 1. Update the hardware specification with the freshly exported HDF
puts ">>> updatehw -hw $hw_proj -newhwspec $hdf_file"
updatehw -hw $hw_proj -newhwspec $hdf_file

# 2. Regenerate the BSP (refreshes xparameters.h, etc.)
puts ">>> regenbsp -bsp $bsp_proj"
regenbsp -bsp $bsp_proj

# 3. Clean + build everything
puts ">>> projects -clean -type all"
projects -clean -type all
puts ">>> projects -build -type all"
projects -build -type all

puts "SDK_REBUILD_DONE"
