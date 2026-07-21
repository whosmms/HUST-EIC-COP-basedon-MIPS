-- Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2018.2 (win64) Build 2258646 Thu Jun 14 20:03:12 MDT 2018
-- Date        : Mon Jun  8 14:55:29 2026
-- Host        : xiaoxin running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
--               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ vga_snake_top_0_1_stub.vhdl
-- Design      : vga_snake_top_0_1
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tcsg324-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix is
  Port ( 
    clk_pix : in STD_LOGIC;
    rst_n : in STD_LOGIC;
    gpio_btn : in STD_LOGIC_VECTOR ( 4 downto 0 );
    hsync : out STD_LOGIC;
    vsync : out STD_LOGIC;
    vga_r : out STD_LOGIC_VECTOR ( 2 downto 0 );
    vga_g : out STD_LOGIC_VECTOR ( 2 downto 0 );
    vga_b : out STD_LOGIC_VECTOR ( 2 downto 0 );
    gpio_status : out STD_LOGIC_VECTOR ( 21 downto 0 )
  );

end decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix;

architecture stub of decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_pix,rst_n,gpio_btn[4:0],hsync,vsync,vga_r[2:0],vga_g[2:0],vga_b[2:0],gpio_status[21:0]";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "top,Vivado 2018.2";
begin
end;
