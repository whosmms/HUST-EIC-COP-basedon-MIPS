// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.2 (win64) Build 2258646 Thu Jun 14 20:03:12 MDT 2018
// Date        : Mon Jun  8 14:55:37 2026
// Host        : xiaoxin running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               D:/vivadoproject/vga_snake/vga_snake.srcs/sources_1/bd/vga_snake/ip/vga_snake_top_0_1/vga_snake_top_0_1_stub.v
// Design      : vga_snake_top_0_1
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "top,Vivado 2018.2" *)
module vga_snake_top_0_1(clk_pix, rst_n, gpio_btn, hsync, vsync, vga_r, vga_g, 
  vga_b, gpio_status)
/* synthesis syn_black_box black_box_pad_pin="clk_pix,rst_n,gpio_btn[4:0],hsync,vsync,vga_r[2:0],vga_g[2:0],vga_b[2:0],gpio_status[21:0]" */;
  input clk_pix;
  input rst_n;
  input [4:0]gpio_btn;
  output hsync;
  output vsync;
  output [2:0]vga_r;
  output [2:0]vga_g;
  output [2:0]vga_b;
  output [21:0]gpio_status;
endmodule
