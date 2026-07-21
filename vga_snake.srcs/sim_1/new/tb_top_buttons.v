`timescale 1ns / 1ps

module tb_top_buttons;
    localparam DIR_UP    = 2'b00;
    localparam DIR_RIGHT = 2'b11;

    reg clk_pix;
    reg rst_n;
    reg [4:0] gpio_btn;
    wire hsync;
    wire vsync;
    wire [2:0] vga_r;
    wire [2:0] vga_g;
    wire [2:0] vga_b;
    wire [6:0] seg;
    wire dp;
    wire [7:0] an;
    wire [21:0] gpio_status;

    integer errors;
    integer x0;
    integer y0;
    integer x1;
    integer y1;
    integer guard;

    top #(
        .TICK_DIV(32),
        .BUTTON_DEBOUNCE_CLKS(1),
        .ONE_SECOND_CLKS(8),
        .SEVENSEG_REFRESH_DIV(2),
        .ENEMY_SPAWN_MIN_TICKS(32767),
        .ENEMY_SPAWN_RANDOM_MASK(16'h0000)
    ) dut (
        .clk_pix(clk_pix),
        .rst_n(rst_n),
        .gpio_btn(gpio_btn),
        .hsync(hsync),
        .vsync(vsync),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .seg(seg),
        .dp(dp),
        .an(an),
        .gpio_status(gpio_status)
    );

    initial begin
        clk_pix = 1'b0;
        forever #5 clk_pix = ~clk_pix;
    end

    task wait_cycles;
        input integer cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1)
                @(posedge clk_pix);
        end
    endtask

    task press_button;
        input integer button_index;
        begin
            gpio_btn[button_index] = 1'b1;
            wait_cycles(4);
            gpio_btn[button_index] = 1'b0;
            wait_cycles(4);
        end
    endtask

    task check;
        input condition;
        input [1023:0] message;
        begin
            if (!condition) begin
                errors = errors + 1;
                $display("ERROR: %0s", message);
            end
        end
    endtask

    task wait_for_state;
        input [1:0] expected_state;
        input integer max_cycles;
        begin
            guard = 0;
            while ((dut.u_snake.state != expected_state) && (guard < max_cycles)) begin
                wait_cycles(1);
                guard = guard + 1;
            end
            check(dut.u_snake.state == expected_state, "state did not reach expected value");
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 1'b0;
        gpio_btn = 5'b00000;

        wait_cycles(5);
        rst_n = 1'b1;
        wait_cycles(5);

        press_button(0);
        wait_cycles(20);
        check(dut.pause_reg == 1'b0, "center button must not set pause while idle");
        check(dut.u_snake.state == 2'd0, "center button must not start game while idle");

        press_button(1);
        wait_for_state(2'd1, 80);
        wait_cycles(24);
        check(dut.elapsed_sec >= 6'd2, "elapsed seconds should count while running");
        check(an != 8'b11111111, "seven segment display should scan one digit");
        check(dut.display_lives == dut.u_snake.lives, "leftmost seven segment digit should use lives");
        check(dut.score_hundreds == 4'd0, "score hundreds should start at zero");
        check(dut.score_tens == 4'd0, "score tens should start at zero");
        check(dut.score_ones == 4'd0, "score ones should start at zero");
        wait_cycles(80);
        check(dut.u_snake.cur_dir == DIR_UP, "short UP press should set current direction to UP");
        check(dut.u_snake.hx == 6'd20, "snake should not drift RIGHT after UP key is released");
        check(dut.u_snake.hy < 5'd15, "snake should keep moving UP after UP key is released");

        press_button(3);
        wait_cycles(80);
        check(dut.u_snake.cur_dir == DIR_RIGHT, "RIGHT press should turn snake to RIGHT");
        check(dut.u_snake.hx > 6'd20, "snake should move RIGHT after RIGHT press");

        @(posedge dut.tick);
        wait_cycles(1);
        x0 = dut.u_snake.hx;
        y0 = dut.u_snake.hy;
        press_button(1);
        press_button(2);
        @(posedge dut.tick);
        wait_cycles(2);
        check(dut.u_snake.cur_dir == DIR_UP, "LEFT after queued UP must be rejected before the next tick");
        check(dut.u_snake.hx >= x0, "illegal same-tick reverse should not move LEFT");
        check(dut.u_snake.hy < y0, "queued UP should move the snake upward");

        @(posedge dut.tick);
        wait_cycles(1);
        press_button(0);
        wait_cycles(12);
        x1 = dut.u_snake.hx;
        y1 = dut.u_snake.hy;
        wait_cycles(100);
        check(dut.u_snake.hx == x1, "paused snake X should remain unchanged");
        check(dut.u_snake.hy == y1, "paused snake Y should remain unchanged");
        check(gpio_status[17:16] == 2'd2, "gpio_status should report pause state");

        press_button(0);
        wait_cycles(70);
        check(dut.u_snake.hy < y1, "snake should move again after unpause");

        dut.u_snake.lives = 4'd1;
        dut.u_snake.invincible_ticks = 6'd0;
        wait_for_state(2'd3, 1200);
        wait_cycles(2);
        check((vga_r == 3'b000) && (vga_g == 3'b000) && (vga_b == 3'b000), "gameover background should clear game pixels to black");
        force dut.pixel_x = 10'd136;
        force dut.pixel_y = 9'd216;
        force dut.active = 1'b1;
        #1;
        check((vga_r == 3'b111) && (vga_g == 3'b111) && (vga_b == 3'b111), "gameover should draw GAMEOVER text pixels");
        release dut.pixel_x;
        release dut.pixel_y;
        release dut.active;
        press_button(0);
        wait_for_state(2'd0, 80);

        press_button(2);
        wait_for_state(2'd1, 80);
        wait_cycles(80);
        check(dut.u_snake.cur_dir == DIR_RIGHT, "LEFT at start should fall back to safe RIGHT direction");

        if (errors == 0)
            $display("PASS: tb_top_buttons");
        else
            $display("FAIL: tb_top_buttons errors=%0d", errors);

        $finish;
    end
endmodule
