`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/31 19:12:55
// Design Name: 
// Module Name: vga_timing
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
// vga_timing.v
// 640x480 @60Hz timing generator
module vga_timing (
    input  wire clk_pix,      // 25 MHz pixel clock
    input  wire rst_n,        // active low reset
    output reg  hsync,
    output reg  vsync,
    output wire active_video,
    output reg  [9:0] pixel_x, // 0..639
    output reg  [8:0] pixel_y  // 0..479
);

    // Timing params for 640x480@60
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; //800

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; //525

    // counters
    reg [9:0] hcnt;
    reg [9:0] vcnt; // needs to count to 524

    always @(posedge clk_pix or negedge rst_n) begin
        if (!rst_n) begin
            hcnt <= 0;
            vcnt <= 0;
            hsync <= 1;
            vsync <= 1;
            pixel_x <= 0;
            pixel_y <= 0;
        end else begin
            if (hcnt == H_TOTAL - 1) begin
                hcnt <= 0;
                if (vcnt == V_TOTAL - 1)
                    vcnt <= 0;
                else
                    vcnt <= vcnt + 1;
            end else begin
                hcnt <= hcnt + 1;
            end

            // HS: active during sync pulse (standard active low)
            if (hcnt >= (H_VISIBLE + H_FRONT) && hcnt < (H_VISIBLE + H_FRONT + H_SYNC))
                hsync <= 0;
            else
                hsync <= 1;

            // VS
            if (vcnt >= (V_VISIBLE + V_FRONT) && vcnt < (V_VISIBLE + V_FRONT + V_SYNC))
                vsync <= 0;
            else
                vsync <= 1;

            // pixel coordinates within visible area
            if (hcnt < H_VISIBLE)
                pixel_x <= hcnt;
            else
                pixel_x <= 0;

            if (vcnt < V_VISIBLE)
                pixel_y <= vcnt;
            else
                pixel_y <= 0;
        end
    end

    assign active_video = (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);

endmodule
