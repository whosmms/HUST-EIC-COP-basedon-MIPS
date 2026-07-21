`timescale 1ns / 1ps

module board_top #(
    parameter ONE_SECOND_CLKS = 100000000,
    parameter SEVENSEG_REFRESH_DIV = 100000
)(
    input  wire       sys_clock,
    input  wire       reset,
    input  wire [4:0] gpio_btn,
    input  wire       usb_uart_rxd,
    output wire       usb_uart_txd,
    output wire       hsync,
    output wire       vsync,
    output wire [2:0] vga_r,
    output wire [2:0] vga_g,
    output wire [2:0] vga_b,
    output reg  [6:0] seg,
    output reg        dp,
    output reg  [7:0] an
);

    wire [21:0] gpio_status_ext;

    vga_snake_wrapper u_system (
        .gpio_btn(gpio_btn),
        .gpio_status_ext(gpio_status_ext),
        .hsync(hsync),
        .reset(reset),
        .sys_clock(sys_clock),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd),
        .vga_b(vga_b),
        .vga_g(vga_g),
        .vga_r(vga_r),
        .vsync(vsync)
    );

    function [6:0] sevenseg_pattern;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: sevenseg_pattern = 7'b1000000;
                4'd1: sevenseg_pattern = 7'b1111001;
                4'd2: sevenseg_pattern = 7'b0100100;
                4'd3: sevenseg_pattern = 7'b0110000;
                4'd4: sevenseg_pattern = 7'b0011001;
                4'd5: sevenseg_pattern = 7'b0010010;
                4'd6: sevenseg_pattern = 7'b0000010;
                4'd7: sevenseg_pattern = 7'b1111000;
                4'd8: sevenseg_pattern = 7'b0000000;
                4'd9: sevenseg_pattern = 7'b0010000;
                default: sevenseg_pattern = 7'b1111111;
            endcase
        end
    endfunction

    reg [21:0] status_meta;
    reg [21:0] status_sync;

    always @(posedge sys_clock) begin
        status_meta <= gpio_status_ext;
        status_sync <= status_meta;
    end

    wire [15:0] score_value = status_sync[15:0];
    wire [1:0] game_state = status_sync[17:16];
    wire [3:0] lives_value = status_sync[21:18];

    reg [31:0] one_second_cnt;
    reg [3:0] elapsed_min;
    reg [5:0] elapsed_sec;

    always @(posedge sys_clock) begin
        if (!reset || game_state == 2'd0) begin
            one_second_cnt <= 32'd0;
            elapsed_min <= 4'd0;
            elapsed_sec <= 6'd0;
        end else if (game_state == 2'd1) begin
            if (one_second_cnt >= (ONE_SECOND_CLKS - 1)) begin
                one_second_cnt <= 32'd0;
                if (elapsed_min != 4'd9 || elapsed_sec != 6'd59) begin
                    if (elapsed_sec == 6'd59) begin
                        elapsed_sec <= 6'd0;
                        elapsed_min <= elapsed_min + 1'b1;
                    end else begin
                        elapsed_sec <= elapsed_sec + 1'b1;
                    end
                end
            end else begin
                one_second_cnt <= one_second_cnt + 1'b1;
            end
        end
    end

    wire [9:0] score_capped = (score_value > 16'd999) ? 10'd999 : score_value[9:0];
    wire [3:0] score_hundreds = score_capped / 10'd100;
    wire [3:0] score_tens = (score_capped / 10'd10) % 10'd10;
    wire [3:0] score_ones = score_capped % 10'd10;
    wire [3:0] display_lives = (lives_value > 4'd9) ? 4'd9 : lives_value;
    wire [3:0] display_sec_tens = elapsed_sec / 6'd10;
    wire [3:0] display_sec_ones = elapsed_sec % 6'd10;

    reg [31:0] sevenseg_refresh_cnt;
    reg [2:0] sevenseg_scan;
    reg [3:0] sevenseg_digit;

    always @(posedge sys_clock) begin
        if (!reset) begin
            sevenseg_refresh_cnt <= 32'd0;
            sevenseg_scan <= 3'd0;
        end else if (sevenseg_refresh_cnt >= (SEVENSEG_REFRESH_DIV - 1)) begin
            sevenseg_refresh_cnt <= 32'd0;
            sevenseg_scan <= sevenseg_scan + 1'b1;
        end else begin
            sevenseg_refresh_cnt <= sevenseg_refresh_cnt + 1'b1;
        end
    end

    always @(*) begin
        sevenseg_digit = 4'hF;
        dp = 1'b1;
        an = 8'b11111111;

        case (sevenseg_scan)
            3'd0: begin
                an = 8'b01111111;
                sevenseg_digit = display_lives;
            end
            3'd1: begin
                an = 8'b10111111;
                sevenseg_digit = elapsed_min;
                dp = 1'b0;
            end
            3'd2: begin
                an = 8'b11011111;
                sevenseg_digit = display_sec_tens;
            end
            3'd3: begin
                an = 8'b11101111;
                sevenseg_digit = display_sec_ones;
            end
            3'd4: begin
                an = 8'b11110111;
                sevenseg_digit = 4'hF;
            end
            3'd5: begin
                an = 8'b11111011;
                sevenseg_digit = score_hundreds;
            end
            3'd6: begin
                an = 8'b11111101;
                sevenseg_digit = score_tens;
            end
            default: begin
                an = 8'b11111110;
                sevenseg_digit = score_ones;
            end
        endcase

        seg = sevenseg_pattern(sevenseg_digit);
    end

endmodule
