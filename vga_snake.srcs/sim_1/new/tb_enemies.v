`timescale 1ns / 1ps

module tb_enemies;
    localparam TB_MAX_ENEMIES = 5;
    localparam TB_ENEMY_MIN_LEN = 4;
    localparam TB_ENEMY_MAX_LEN = 8;

    localparam EMPTY = 3'b000;
    localparam BODY  = 3'b001;
    localparam HEAD  = 3'b010;
    localparam RED_FOOD    = 3'b011;
    localparam YELLOW_FOOD = 3'b100;
    localparam BLUE_FOOD   = 3'b101;
    localparam ENEMY_HEAD  = 3'b110;
    localparam ENEMY_BODY  = 3'b111;

    localparam DIR_UP    = 2'b00;
    localparam DIR_DOWN  = 2'b01;
    localparam DIR_LEFT  = 2'b10;
    localparam DIR_RIGHT = 2'b11;

    reg clk;
    reg rst_n;
    reg [1:0] dir;
    reg dir_valid;
    reg start;
    reg pause;
    reg reset_game;
    reg tick;
    reg [2:0] enemy_limit;
    reg [5:0] cell_x;
    reg [4:0] cell_y;
    wire [2:0] cell_state;
    wire [15:0] score;
    wire [3:0] lives;
    wire [1:0] state;

    integer errors;
    integer i;
    integer red_count;
    integer yellow_count;
    integer blue_count;

    snake_game #(
        .COLS(12),
        .ROWS(8),
        .MAXLEN(32),
        .MAX_ENEMIES(TB_MAX_ENEMIES),
        .ENEMY_MIN_LEN(TB_ENEMY_MIN_LEN),
        .ENEMY_MAX_LEN(TB_ENEMY_MAX_LEN),
        .ENEMY_SPAWN_MIN_TICKS(1),
        .ENEMY_SPAWN_RANDOM_MASK(16'h0000)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .dir(dir),
        .dir_valid(dir_valid),
        .start(start),
        .pause(pause),
        .reset_game(reset_game),
        .tick(tick),
        .enemy_limit(enemy_limit),
        .cell_x(cell_x),
        .cell_y(cell_y),
        .cell_state(cell_state),
        .score(score),
        .lives(lives),
        .state(state)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task wait_cycles;
        input integer cycles;
        integer c;
        begin
            for (c = 0; c < cycles; c = c + 1)
                @(posedge clk);
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

    task tick_once;
        begin
            @(negedge clk);
            tick = 1'b1;
            @(posedge clk);
            @(negedge clk);
            tick = 1'b0;
            wait_cycles(1);
        end
    endtask

    task start_game;
        begin
            start = 1'b1;
            dir = DIR_RIGHT;
            dir_valid = 1'b1;
            @(posedge clk);
            #1 start = 1'b0;
            dir_valid = 1'b0;
            wait_cycles(2);
            #1;
            dut.food_valid = 1'b0;
            dut.yellow_food_valid = 1'b0;
            dut.green_food_valid = 1'b0;
            dut.pending_food = 1'b0;
            dut.food_spawn_countdown = 16'h7fff;
            dut.pending_enemy_spawn = 1'b0;
            dut.enemy_spawn_countdown = 16'h7fff;
            check(state == 2'd1, "game should enter RUNNING after start");
        end
    endtask

    task restart_game;
        begin
            reset_game = 1'b1;
            @(posedge clk);
            #1 reset_game = 1'b0;
            wait_cycles(2);
            start_game;
        end
    endtask

    task clear_enemies;
        begin
            for (i = 0; i < TB_MAX_ENEMIES; i = i + 1) begin
                dut.enemy_alive[i] = 1'b0;
                dut.enemy_dir[i] = DIR_RIGHT;
                dut.enemy_len[i] = TB_ENEMY_MIN_LEN;
            end
            for (i = 0; i < TB_MAX_ENEMIES * TB_ENEMY_MAX_LEN; i = i + 1)
                dut.enemy_pos[i] = 16'hffff;
        end
    endtask

    task force_player_line;
        input [15:0] head;
        input [15:0] len;
        begin
            dut.snake_map = {96{1'b0}};
            dut.head_idx = head;
            dut.hx = head % 12;
            dut.hy = head / 12;
            dut.slen = len;
            dut.head_ptr = 0;
            dut.tail_ptr = len - 1;
            dut.cur_dir = DIR_RIGHT;
            dut.next_dir = DIR_RIGHT;
            dut.invincible_ticks = 0;
            dut.invincible_blink = 1'b1;
            dut.growth_pending = 0;
            dut.pending_player_respawn = 1'b0;
            dut.food_valid = 1'b0;
            dut.yellow_food_valid = 1'b0;
            dut.green_food_valid = 1'b0;
            dut.pending_food = 1'b0;
            dut.food_spawn_countdown = 16'h7fff;
            dut.pending_enemy_spawn = 1'b0;
            dut.enemy_spawn_countdown = 16'h7fff;
            for (i = 0; i < 32; i = i + 1) begin
                if (i < len) begin
                    dut.snake_pos[i] = head - i;
                    if (i != 0)
                        dut.snake_map[head - i] = 1'b1;
                end else begin
                    dut.snake_pos[i] = 16'hffff;
                end
            end
        end
    endtask

    task force_self_collision_shape;
        input [15:0] len;
        begin
            force_player_line(16'd54, len);
            dut.snake_pos[1] = 16'd55;
            dut.snake_map[55] = 1'b1;
        end
    endtask

    task wait_respawn_done;
        integer guard;
        begin
            guard = 0;
            while (dut.pending_player_respawn && guard < 200) begin
                wait_cycles(1);
                guard = guard + 1;
            end
            check(!dut.pending_player_respawn, "self-collision respawn should finish");
        end
    endtask

    function [1:0] dir_between_cells;
        input [15:0] from_idx;
        input [15:0] to_idx;
        begin
            if (to_idx == from_idx + 1)
                dir_between_cells = DIR_RIGHT;
            else if (from_idx == to_idx + 1)
                dir_between_cells = DIR_LEFT;
            else if (to_idx == from_idx + 12)
                dir_between_cells = DIR_DOWN;
            else
                dir_between_cells = DIR_UP;
        end
    endfunction

    function player_body_has_bend;
        input unused;
        integer k;
        reg [1:0] d0;
        reg [1:0] d1;
        begin
            player_body_has_bend = 1'b0;
            for (k = 1; k < 31; k = k + 1) begin
                if (k < dut.slen - 1) begin
                    d0 = dir_between_cells(dut.snake_pos[k], dut.snake_pos[k - 1]);
                    d1 = dir_between_cells(dut.snake_pos[k + 1], dut.snake_pos[k]);
                    if (d0 != d1)
                        player_body_has_bend = 1'b1;
                end
            end
        end
    endfunction

    task spawn_one;
        input [15:0] seed;
        input [15:0] scan_idx;
        begin
            dut.lfsr = seed;
            dut.enemy_scan_idx = scan_idx;
            dut.pending_enemy_spawn = 1'b1;
            @(posedge clk);
            #1;
        end
    endtask

    function integer alive_count;
        input unused;
        integer j;
        begin
            alive_count = 0;
            for (j = 0; j < TB_MAX_ENEMIES; j = j + 1) begin
                if (dut.enemy_alive[j])
                    alive_count = alive_count + 1;
            end
        end
    endfunction

    task check_enemy_lengths;
        begin
            for (i = 0; i < TB_MAX_ENEMIES; i = i + 1) begin
                if (dut.enemy_alive[i]) begin
                    check(dut.enemy_len[i] >= TB_ENEMY_MIN_LEN, "enemy length should not be below four");
                    check(dut.enemy_len[i] <= TB_ENEMY_MAX_LEN, "enemy length should not be above eight");
                end
            end
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 1'b0;
        dir = DIR_RIGHT;
        dir_valid = 1'b0;
        start = 1'b0;
        pause = 1'b0;
        reset_game = 1'b0;
        tick = 1'b0;
        enemy_limit = 3'd3;
        cell_x = 0;
        cell_y = 0;

        wait_cycles(5);
        rst_n = 1'b1;
        wait_cycles(3);

        start_game;
        check(lives == 4'd1, "initial lives should be one");
        clear_enemies;

        red_count = 0;
        yellow_count = 0;
        blue_count = 0;
        for (i = 0; i < 10; i = i + 1) begin
            case (dut.weighted_food_type(i[15:0]))
                2'd0: red_count = red_count + 1;
                2'd1: yellow_count = yellow_count + 1;
                2'd2: blue_count = blue_count + 1;
            endcase
        end
        check(red_count == 5, "red food frequency weight should be 5");
        check(yellow_count == 3, "yellow food frequency weight should be 3");
        check(blue_count == 2, "blue life food frequency weight should be 2");

        spawn_one(16'h0000, 16'd23);
        check(alive_count(1'b0) == 1, "first enemy should spawn");
        spawn_one(16'h0002, 16'd47);
        check(alive_count(1'b0) == 2, "second enemy should spawn");
        spawn_one(16'h0001, 16'd83);
        check(alive_count(1'b0) == 3, "third enemy should spawn");
        check_enemy_lengths;
        spawn_one(16'h0003, 16'd95);
        check(alive_count(1'b0) == 3, "enemy count must stay at three");
        check(dut.pending_enemy_spawn == 1'b0, "spawn request should clear when field has three enemies");
        enemy_limit = 3'd5;
        spawn_one(16'h0004, 16'd71);
        check(alive_count(1'b0) == 4, "fourth enemy should spawn after limit rises");
        spawn_one(16'h0005, 16'd95);
        check(alive_count(1'b0) == 5, "fifth enemy should spawn after limit rises");
        check_enemy_lengths;

        cell_x = 6'd11;
        cell_y = 5'd1;
        #1 check(cell_state == ENEMY_HEAD, "enemy head should render as enemy-head state");
        cell_x = 6'd10;
        cell_y = 5'd1;
        #1 check(cell_state == ENEMY_BODY, "enemy body should render as enemy-body state");

        restart_game;
        clear_enemies;
        force_player_line(16'd54, 16'd3);
        dut.yellow_food_idx = 16'd55;
        dut.yellow_food_valid = 1'b1;
        tick_once;
        check(score == 16'd2, "yellow food should add two points");
        check(dut.slen == 16'd4, "yellow food should add the first growth segment immediately");
        check(dut.growth_pending == 4'd1, "yellow food should queue the second growth segment");

        restart_game;
        clear_enemies;
        force_player_line(16'd54, 16'd3);
        dut.lives = 4'd8;
        dut.green_food_idx = 16'd55;
        dut.green_food_valid = 1'b1;
        cell_x = 6'd7;
        cell_y = 5'd4;
        #1 check(cell_state == BLUE_FOOD, "blue life food should render as blue state");
        tick_once;
        check(lives == 4'd9, "blue life food should raise lives to nine");
        force_player_line(16'd54, 16'd3);
        dut.lives = 4'd9;
        dut.green_food_idx = 16'd55;
        dut.green_food_valid = 1'b1;
        tick_once;
        check(lives == 4'd9, "blue life food should not exceed nine lives");

        restart_game;
        clear_enemies;
        dut.enemy_alive[0] = 1'b1;
        dut.enemy_dir[0] = DIR_RIGHT;
        dut.enemy_len[0] = 4'd4;
        dut.enemy_pos[0] = 16'd70;
        dut.enemy_pos[1] = 16'd55;
        dut.enemy_pos[2] = 16'd56;
        dut.enemy_pos[3] = 16'd57;
        tick_once;
        check(state == 2'd1, "hitting enemy body should not end game");
        check(score == 16'd5, "hitting enemy body should add five points");
        check(dut.enemy_alive[0] == 1'b0, "enemy should disappear after body hit");

        restart_game;
        clear_enemies;
        dut.lives = 4'd3;
        dut.enemy_alive[0] = 1'b1;
        dut.enemy_dir[0] = DIR_RIGHT;
        dut.enemy_len[0] = 4'd4;
        dut.enemy_pos[0] = 16'd55;
        dut.enemy_pos[1] = 16'd56;
        dut.enemy_pos[2] = 16'd57;
        dut.enemy_pos[3] = 16'd58;
        tick_once;
        check(state == 2'd1, "player head hitting enemy head should spend one life first");
        check(dut.lives == 4'd2, "player head hitting enemy head should decrement lives");
        check(dut.invincible_ticks != 0, "player should become invincible after enemy-head damage");

        restart_game;
        clear_enemies;
        dut.lives = 4'd3;
        dut.enemy_alive[0] = 1'b1;
        dut.enemy_dir[0] = DIR_LEFT;
        dut.enemy_len[0] = 4'd4;
        dut.enemy_pos[0] = 16'd56;
        dut.enemy_pos[1] = 16'd57;
        dut.enemy_pos[2] = 16'd58;
        dut.enemy_pos[3] = 16'd59;
        dut.lfsr = 16'h0002;
        tick_once;
        check(state == 2'd1, "enemy head hitting player should spend one life first");
        check(dut.lives == 4'd2, "enemy head hitting player should decrement lives");
        check(dut.invincible_ticks != 0, "enemy hit should start invincible state");

        restart_game;
        clear_enemies;
        dut.lives = 4'd3;
        dut.lfsr = 16'h002d;
        force_self_collision_shape(16'd6);
        tick_once;
        check(state == 2'd1, "self-collision should spend one life before game over");
        check(lives == 4'd2, "self-collision should decrement one life");
        check(dut.slen == 16'd6, "self-collision respawn should keep length");
        wait_respawn_done;
        check(state == 2'd1, "self-collision respawn should keep game running");
        check(dut.slen == 16'd6, "respawned player length should stay unchanged");
        check(player_body_has_bend(1'b0), "respawned player body should contain a bend");
        dut.invincible_ticks = 0;
        tick_once;
        check(state == 2'd1, "respawned player should survive the first move");

        reset_game = 1'b1;
        @(posedge clk);
        #1 reset_game = 1'b0;
        wait_cycles(1);
        check(state == 2'd0, "reset_game should return to IDLE");
        check(alive_count(1'b0) == 0, "reset_game should clear all enemies");

        if (errors == 0)
            $display("PASS: tb_enemies");
        else
            $display("FAIL: tb_enemies errors=%0d", errors);

        $finish;
    end
endmodule
