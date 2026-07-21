# Nexys DDR4 — VGA and board signal XDC template
# Replace <PIN_*> placeholders with actual board pin names from your board reference.
# Do NOT map gpio_status (it's read by MicroBlaze via AXI GPIO).

# Clock and reset (external ports in BD: sys_clock, reset)
# sys_clock: external clock input used by clk_wiz
set_property PACKAGE_PIN E3 [get_ports sys_clock]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clock]

set_property PACKAGE_PIN C12 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

# VGA signals (external ports named in BD as hsync, vsync, vga_r, vga_g, vga_b)
// HS / VS from user mapping
set_property PACKAGE_PIN B11 [get_ports hsync]
set_property IOSTANDARD LVCMOS33 [get_ports hsync]

set_property PACKAGE_PIN B12 [get_ports vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vsync]

# Red bits vga_r[2]..vga_r[0]
// VGA Red bits (user provided: A4 C5 B4 A3) — using first three for vga_r[2:0]
set_property PACKAGE_PIN A4 [get_ports {vga_r[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN C5 [get_ports {vga_r[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN B4 [get_ports {vga_r[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[0]}]
# note: A3 from your list left unused (top.v has 3-bit red)

# Green bits
// VGA Green bits (user provided: A6 B6 A5 C6) — using first three for vga_g[2:0]
set_property PACKAGE_PIN A6 [get_ports {vga_g[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN B6 [get_ports {vga_g[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN A5 [get_ports {vga_g[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[0]}]
# note: C6 from your list left unused (top.v has 3-bit green)

# Blue bits
// VGA Blue bits (user provided: D8 D7 C7 B7) — using first three for vga_b[2:0]
set_property PACKAGE_PIN D8 [get_ports {vga_b[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN D7 [get_ports {vga_b[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN C7 [get_ports {vga_b[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[0]}]
# note: B7 from your list left unused (top.v has 3-bit blue)

# Eight-digit seven-segment display, active-low.
# seg[0..6] = CA, CB, CC, CD, CE, CF, CG.
set_property PACKAGE_PIN T10 [get_ports {seg[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]
set_property PACKAGE_PIN R10 [get_ports {seg[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]
set_property PACKAGE_PIN K16 [get_ports {seg[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]
set_property PACKAGE_PIN K13 [get_ports {seg[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]
set_property PACKAGE_PIN P15 [get_ports {seg[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]
set_property PACKAGE_PIN T11 [get_ports {seg[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]
set_property PACKAGE_PIN L18 [get_ports {seg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]
set_property PACKAGE_PIN H15 [get_ports dp]
set_property IOSTANDARD LVCMOS33 [get_ports dp]

# an[7] is the leftmost digit and an[0] is the rightmost digit in this design.
set_property PACKAGE_PIN U13 [get_ports {an[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[7]}]
set_property PACKAGE_PIN K2 [get_ports {an[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[6]}]
set_property PACKAGE_PIN T14 [get_ports {an[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[5]}]
set_property PACKAGE_PIN P14 [get_ports {an[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[4]}]
set_property PACKAGE_PIN J14 [get_ports {an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]
set_property PACKAGE_PIN T9 [get_ports {an[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
set_property PACKAGE_PIN J18 [get_ports {an[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
set_property PACKAGE_PIN J17 [get_ports {an[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]

# Optional: Drive strength or SLEW can be set if needed
# set_property DRIVE 8 [get_ports hsync]
# set_property SLEW SLOW [get_ports hsync]

# Push buttons (gpio_btn[4:0] connected to AXI GPIO Channel A)
# Nexys4 DDR push_buttons_5bits order:
# gpio_btn[0]=CENTER, [1]=UP, [2]=LEFT, [3]=RIGHT, [4]=DOWN
# These button pins come from constrs_1/new/limlitdoc.xdc in this project
# btn_center-> N17
# btn_up    -> M18
# btn_left  -> P17
# btn_right -> M17
# btn_down  -> P18
set_property PACKAGE_PIN N17 [get_ports {gpio_btn[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_btn[0]}]
set_property PACKAGE_PIN M18 [get_ports {gpio_btn[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_btn[1]}]
set_property PACKAGE_PIN P17 [get_ports {gpio_btn[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_btn[2]}]
set_property PACKAGE_PIN M17 [get_ports {gpio_btn[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_btn[3]}]
set_property PACKAGE_PIN P18 [get_ports {gpio_btn[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_btn[4]}]

# Notes:
# - Replace each <PIN_*> with the actual pin name (e.g. "J18" or "W5") from Nexys DDR4 reference.
# - For vector ports use the same bit indices shown in BD (vga_r[2:0]).
# - Do not map gpio_status to physical pins — it's read by the processor via AXI GPIO.
# - After editing, in Vivado: Flow Navigator -> Generate Bitstream (or at least Validate Design -> Regenerate Output Products -> Create HDL Wrapper if needed).

# Optional TCL loop to help generate per-bit constraints (example usage inside Vivado Tcl console):
# set pins {<PIN_VGA_R2> <PIN_VGA_R1> <PIN_VGA_R0>}
# for {set i 0} {$i < [llength $pins]} {incr i} {
#   set p [lindex $pins $i]
#   set_property PACKAGE_PIN $p [get_ports {vga_r[$i]}]
#   set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[$i]}]
# }
