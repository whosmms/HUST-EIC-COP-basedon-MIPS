`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/31 19:13:52
// Design Name: 
// Module Name: grid_renderer
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
// grid_renderer.v
// Map pixel coordinates -> grid cell -> color output
module grid_renderer #(
    parameter CELL_W = 16,
    parameter CELL_H = 16
)(
    input  wire        clk_pix,      // pixel clock (25MHz)
    input  wire        rst_n,
    input  wire        active,
    input  wire [9:0]  pixel_x,
    input  wire [8:0]  pixel_y,
    // query to snake_game
    output wire [5:0]  cell_x,       // 0..39
    output wire [4:0]  cell_y,       // 0..29
    input  wire [2:0]  cell_state,   // 000 empty, 001 body, 010 head, 011 red, 100 yellow, 101 blue, 110 enemy head, 111 enemy body
    // RGB outputs (3 bits per color)
    output reg  [2:0]  rgb_r,
    output reg  [2:0]  rgb_g,
    output reg  [2:0]  rgb_b
);

    // compute cell coordinates by division by CELL_W/H (powers of two assumed)
    // CELL_W=16 -> >>4
    assign cell_x = pixel_x[9:4]; // pixel_x / 16
    assign cell_y = pixel_y[8:4]; // pixel_y / 16

    // Optionally draw cell borders: thin grid lines
    wire [3:0] local_x = pixel_x[3:0]; // within cell 0..15
    wire [3:0] local_y = pixel_y[3:0];
    wire border = (local_x == 0) || (local_y == 0);

    always @(posedge clk_pix or negedge rst_n) begin
        if (!rst_n) begin
            rgb_r <= 3'b000; rgb_g <= 3'b000; rgb_b <= 3'b000;
        end else begin
            if (!active) begin
                rgb_r <= 3'b000; rgb_g <= 3'b000; rgb_b <= 3'b000;
            end else begin
                case (cell_state)
                    3'b000: begin // empty
                        if (border) begin
                            rgb_r <= 3'b010; rgb_g <= 3'b010; rgb_b <= 3'b010; // light grey grid line
                        end else begin
                            rgb_r <= 3'b000; rgb_g <= 3'b000; rgb_b <= 3'b000; // black background
                        end
                    end
                    3'b001: begin // player body -> green
                        rgb_r <= 3'b000; rgb_g <= 3'b111; rgb_b <= 3'b000;
                    end
                    3'b010: begin // player head -> white
                        rgb_r <= 3'b111; rgb_g <= 3'b111; rgb_b <= 3'b111;
                    end
                    3'b011: begin // red food
                        rgb_r <= 3'b111; rgb_g <= 3'b000; rgb_b <= 3'b000;
                    end
                    3'b100: begin // yellow food
                        rgb_r <= 3'b111; rgb_g <= 3'b111; rgb_b <= 3'b000;
                    end
                    3'b101: begin // blue life food
                        rgb_r <= 3'b000; rgb_g <= 3'b000; rgb_b <= 3'b111;
                    end
                    3'b110: begin // enemy head -> magenta
                        rgb_r <= 3'b111; rgb_g <= 3'b000; rgb_b <= 3'b111;
                    end
                    3'b111: begin // enemy body -> dark magenta
                        rgb_r <= 3'b011; rgb_g <= 3'b000; rgb_b <= 3'b011;
                    end
                    default: begin
                        rgb_r <= 3'b000; rgb_g <= 3'b000; rgb_b <= 3'b000;
                    end
                endcase
            end
        end
    end

endmodule
