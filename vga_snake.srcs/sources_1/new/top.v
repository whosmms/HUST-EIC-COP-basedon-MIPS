`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/31 19:11:07
// Design Name: 
// Module Name: top
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
// top.v
// Top-level: connect vga_timing, grid_renderer, snake_game
module top (
    input  wire clk_pix,    // 25 MHz pixel clock from Clocking Wizard
    input  wire rst_n,      // active-low reset (global)
    // direct AXI GPIO connection
    // Nexys4 DDR push_buttons_5bits: gpio_btn[0]=center, [1]=up,
    // [2]=left, [3]=right, [4]=down.
    input  wire [4:0] gpio_btn,
    // VGA outputs (connect these pins in XDC)
    output wire hsync,
    output wire vsync,
    output wire [2:0] vga_r,
    output wire [2:0] vga_g,
    output wire [2:0] vga_b,
    // Nexys4 DDR eight-digit seven-segment display, active-low.
    output reg  [6:0] seg,
    output reg        dp,
    output reg  [7:0] an,
    // status/debug packed for AXI GPIO input
    // gpio_status[15:0] = score, gpio_status[17:16] = state, gpio_status[21:18] = lives
    output wire [21:0] gpio_status
);

    //==================================================
    // parameters
    //==================================================
    parameter TICK_DIV = 2500000; // 25MHz / 2.5e6 ~= 10 Hz movement tick (adjustable)
    parameter BUTTON_DEBOUNCE_CLKS = 250000; // 10 ms at 25 MHz
    parameter ONE_SECOND_CLKS = 25000000;
    parameter SEVENSEG_REFRESH_DIV = 25000;
    parameter ENEMY_SPAWN_MIN_TICKS = 40;
    parameter ENEMY_SPAWN_RANDOM_MASK = 16'h003F;
    parameter ENEMY_MIN_LEN = 4;
    parameter ENEMY_MAX_LEN = 8;

    localparam DIR_UP    = 2'b00;
    localparam DIR_DOWN  = 2'b01;
    localparam DIR_LEFT  = 2'b10;
    localparam DIR_RIGHT = 2'b11;

    //==================================================
    // 按键同步、去抖和按下事件
    //==================================================
    reg [4:0] btn_sync0;
    reg [4:0] btn_sync1;
    reg [4:0] btn_stable;
    reg [4:0] btn_stable_d;
    reg [31:0] btn_debounce_cnt;
    reg pause_reg;
    reg reset_game_reg;
    reg [1:0] dir_req;
    reg dir_req_valid;

    wire [15:0] score;
    wire [1:0] state;
    wire [3:0] lives;

    wire [4:0] btn_rise = btn_stable & ~btn_stable_d;
    wire btn_center_event = btn_rise[0];
    wire btn_up_event     = btn_rise[1];
    wire btn_left_event   = btn_rise[2];
    wire btn_right_event  = btn_rise[3];
    wire btn_down_event   = btn_rise[4];

    wire start = (state == 2'd0) ? dir_req_valid : 1'b0;
    wire pause  = pause_reg;
    wire reset_game = reset_game_reg;
    wire [1:0] status_state = (pause && (state == 2'd1)) ? 2'd2 : state;

    function [6:0] sevenseg_pattern;
        input [3:0] value;
        begin
            case (value)
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

    function gameover_letter_pixel;
        input [3:0] ch;
        input [2:0] fx;
        input [2:0] fy;
        reg [4:0] row;
        begin
            row = 5'b00000;
            case (ch)
                4'd0: begin // G
                    case (fy)
                        3'd0: row = 5'b11111;
                        3'd1: row = 5'b10000;
                        3'd2: row = 5'b10000;
                        3'd3: row = 5'b10111;
                        3'd4: row = 5'b10001;
                        3'd5: row = 5'b10001;
                        3'd6: row = 5'b11111;
                    endcase
                end
                4'd1: begin // A
                    case (fy)
                        3'd0: row = 5'b01110;
                        3'd1: row = 5'b10001;
                        3'd2: row = 5'b10001;
                        3'd3: row = 5'b11111;
                        3'd4: row = 5'b10001;
                        3'd5: row = 5'b10001;
                        3'd6: row = 5'b10001;
                    endcase
                end
                4'd2: begin // M
                    case (fy)
                        3'd0: row = 5'b10001;
                        3'd1: row = 5'b11011;
                        3'd2: row = 5'b10101;
                        3'd3: row = 5'b10101;
                        3'd4: row = 5'b10001;
                        3'd5: row = 5'b10001;
                        3'd6: row = 5'b10001;
                    endcase
                end
                4'd3: begin // E
                    case (fy)
                        3'd0: row = 5'b11111;
                        3'd1: row = 5'b10000;
                        3'd2: row = 5'b10000;
                        3'd3: row = 5'b11110;
                        3'd4: row = 5'b10000;
                        3'd5: row = 5'b10000;
                        3'd6: row = 5'b11111;
                    endcase
                end
                4'd4: begin // O
                    case (fy)
                        3'd0: row = 5'b01110;
                        3'd1: row = 5'b10001;
                        3'd2: row = 5'b10001;
                        3'd3: row = 5'b10001;
                        3'd4: row = 5'b10001;
                        3'd5: row = 5'b10001;
                        3'd6: row = 5'b01110;
                    endcase
                end
                4'd5: begin // V
                    case (fy)
                        3'd0: row = 5'b10001;
                        3'd1: row = 5'b10001;
                        3'd2: row = 5'b10001;
                        3'd3: row = 5'b10001;
                        3'd4: row = 5'b10001;
                        3'd5: row = 5'b01010;
                        3'd6: row = 5'b00100;
                    endcase
                end
                default: begin // R
                    case (fy)
                        3'd0: row = 5'b11110;
                        3'd1: row = 5'b10001;
                        3'd2: row = 5'b10001;
                        3'd3: row = 5'b11110;
                        3'd4: row = 5'b10100;
                        3'd5: row = 5'b10010;
                        3'd6: row = 5'b10001;
                    endcase
                end
            endcase

            case (fx)
                3'd0: gameover_letter_pixel = row[4];
                3'd1: gameover_letter_pixel = row[3];
                3'd2: gameover_letter_pixel = row[2];
                3'd3: gameover_letter_pixel = row[1];
                3'd4: gameover_letter_pixel = row[0];
                default: gameover_letter_pixel = 1'b0;
            endcase
        end
    endfunction

    function gameover_pixel;
        input [5:0] tx;
        input [2:0] ty;
        reg [3:0] ch;
        reg [2:0] fx;
        begin
            ch = 4'd15;
            fx = 3'd7;
            if (tx < 6'd5) begin
                ch = 4'd0; fx = tx[2:0];
            end else if ((tx >= 6'd6) && (tx < 6'd11)) begin
                ch = 4'd1; fx = tx - 6'd6;
            end else if ((tx >= 6'd12) && (tx < 6'd17)) begin
                ch = 4'd2; fx = tx - 6'd12;
            end else if ((tx >= 6'd18) && (tx < 6'd23)) begin
                ch = 4'd3; fx = tx - 6'd18;
            end else if ((tx >= 6'd24) && (tx < 6'd29)) begin
                ch = 4'd4; fx = tx - 6'd24;
            end else if ((tx >= 6'd30) && (tx < 6'd35)) begin
                ch = 4'd5; fx = tx - 6'd30;
            end else if ((tx >= 6'd36) && (tx < 6'd41)) begin
                ch = 4'd3; fx = tx - 6'd36;
            end else if ((tx >= 6'd42) && (tx < 6'd47)) begin
                ch = 4'd6; fx = tx - 6'd42;
            end
            gameover_pixel = (ch != 4'd15) && gameover_letter_pixel(ch, fx, ty);
        end
    endfunction

    // 多键同时产生上升沿时使用固定优先级，正常单键操作不受影响。
    always @(*) begin
        dir_req = DIR_RIGHT;
        dir_req_valid = 1'b0;

        if (btn_up_event) begin
            dir_req = DIR_UP;
            dir_req_valid = 1'b1;
        end else if (btn_down_event) begin
            dir_req = DIR_DOWN;
            dir_req_valid = 1'b1;
        end else if (btn_left_event) begin
            dir_req = DIR_LEFT;
            dir_req_valid = 1'b1;
        end else if (btn_right_event) begin
            dir_req = DIR_RIGHT;
            dir_req_valid = 1'b1;
        end
    end

    always @(posedge clk_pix or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync0 <= 5'b00000;
            btn_sync1 <= 5'b00000;
            btn_stable <= 5'b00000;
            btn_stable_d <= 5'b00000;
            btn_debounce_cnt <= 32'd0;
        end else begin
            btn_sync0 <= gpio_btn;
            btn_sync1 <= btn_sync0;
            btn_stable_d <= btn_stable;

            if (btn_sync1 == btn_stable) begin
                btn_debounce_cnt <= 32'd0;
            end else if (btn_debounce_cnt >= (BUTTON_DEBOUNCE_CLKS - 1)) begin
                btn_stable <= btn_sync1;
                btn_debounce_cnt <= 32'd0;
            end else begin
                btn_debounce_cnt <= btn_debounce_cnt + 1'b1;
            end
        end
    end

    // 中键：运行时暂停/继续，游戏结束时复位；空闲时不改变暂停状态。
    always @(posedge clk_pix or negedge rst_n) begin
        if (!rst_n) begin
            pause_reg <= 1'b0;
            reset_game_reg <= 1'b0;
        end else begin
            reset_game_reg <= 1'b0;

            if (state == 2'd0) begin
                pause_reg <= 1'b0;
            end

            if (btn_center_event) begin
                if (state == 2'd3) begin
                    reset_game_reg <= 1'b1;
                    pause_reg <= 1'b0;
                end else if (state == 2'd1) begin
                    pause_reg <= ~pause_reg;
                end
            end
        end
    end

    //==================================================
    // VGA timing instantiation
    //==================================================
    wire active;
    wire [9:0] pixel_x;
    wire [8:0] pixel_y;

    vga_timing u_vga_timing (
        .clk_pix(clk_pix),
        .rst_n(rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .active_video(active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    //==================================================
    // slow tick generator (for snake move)
    // uses clk_pix domain
    //==================================================
    reg [31:0] tick_cnt;
    reg tick_q;

    always @(posedge clk_pix or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt <= 0;
            tick_q <= 1'b0;
        end else begin
            if (tick_cnt >= (TICK_DIV - 1)) begin
                tick_cnt <= 0;
                tick_q <= 1'b1;
            end else begin
                tick_cnt <= tick_cnt + 1;
                tick_q <= 1'b0;
            end
        end
    end

    wire tick = tick_q;

    //==================================================
    // elapsed time and seven-segment display
    // left-to-right: lives, minutes with dp, seconds tens, seconds ones,
    // blank, score hundreds, score tens, score ones.
    //==================================================
    reg [31:0] one_second_cnt;
    reg [3:0] elapsed_min;
    reg [5:0] elapsed_sec;
    reg [31:0] sevenseg_refresh_cnt;
    reg [2:0] sevenseg_scan;
    reg [3:0] sevenseg_digit;

    wire [9:0] score_capped = (score > 16'd999) ? 10'd999 : score[9:0];
    wire [3:0] score_hundreds = score_capped / 10'd100;
    wire [6:0] score_after_hundreds = score_capped - (score_hundreds * 7'd100);
    wire [3:0] score_tens = score_after_hundreds / 7'd10;
    wire [3:0] score_ones = score_after_hundreds - (score_tens * 4'd10);
    wire [3:0] display_lives = (lives > 4'd9) ? 4'd9 : lives;
    wire [3:0] display_min = elapsed_min;
    wire [3:0] display_sec_tens = elapsed_sec / 6'd10;
    wire [3:0] display_sec_ones = elapsed_sec - (display_sec_tens * 4'd10);
    wire [2:0] active_enemy_limit = (elapsed_min >= 4'd2) ? 3'd5 : 3'd3;

    always @(posedge clk_pix or negedge rst_n) begin
        if (!rst_n) begin
            one_second_cnt <= 32'd0;
            elapsed_min <= 4'd0;
            elapsed_sec <= 6'd0;
        end else if ((state == 2'd0) || reset_game || start) begin
            one_second_cnt <= 32'd0;
            elapsed_min <= 4'd0;
            elapsed_sec <= 6'd0;
        end else if ((state == 2'd1) && !pause) begin
            if (one_second_cnt >= (ONE_SECOND_CLKS - 1)) begin
                one_second_cnt <= 32'd0;
                if (!((elapsed_min == 4'd9) && (elapsed_sec == 6'd59))) begin
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

    always @(posedge clk_pix or negedge rst_n) begin
        if (!rst_n) begin
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
                sevenseg_digit = display_min;
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

    //==================================================
    // snake_game instantiation
    // snake_game clocked by clk_pix in this prototype
    //==================================================
    wire [5:0] cell_x;
    wire [4:0] cell_y;
    wire [2:0] cell_status;

    snake_game #(
        .COLS(40),
        .ROWS(30),
        .MAXLEN(128),
        .MAX_ENEMIES(5),
        .ENEMY_MIN_LEN(ENEMY_MIN_LEN),
        .ENEMY_MAX_LEN(ENEMY_MAX_LEN),
        .ENEMY_SPAWN_MIN_TICKS(ENEMY_SPAWN_MIN_TICKS),
        .ENEMY_SPAWN_RANDOM_MASK(ENEMY_SPAWN_RANDOM_MASK)
    ) u_snake (
        .clk(clk_pix),
        .rst_n(rst_n),
        .dir(dir_req),
        .dir_valid(dir_req_valid),
        .start(start),
        .pause(pause),
        .reset_game(reset_game),
        .tick(tick),
        .enemy_limit(active_enemy_limit),
        .cell_x(cell_x),
        .cell_y(cell_y),
        .cell_state(cell_status),
        .score(score),
        .lives(lives),
        .state(state)
    );

    assign gpio_status = {lives, status_state, score};

    //==================================================
    // grid_renderer instantiation
    //==================================================
    wire [2:0] rgb_r, rgb_g, rgb_b;

    grid_renderer #(
        .CELL_W(16),
        .CELL_H(16)
    ) u_renderer (
        .clk_pix(clk_pix),
        .rst_n(rst_n),
        .active(active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .cell_x(cell_x),
        .cell_y(cell_y),
        .cell_state(cell_status),
        .rgb_r(rgb_r),
        .rgb_g(rgb_g),
        .rgb_b(rgb_b)
    );

    // GAMEOVER clears the game field and draws only pixel text.
    localparam GAMEOVER_TEXT_X = 10'd132;
    localparam GAMEOVER_TEXT_Y = 9'd212;
    localparam GAMEOVER_TEXT_W = 10'd376;
    localparam GAMEOVER_TEXT_H = 9'd56;

    wire gameover_box =
        (pixel_x >= GAMEOVER_TEXT_X) && (pixel_x < GAMEOVER_TEXT_X + GAMEOVER_TEXT_W) &&
        (pixel_y >= GAMEOVER_TEXT_Y) && (pixel_y < GAMEOVER_TEXT_Y + GAMEOVER_TEXT_H);
    wire [5:0] gameover_text_x = (pixel_x - GAMEOVER_TEXT_X) >> 3;
    wire [2:0] gameover_text_y = (pixel_y - GAMEOVER_TEXT_Y) >> 3;
    wire gameover_text_on =
        active && (state == 2'd3) && gameover_box &&
        gameover_pixel(gameover_text_x, gameover_text_y);

    assign vga_r = (state == 2'd3) ? (gameover_text_on ? 3'b111 : 3'b000) : rgb_r;
    assign vga_g = (state == 2'd3) ? (gameover_text_on ? 3'b111 : 3'b000) : rgb_g;
    assign vga_b = (state == 2'd3) ? (gameover_text_on ? 3'b111 : 3'b000) : rgb_b;

endmodule
