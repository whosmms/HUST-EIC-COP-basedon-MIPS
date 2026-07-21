//Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2018.2 (win64) Build 2258646 Thu Jun 14 20:03:12 MDT 2018
//Date        : Mon Jun  8 14:52:10 2026
//Host        : xiaoxin running 64-bit major release  (build 9200)
//Command     : generate_target vga_snake_wrapper.bd
//Design      : vga_snake_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module vga_snake_wrapper
   (gpio_btn,
    gpio_status_ext,
    hsync,
    reset,
    sys_clock,
    usb_uart_rxd,
    usb_uart_txd,
    vga_b,
    vga_g,
    vga_r,
    vsync);
  input [4:0]gpio_btn;
  output [21:0]gpio_status_ext;
  output hsync;
  input reset;
  input sys_clock;
  input usb_uart_rxd;
  output usb_uart_txd;
  output [2:0]vga_b;
  output [2:0]vga_g;
  output [2:0]vga_r;
  output vsync;

  wire [4:0]gpio_btn;
  wire [21:0]gpio_status_ext;
  wire hsync;
  wire reset;
  wire sys_clock;
  wire usb_uart_rxd;
  wire usb_uart_txd;
  wire [2:0]vga_b;
  wire [2:0]vga_g;
  wire [2:0]vga_r;
  wire vsync;

  vga_snake vga_snake_i
       (.gpio_btn(gpio_btn),
        .gpio_status_ext(gpio_status_ext),
        .hsync(hsync),
        .reset(reset),
        .sys_clock(sys_clock),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd),
        .vga_b(vga_b),
        .vga_g(vga_g),
        .vga_r(vga_r),
        .vsync(vsync));
endmodule
