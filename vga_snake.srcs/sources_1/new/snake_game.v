`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// snake_game.v
// Grid-based snake logic.
// - grid: 40 x 30 (parameterizable)
// - external slow tick controls movement
// - snake body storage uses a circular buffer plus a body bitmap
// - short enemy snakes spawn randomly and move randomly
//////////////////////////////////////////////////////////////////////////////////
module snake_game #(
    parameter COLS = 40,
    parameter ROWS = 30,
    parameter MAXLEN = (COLS*ROWS),
    parameter MAX_ENEMIES = 3,
    parameter ENEMY_MIN_LEN = 4,
    parameter ENEMY_MAX_LEN = 8,
    parameter ENEMY_SPAWN_MIN_TICKS = 40,
    parameter ENEMY_SPAWN_RANDOM_MASK = 16'h003F,
    parameter FOOD_SPAWN_MIN_TICKS = 8,
    parameter FOOD_SPAWN_RANDOM_MASK = 16'h000F,
    parameter INITIAL_LIVES = 1,
    parameter MAX_LIVES = 9,
    parameter INVINCIBLE_TICKS = 20
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  dir,       // 00 up, 01 down, 10 left, 11 right
    input  wire        dir_valid,
    input  wire        start,
    input  wire        pause,
    input  wire        reset_game,
    input  wire        tick,
    input  wire [2:0]  enemy_limit,
    input  wire [5:0]  cell_x,
    input  wire [4:0]  cell_y,
    output wire [2:0]  cell_state,
    output reg  [15:0] score,
    output reg  [3:0]  lives,
    output reg  [1:0]  state      // 0 idle,1 running,2 pause,3 gameover
);

    localparam EMPTY       = 3'b000;
    localparam BODY        = 3'b001;
    localparam HEAD        = 3'b010;
    localparam RED_FOOD    = 3'b011;
    localparam YELLOW_FOOD = 3'b100;
    localparam BLUE_FOOD   = 3'b101;
    localparam ENEMY_HEAD  = 3'b110;
    localparam ENEMY_BODY  = 3'b111;

    localparam FOOD_RED    = 2'd0;
    localparam FOOD_YELLOW = 2'd1;
    localparam FOOD_GREEN  = 2'd2;

    localparam DIR_UP    = 2'b00;
    localparam DIR_DOWN  = 2'b01;
    localparam DIR_LEFT  = 2'b10;
    localparam DIR_RIGHT = 2'b11;

    localparam GRID_CELLS = COLS*ROWS;
    localparam INIT_HEAD_IDX  = (ROWS/2)*COLS + (COLS/2);
    localparam INIT_BODY1_IDX = (ROWS/2)*COLS + (COLS/2 - 1);
    localparam INIT_BODY2_IDX = (ROWS/2)*COLS + (COLS/2 - 2);
    localparam INVALID_INDEX = 16'hFFFF;
    localparam RESP_SCAN  = 1'b0;
    localparam RESP_BUILD = 1'b1;
    localparam [2:0] NO_ENEMY_SLOT = MAX_ENEMIES;

    wire [2:0] active_enemy_limit = (enemy_limit > MAX_ENEMIES) ? MAX_ENEMIES : enemy_limit;

    function is_initial_snake_index;
        input integer qidx;
        begin
            is_initial_snake_index =
                (qidx == INIT_HEAD_IDX) ||
                (qidx == INIT_BODY1_IDX) ||
                (qidx == INIT_BODY2_IDX);
        end
    endfunction

    function [15:0] prev_snake_index;
        input [15:0] ptr;
        begin
            if (ptr == 16'd0)
                prev_snake_index = MAXLEN - 1;
            else
                prev_snake_index = ptr - 1'b1;
        end
    endfunction

    function is_opposite_dir;
        input [1:0] a;
        input [1:0] b;
        begin
            is_opposite_dir =
                ((a == DIR_UP)    && (b == DIR_DOWN)) ||
                ((a == DIR_DOWN)  && (b == DIR_UP))   ||
                ((a == DIR_LEFT)  && (b == DIR_RIGHT))||
                ((a == DIR_RIGHT) && (b == DIR_LEFT));
        end
    endfunction

    function [1:0] start_direction;
        input [1:0] requested_dir;
        input       requested_valid;
        begin
            if (requested_valid && !is_opposite_dir(DIR_RIGHT, requested_dir))
                start_direction = requested_dir;
            else
                start_direction = DIR_RIGHT;
        end
    endfunction

    function [1:0] turn_right;
        input [1:0] d;
        begin
            case (d)
                DIR_UP:    turn_right = DIR_RIGHT;
                DIR_RIGHT: turn_right = DIR_DOWN;
                DIR_DOWN:  turn_right = DIR_LEFT;
                default:   turn_right = DIR_UP;
            endcase
        end
    endfunction

    function [1:0] turn_left;
        input [1:0] d;
        begin
            case (d)
                DIR_UP:    turn_left = DIR_LEFT;
                DIR_LEFT:  turn_left = DIR_DOWN;
                DIR_DOWN:  turn_left = DIR_RIGHT;
                default:   turn_left = DIR_UP;
            endcase
        end
    endfunction

    function [15:0] next_grid_index;
        input [15:0] cur_idx;
        input [1:0]  move_dir;
        integer qx;
        integer qy;
        begin
            qx = cur_idx % COLS;
            qy = cur_idx / COLS;
            next_grid_index = INVALID_INDEX;

            case (move_dir)
                DIR_UP: begin
                    if (qy > 0)
                        next_grid_index = cur_idx - COLS;
                end
                DIR_DOWN: begin
                    if (qy < ROWS - 1)
                        next_grid_index = cur_idx + COLS;
                end
                DIR_LEFT: begin
                    if (qx > 0)
                        next_grid_index = cur_idx - 1'b1;
                end
                DIR_RIGHT: begin
                    if (qx < COLS - 1)
                        next_grid_index = cur_idx + 1'b1;
                end
            endcase
        end
    endfunction

    function [GRID_CELLS-1:0] initial_snake_map;
        input unused;
        begin
            initial_snake_map = {GRID_CELLS{1'b0}};
            initial_snake_map[INIT_BODY1_IDX] = 1'b1;
            initial_snake_map[INIT_BODY2_IDX] = 1'b1;
        end
    endfunction

    // Body bitmap excludes the player head. Enemy positions include head at segment 0.
    reg [GRID_CELLS-1:0] snake_map;
    reg [15:0] snake_pos [0:MAXLEN-1];
    reg [15:0] slen;
    reg [15:0] head_ptr;
    reg [15:0] tail_ptr;
    reg [15:0] head_idx;
    reg [15:0] food_idx;
    reg        food_valid;
    reg [15:0] yellow_food_idx;
    reg        yellow_food_valid;
    reg [15:0] green_food_idx;
    reg        green_food_valid;
    reg        pending_food;
    reg [1:0]  pending_food_type;
    reg [15:0] food_scan_idx;
    reg [15:0] food_spawn_countdown;
    reg [5:0]  invincible_ticks;
    reg        invincible_blink;
    reg [3:0]  growth_pending;
    reg        pending_player_respawn;
    reg [15:0] respawn_scan_idx;
    reg [1:0]  respawn_path_mode;
    reg        respawn_phase;
    reg [15:0] respawn_build_idx;
    reg [15:0] respawn_head_idx;
    reg [15:0] respawn_forward_idx;
    reg [1:0]  respawn_head_dir;
    reg [5:0]  respawn_scan_x;
    reg [4:0]  respawn_scan_y;
    reg [5:0]  respawn_build_x;
    reg [4:0]  respawn_build_y;
    reg [1:0]  respawn_build_dir;
    reg        respawn_bend_seen;
    reg [1:0]  respawn_last_dir;

    reg [5:0] hx;
    reg [4:0] hy;
    reg [1:0] cur_dir;
    reg [1:0] next_dir;
    reg [15:0] lfsr;

    reg enemy_alive [0:MAX_ENEMIES-1];
    reg [1:0] enemy_dir [0:MAX_ENEMIES-1];
    reg [3:0] enemy_len [0:MAX_ENEMIES-1];
    reg [15:0] enemy_pos [0:(MAX_ENEMIES*ENEMY_MAX_LEN)-1];
    reg [15:0] enemy_spawn_countdown;
    reg        pending_enemy_spawn;
    reg [15:0] enemy_scan_idx;

    function food_occupies_index;
        input [15:0] qidx;
        begin
            food_occupies_index =
                (food_valid && (qidx == food_idx)) ||
                (yellow_food_valid && (qidx == yellow_food_idx)) ||
                (green_food_valid && (qidx == green_food_idx));
        end
    endfunction

    function food_type_available;
        input [1:0] qtype;
        begin
            case (qtype)
                FOOD_RED:    food_type_available = !food_valid;
                FOOD_YELLOW: food_type_available = !yellow_food_valid;
                FOOD_GREEN:  food_type_available = !green_food_valid;
                default:     food_type_available = 1'b0;
            endcase
        end
    endfunction

    function [1:0] weighted_food_type;
        input [15:0] seed;
        integer bucket;
        begin
            bucket = seed % 10;
            if (bucket < 5)
                weighted_food_type = FOOD_RED;
            else if (bucket < 8)
                weighted_food_type = FOOD_YELLOW;
            else
                weighted_food_type = FOOD_GREEN;
        end
    endfunction

    function [1:0] select_food_type;
        input [15:0] seed;
        reg [1:0] chosen;
        begin
            chosen = weighted_food_type(seed);
            if (food_type_available(chosen)) begin
                select_food_type = chosen;
            end else if (!food_valid) begin
                select_food_type = FOOD_RED;
            end else if (!yellow_food_valid) begin
                select_food_type = FOOD_YELLOW;
            end else begin
                select_food_type = FOOD_GREEN;
            end
        end
    endfunction

    function all_food_present;
        input unused;
        begin
            all_food_present = food_valid && yellow_food_valid && green_food_valid;
        end
    endfunction

    function enemy_occupies_index;
        input [15:0] qidx;
        integer ei;
        integer ej;
        integer base;
        begin
            enemy_occupies_index = 1'b0;
            for (ei = 0; ei < MAX_ENEMIES; ei = ei + 1) begin
                base = ei * ENEMY_MAX_LEN;
                if (enemy_alive[ei]) begin
                    for (ej = 0; ej < ENEMY_MAX_LEN; ej = ej + 1) begin
                        if ((ej < enemy_len[ei]) && (enemy_pos[base + ej] == qidx))
                            enemy_occupies_index = 1'b1;
                    end
                end
            end
        end
    endfunction

    function enemy_head_at_index;
        input [15:0] qidx;
        integer ei;
        begin
            enemy_head_at_index = 1'b0;
            for (ei = 0; ei < MAX_ENEMIES; ei = ei + 1) begin
                if (enemy_alive[ei] && (enemy_pos[ei * ENEMY_MAX_LEN] == qidx))
                    enemy_head_at_index = 1'b1;
            end
        end
    endfunction

    function enemy_occupies_index_except_self_tail;
        input [2:0]  slot;
        input [15:0] qidx;
        integer ei;
        integer ej;
        integer base;
        begin
            enemy_occupies_index_except_self_tail = 1'b0;
            for (ei = 0; ei < MAX_ENEMIES; ei = ei + 1) begin
                base = ei * ENEMY_MAX_LEN;
                if (enemy_alive[ei]) begin
                    for (ej = 0; ej < ENEMY_MAX_LEN; ej = ej + 1) begin
                        if ((ej < enemy_len[ei]) &&
                            !((ei == slot) && (ej == enemy_len[ei] - 1)) &&
                            (enemy_pos[base + ej] == qidx)) begin
                            enemy_occupies_index_except_self_tail = 1'b1;
                        end
                    end
                end
            end
        end
    endfunction

    function enemy_move_valid;
        input [2:0] slot;
        input [1:0] move_dir;
        reg [15:0] qidx;
        begin
            qidx = next_grid_index(enemy_pos[slot * ENEMY_MAX_LEN], move_dir);
            enemy_move_valid =
                (qidx != INVALID_INDEX) &&
                !enemy_occupies_index_except_self_tail(slot, qidx) &&
                !food_occupies_index(qidx);
        end
    endfunction

    function [2:0] enemy_alive_count;
        input unused;
        integer ei;
        begin
            enemy_alive_count = 3'd0;
            for (ei = 0; ei < MAX_ENEMIES; ei = ei + 1) begin
                if (enemy_alive[ei])
                    enemy_alive_count = enemy_alive_count + 1'b1;
            end
        end
    endfunction

    function [2:0] first_dead_enemy_slot;
        input unused;
        integer ei;
        begin
            first_dead_enemy_slot = NO_ENEMY_SLOT;
            for (ei = 0; ei < MAX_ENEMIES; ei = ei + 1) begin
                if ((ei < active_enemy_limit) && !enemy_alive[ei] && (first_dead_enemy_slot == NO_ENEMY_SLOT))
                    first_dead_enemy_slot = ei[2:0];
            end
        end
    endfunction

    function spawn_cell_free;
        input [15:0] qidx;
        begin
            spawn_cell_free =
                (qidx < GRID_CELLS) &&
                (qidx != head_idx) &&
                !snake_map[qidx] &&
                !food_occupies_index(qidx) &&
                !enemy_occupies_index(qidx);
        end
    endfunction

    function respawn_cell_free;
        input [15:0] qidx;
        begin
            respawn_cell_free =
                (qidx < GRID_CELLS) &&
                !food_occupies_index(qidx) &&
                !enemy_occupies_index(qidx);
        end
    endfunction

    function [15:0] xy_index;
        input [5:0] qx;
        input [4:0] qy;
        begin
            xy_index = qy * COLS + qx;
        end
    endfunction

    function [5:0] random_x;
        input [15:0] seed;
        begin
            random_x = seed[5:0];
            if (random_x >= COLS)
                random_x = random_x - COLS;
            if (random_x >= COLS)
                random_x = random_x - COLS;
        end
    endfunction

    function [4:0] random_y;
        input [15:0] seed;
        begin
            random_y = seed[10:6];
            if (random_y >= ROWS)
                random_y = random_y - ROWS;
        end
    endfunction

    function [1:0] opposite_dir;
        input [1:0] qdir;
        begin
            case (qdir)
                DIR_UP:    opposite_dir = DIR_DOWN;
                DIR_DOWN:  opposite_dir = DIR_UP;
                DIR_LEFT:  opposite_dir = DIR_RIGHT;
                default:   opposite_dir = DIR_LEFT;
            endcase
        end
    endfunction

    function respawn_step_in_range;
        input [5:0] qx;
        input [4:0] qy;
        input [1:0] qdir;
        begin
            case (qdir)
                DIR_UP:    respawn_step_in_range = (qy > 0);
                DIR_DOWN:  respawn_step_in_range = (qy < ROWS - 1);
                DIR_LEFT:  respawn_step_in_range = (qx > 0);
                default:   respawn_step_in_range = (qx < COLS - 1);
            endcase
        end
    endfunction

    function [5:0] respawn_step_x;
        input [5:0] qx;
        input [1:0] qdir;
        begin
            case (qdir)
                DIR_LEFT:  respawn_step_x = qx - 1'b1;
                DIR_RIGHT: respawn_step_x = qx + 1'b1;
                default:   respawn_step_x = qx;
            endcase
        end
    endfunction

    function [4:0] respawn_step_y;
        input [4:0] qy;
        input [1:0] qdir;
        begin
            case (qdir)
                DIR_UP:   respawn_step_y = qy - 1'b1;
                DIR_DOWN: respawn_step_y = qy + 1'b1;
                default:  respawn_step_y = qy;
            endcase
        end
    endfunction

    function respawn_body_step_free;
        input [5:0] qx;
        input [4:0] qy;
        input [1:0] qdir;
        reg [15:0] qidx;
        begin
            if (!respawn_step_in_range(qx, qy, qdir)) begin
                respawn_body_step_free = 1'b0;
            end else begin
                qidx = xy_index(respawn_step_x(qx, qdir), respawn_step_y(qy, qdir));
                respawn_body_step_free =
                    respawn_cell_free(qidx) &&
                    (qidx != respawn_forward_idx) &&
                    !snake_map[qidx];
            end
        end
    endfunction

    function enemy_spawn_valid;
        input [15:0] qidx;
        input [3:0] qlen;
        integer qx;
        integer sj;
        begin
            qx = qidx % COLS;
            enemy_spawn_valid = (qidx < GRID_CELLS) && (qx >= qlen - 1);
            for (sj = 0; sj < ENEMY_MAX_LEN; sj = sj + 1) begin
                if ((sj < qlen) && ((qx < sj) || !spawn_cell_free(qidx - sj)))
                    enemy_spawn_valid = 1'b0;
            end
        end
    endfunction

    function [3:0] random_enemy_len;
        input [15:0] seed;
        integer span;
        begin
            span = ENEMY_MAX_LEN - ENEMY_MIN_LEN + 1;
            random_enemy_len = ENEMY_MIN_LEN + (seed % span);
        end
    endfunction

    function [15:0] next_spawn_delay;
        input [15:0] seed;
        begin
            next_spawn_delay = ENEMY_SPAWN_MIN_TICKS + (seed & ENEMY_SPAWN_RANDOM_MASK);
        end
    endfunction

    function [15:0] next_food_delay;
        input [15:0] seed;
        begin
            next_food_delay = FOOD_SPAWN_MIN_TICKS + (seed & FOOD_SPAWN_RANDOM_MASK);
        end
    endfunction

    integer fx;
    integer fy;
    integer idx;
    integer nidx;
    integer tailidx;
    integer fidx;
    reg [15:0] new_head_ptr;
    reg [15:0] next_tail_ptr;
    reg [5:0] nx;
    reg [4:0] ny;

    integer ei;
    integer ej;
    integer enemy_base;
    reg [1:0] rand_dir;
    reg [1:0] try_dir;
    reg [15:0] enemy_next_idx;
    reg player_gameover;
    reg player_grew;
    reg player_hit_enemy_body;
    reg [2:0] killed_enemy_slot;
    reg player_ate_food;
    reg [1:0] eaten_food_type;
    reg player_damaged;
    reg [2:0] spawn_slot;
    reg [3:0] spawn_len;
    reg enemy_hit_player;
    reg enemy_can_move;

    reg enemy_head_cell;
    reg enemy_body_cell;
    integer de;
    integer ds;
    integer display_base;

    wire        cell_in_range = (cell_x < COLS) && (cell_y < ROWS);
    wire [15:0] cell_index_raw = cell_y * COLS + cell_x;
    wire [15:0] cell_index = cell_in_range ? cell_index_raw : 16'd0;
    wire        show_cells = cell_in_range && (state != 2'd0);
    wire        show_player = !(invincible_ticks != 0 && !invincible_blink);

    always @(*) begin
        enemy_head_cell = 1'b0;
        enemy_body_cell = 1'b0;
        for (de = 0; de < MAX_ENEMIES; de = de + 1) begin
            display_base = de * ENEMY_MAX_LEN;
            if (enemy_alive[de]) begin
                if (enemy_pos[display_base] == cell_index)
                    enemy_head_cell = 1'b1;
                for (ds = 1; ds < ENEMY_MAX_LEN; ds = ds + 1) begin
                    if ((ds < enemy_len[de]) && (enemy_pos[display_base + ds] == cell_index))
                        enemy_body_cell = 1'b1;
                end
            end
        end
    end

    assign cell_state =
        (!show_cells) ? EMPTY :
        (show_player && (cell_index == head_idx)) ? HEAD :
        enemy_head_cell ? ENEMY_HEAD :
        (food_valid && (cell_index == food_idx)) ? RED_FOOD :
        (yellow_food_valid && (cell_index == yellow_food_idx)) ? YELLOW_FOOD :
        (green_food_valid && (cell_index == green_food_idx)) ? BLUE_FOOD :
        enemy_body_cell ? ENEMY_BODY :
        (show_player && snake_map[cell_index]) ? BODY :
        EMPTY;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            score <= 0;
            lives <= INITIAL_LIVES;
            state <= 0;
            slen <= 0;
            head_ptr <= 0;
            tail_ptr <= 0;
            head_idx <= 0;
            food_idx <= 0;
            food_valid <= 1'b0;
            yellow_food_idx <= 0;
            yellow_food_valid <= 1'b0;
            green_food_idx <= 0;
            green_food_valid <= 1'b0;
            pending_food <= 1'b0;
            pending_food_type <= FOOD_RED;
            food_scan_idx <= 0;
            food_spawn_countdown <= next_food_delay(16'hACE1);
            invincible_ticks <= 0;
            invincible_blink <= 1'b1;
            growth_pending <= 0;
            pending_player_respawn <= 1'b0;
            respawn_scan_idx <= 0;
            respawn_path_mode <= 2'd0;
            respawn_phase <= RESP_SCAN;
            respawn_build_idx <= 0;
            respawn_head_idx <= 0;
            respawn_forward_idx <= 0;
            respawn_head_dir <= DIR_RIGHT;
            respawn_scan_x <= 0;
            respawn_scan_y <= 0;
            respawn_build_x <= 0;
            respawn_build_y <= 0;
            respawn_build_dir <= DIR_LEFT;
            respawn_bend_seen <= 1'b0;
            respawn_last_dir <= DIR_LEFT;
            snake_map <= {GRID_CELLS{1'b0}};
            hx <= 0;
            hy <= 0;
            cur_dir <= DIR_RIGHT;
            next_dir <= DIR_RIGHT;
            lfsr <= 16'hACE1;
            enemy_spawn_countdown <= next_spawn_delay(16'hACE1);
            pending_enemy_spawn <= 1'b0;
            enemy_scan_idx <= 0;
            for (ei = 0; ei < MAX_ENEMIES; ei = ei + 1) begin
                enemy_alive[ei] <= 1'b0;
                enemy_dir[ei] <= DIR_RIGHT;
                enemy_len[ei] <= ENEMY_MIN_LEN;
            end
            for (ej = 0; ej < MAX_ENEMIES * ENEMY_MAX_LEN; ej = ej + 1) begin
                enemy_pos[ej] <= INVALID_INDEX;
            end
        end else begin
            if (reset_game) begin
                score <= 0;
                lives <= INITIAL_LIVES;
                state <= 0;
                slen <= 0;
                head_ptr <= 0;
                tail_ptr <= 0;
                head_idx <= 0;
                food_idx <= 0;
                food_valid <= 1'b0;
                yellow_food_idx <= 0;
                yellow_food_valid <= 1'b0;
                green_food_idx <= 0;
                green_food_valid <= 1'b0;
                pending_food <= 1'b0;
                pending_food_type <= FOOD_RED;
                food_scan_idx <= 0;
                food_spawn_countdown <= next_food_delay(lfsr ^ 16'hBEEF);
                invincible_ticks <= 0;
                invincible_blink <= 1'b1;
                growth_pending <= 0;
                pending_player_respawn <= 1'b0;
                respawn_scan_idx <= 0;
                respawn_path_mode <= 2'd0;
                respawn_phase <= RESP_SCAN;
                respawn_build_idx <= 0;
                respawn_head_idx <= 0;
                respawn_forward_idx <= 0;
                respawn_head_dir <= DIR_RIGHT;
                respawn_scan_x <= 0;
                respawn_scan_y <= 0;
                respawn_build_x <= 0;
                respawn_build_y <= 0;
                respawn_build_dir <= DIR_LEFT;
                respawn_bend_seen <= 1'b0;
                respawn_last_dir <= DIR_LEFT;
                snake_map <= {GRID_CELLS{1'b0}};
                hx <= COLS/2;
                hy <= ROWS/2;
                cur_dir <= DIR_RIGHT;
                next_dir <= DIR_RIGHT;
                lfsr <= lfsr ^ 16'hBEEF;
                enemy_spawn_countdown <= next_spawn_delay(lfsr ^ 16'hBEEF);
                pending_enemy_spawn <= 1'b0;
                enemy_scan_idx <= 0;
                for (ei = 0; ei < MAX_ENEMIES; ei = ei + 1) begin
                    enemy_alive[ei] <= 1'b0;
                    enemy_dir[ei] <= DIR_RIGHT;
                    enemy_len[ei] <= ENEMY_MIN_LEN;
                end
                for (ej = 0; ej < MAX_ENEMIES * ENEMY_MAX_LEN; ej = ej + 1) begin
                    enemy_pos[ej] <= INVALID_INDEX;
                end
            end else begin
                lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

                if (pending_food) begin
                    if (!food_type_available(pending_food_type) || food_scan_idx >= GRID_CELLS) begin
                        pending_food <= 1'b0;
                    end else if ((food_scan_idx != head_idx) &&
                                 !snake_map[food_scan_idx] &&
                                 !food_occupies_index(food_scan_idx) &&
                                 !enemy_occupies_index(food_scan_idx)) begin
                        case (pending_food_type)
                            FOOD_RED: begin
                                food_idx <= food_scan_idx;
                                food_valid <= 1'b1;
                            end
                            FOOD_YELLOW: begin
                                yellow_food_idx <= food_scan_idx;
                                yellow_food_valid <= 1'b1;
                            end
                            FOOD_GREEN: begin
                                green_food_idx <= food_scan_idx;
                                green_food_valid <= 1'b1;
                            end
                        endcase
                        pending_food <= 1'b0;
                        food_spawn_countdown <= next_food_delay(lfsr ^ food_scan_idx);
                    end else begin
                        food_scan_idx <= food_scan_idx + 1'b1;
                    end
                end else if (start && state == 0) begin
                    hx <= COLS/2;
                    hy <= ROWS/2;
                    head_idx <= INIT_HEAD_IDX;
                    slen <= 3;
                    head_ptr <= 0;
                    tail_ptr <= 2;
                    snake_pos[0] <= INIT_HEAD_IDX;
                    snake_pos[1] <= INIT_BODY1_IDX;
                    snake_pos[2] <= INIT_BODY2_IDX;
                    snake_map <= initial_snake_map(1'b0);

                    fx = lfsr % COLS;
                    fy = (lfsr >> 4) % ROWS;
                    idx = fy * COLS + fx;
                    food_valid <= 1'b0;
                    yellow_food_valid <= 1'b0;
                    green_food_valid <= 1'b0;
                    pending_food_type <= select_food_type(lfsr);
                    if (!is_initial_snake_index(idx)) begin
                        case (select_food_type(lfsr))
                            FOOD_RED: begin
                                food_idx <= idx;
                                food_valid <= 1'b1;
                            end
                            FOOD_YELLOW: begin
                                yellow_food_idx <= idx;
                                yellow_food_valid <= 1'b1;
                            end
                            FOOD_GREEN: begin
                                green_food_idx <= idx;
                                green_food_valid <= 1'b1;
                            end
                        endcase
                    end else begin
                        pending_food <= 1'b1;
                        food_scan_idx <= 0;
                    end

                    state <= 1;
                    score <= 0;
                    lives <= INITIAL_LIVES;
                    invincible_ticks <= 0;
                    invincible_blink <= 1'b1;
                    growth_pending <= 0;
                    pending_player_respawn <= 1'b0;
                    respawn_scan_idx <= lfsr % GRID_CELLS;
                    respawn_path_mode <= lfsr[3:2];
                    respawn_phase <= RESP_SCAN;
                    respawn_build_idx <= 0;
                    respawn_head_idx <= 0;
                    respawn_forward_idx <= 0;
                    respawn_head_dir <= DIR_RIGHT;
                    respawn_scan_x <= random_x(lfsr);
                    respawn_scan_y <= random_y(lfsr);
                    respawn_build_x <= 0;
                    respawn_build_y <= 0;
                    respawn_build_dir <= DIR_LEFT;
                    respawn_bend_seen <= 1'b0;
                    respawn_last_dir <= DIR_LEFT;
                    food_spawn_countdown <= next_food_delay(lfsr ^ 16'h2468);
                    cur_dir <= start_direction(dir, dir_valid);
                    next_dir <= start_direction(dir, dir_valid);
                    enemy_spawn_countdown <= next_spawn_delay(lfsr ^ 16'h1357);
                    pending_enemy_spawn <= 1'b0;
                    enemy_scan_idx <= lfsr % GRID_CELLS;
                    for (ei = 0; ei < MAX_ENEMIES; ei = ei + 1) begin
                        enemy_alive[ei] <= 1'b0;
                        enemy_dir[ei] <= DIR_RIGHT;
                        enemy_len[ei] <= ENEMY_MIN_LEN;
                    end
                    for (ej = 0; ej < MAX_ENEMIES * ENEMY_MAX_LEN; ej = ej + 1) begin
                        enemy_pos[ej] <= INVALID_INDEX;
                    end
                end else begin
                    if (state == 1 && !pause) begin
                        if (pending_player_respawn) begin
                            if (respawn_phase == RESP_SCAN) begin
                                idx = xy_index(respawn_scan_x, respawn_scan_y);
                                try_dir = respawn_head_dir;
                                if (respawn_step_in_range(respawn_scan_x, respawn_scan_y, try_dir))
                                    nidx = xy_index(respawn_step_x(respawn_scan_x, try_dir),
                                                     respawn_step_y(respawn_scan_y, try_dir));
                                else
                                    nidx = INVALID_INDEX;

                                if ((nidx != INVALID_INDEX) &&
                                    respawn_cell_free(idx) &&
                                    respawn_cell_free(nidx)) begin
                                    respawn_head_idx <= idx;
                                    respawn_forward_idx <= nidx;
                                    respawn_build_idx <= 0;
                                    respawn_build_x <= respawn_scan_x;
                                    respawn_build_y <= respawn_scan_y;
                                    respawn_build_dir <= opposite_dir(try_dir);
                                    respawn_last_dir <= opposite_dir(try_dir);
                                    respawn_bend_seen <= 1'b0;
                                    respawn_phase <= RESP_BUILD;
                                    snake_map <= {GRID_CELLS{1'b0}};
                                end else begin
                                    respawn_scan_idx <= respawn_scan_idx + 1'b1;
                                    if (respawn_scan_x >= COLS - 1) begin
                                        respawn_scan_x <= 0;
                                        if (respawn_scan_y >= ROWS - 1) begin
                                            respawn_scan_y <= 0;
                                            respawn_head_dir <= respawn_head_dir + 1'b1;
                                            respawn_path_mode <= respawn_path_mode + 1'b1;
                                        end else begin
                                            respawn_scan_y <= respawn_scan_y + 1'b1;
                                        end
                                    end else begin
                                        respawn_scan_x <= respawn_scan_x + 1'b1;
                                    end
                                end
                            end else begin
                                idx = xy_index(respawn_build_x, respawn_build_y);
                                if (!respawn_cell_free(idx) ||
                                    (idx == respawn_forward_idx) ||
                                    ((respawn_build_idx != 0) && snake_map[idx])) begin
                                    snake_map <= {GRID_CELLS{1'b0}};
                                    respawn_phase <= RESP_SCAN;
                                    respawn_build_idx <= 0;
                                    respawn_scan_idx <= respawn_scan_idx + 1'b1;
                                    if (respawn_scan_x >= COLS - 1) begin
                                        respawn_scan_x <= 0;
                                        if (respawn_scan_y >= ROWS - 1) begin
                                            respawn_scan_y <= 0;
                                            respawn_head_dir <= respawn_head_dir + 1'b1;
                                            respawn_path_mode <= respawn_path_mode + 1'b1;
                                        end else begin
                                            respawn_scan_y <= respawn_scan_y + 1'b1;
                                        end
                                    end else begin
                                        respawn_scan_x <= respawn_scan_x + 1'b1;
                                    end
                                end else begin
                                    snake_pos[respawn_build_idx] <= idx;
                                    if (respawn_build_idx != 0)
                                        snake_map[idx] <= 1'b1;

                                    if (respawn_build_idx >= slen - 1'b1) begin
                                        if ((slen >= 5) && !respawn_bend_seen) begin
                                            snake_map <= {GRID_CELLS{1'b0}};
                                            respawn_phase <= RESP_SCAN;
                                            respawn_build_idx <= 0;
                                            respawn_scan_idx <= respawn_scan_idx + 1'b1;
                                            if (respawn_scan_x >= COLS - 1) begin
                                                respawn_scan_x <= 0;
                                                if (respawn_scan_y >= ROWS - 1) begin
                                                    respawn_scan_y <= 0;
                                                    respawn_head_dir <= respawn_head_dir + 1'b1;
                                                    respawn_path_mode <= respawn_path_mode + 1'b1;
                                                end else begin
                                                    respawn_scan_y <= respawn_scan_y + 1'b1;
                                                end
                                            end else begin
                                                respawn_scan_x <= respawn_scan_x + 1'b1;
                                            end
                                        end else begin
                                            hx <= respawn_scan_x;
                                            hy <= respawn_scan_y;
                                            head_idx <= respawn_head_idx;
                                            head_ptr <= 0;
                                            tail_ptr <= slen - 1'b1;
                                            cur_dir <= respawn_head_dir;
                                            next_dir <= respawn_head_dir;
                                            pending_player_respawn <= 1'b0;
                                            respawn_phase <= RESP_SCAN;
                                        end
                                    end else begin
                                        enemy_can_move = 1'b0;
                                        if ((slen >= 5) && !respawn_bend_seen && (respawn_build_idx >= 2)) begin
                                            try_dir = (respawn_path_mode[0]) ? turn_right(respawn_build_dir) : turn_left(respawn_build_dir);
                                            if (respawn_body_step_free(respawn_build_x, respawn_build_y, try_dir)) begin
                                                enemy_can_move = 1'b1;
                                            end else begin
                                                try_dir = (respawn_path_mode[0]) ? turn_left(respawn_build_dir) : turn_right(respawn_build_dir);
                                                if (respawn_body_step_free(respawn_build_x, respawn_build_y, try_dir))
                                                    enemy_can_move = 1'b1;
                                            end
                                        end else begin
                                            try_dir = respawn_build_dir;
                                            if (respawn_body_step_free(respawn_build_x, respawn_build_y, try_dir))
                                                enemy_can_move = 1'b1;
                                        end

                                        if (!enemy_can_move && !((slen >= 5) && !respawn_bend_seen && (respawn_build_idx >= 2))) begin
                                            case (respawn_path_mode ^ respawn_build_idx[1:0])
                                                2'd0: try_dir = turn_left(respawn_build_dir);
                                                2'd1: try_dir = turn_right(respawn_build_dir);
                                                2'd2: try_dir = respawn_build_dir;
                                                default: try_dir = turn_left(respawn_build_dir);
                                            endcase
                                            if (respawn_body_step_free(respawn_build_x, respawn_build_y, try_dir)) begin
                                                enemy_can_move = 1'b1;
                                            end else begin
                                                try_dir = turn_right(respawn_build_dir);
                                                if (respawn_body_step_free(respawn_build_x, respawn_build_y, try_dir)) begin
                                                    enemy_can_move = 1'b1;
                                                end else begin
                                                    try_dir = turn_left(respawn_build_dir);
                                                    if (respawn_body_step_free(respawn_build_x, respawn_build_y, try_dir))
                                                        enemy_can_move = 1'b1;
                                                end
                                            end
                                        end

                                        if (enemy_can_move) begin
                                            respawn_build_x <= respawn_step_x(respawn_build_x, try_dir);
                                            respawn_build_y <= respawn_step_y(respawn_build_y, try_dir);
                                            if (respawn_build_idx >= 2)
                                                respawn_bend_seen <= respawn_bend_seen || (try_dir != respawn_last_dir);
                                            respawn_last_dir <= try_dir;
                                            respawn_build_dir <= try_dir;
                                            respawn_build_idx <= respawn_build_idx + 1'b1;
                                        end else begin
                                            snake_map <= {GRID_CELLS{1'b0}};
                                            respawn_phase <= RESP_SCAN;
                                            respawn_build_idx <= 0;
                                            respawn_scan_idx <= respawn_scan_idx + 1'b1;
                                            if (respawn_scan_x >= COLS - 1) begin
                                                respawn_scan_x <= 0;
                                                if (respawn_scan_y >= ROWS - 1) begin
                                                    respawn_scan_y <= 0;
                                                    respawn_head_dir <= respawn_head_dir + 1'b1;
                                                    respawn_path_mode <= respawn_path_mode + 1'b1;
                                                end else begin
                                                    respawn_scan_y <= respawn_scan_y + 1'b1;
                                                end
                                            end else begin
                                                respawn_scan_x <= respawn_scan_x + 1'b1;
                                            end
                                        end
                                    end
                                end
                            end
                        end else if (pending_enemy_spawn) begin
                            spawn_slot = first_dead_enemy_slot(1'b0);
                            if (spawn_slot == NO_ENEMY_SLOT) begin
                                pending_enemy_spawn <= 1'b0;
                                enemy_spawn_countdown <= next_spawn_delay(lfsr);
                            end else begin
                                spawn_len = random_enemy_len(lfsr ^ enemy_scan_idx);
                                if (enemy_spawn_valid(enemy_scan_idx, spawn_len)) begin
                                    enemy_base = spawn_slot * ENEMY_MAX_LEN;
                                    enemy_alive[spawn_slot] <= 1'b1;
                                    enemy_dir[spawn_slot] <= DIR_RIGHT;
                                    enemy_len[spawn_slot] <= spawn_len;
                                    for (ej = 0; ej < ENEMY_MAX_LEN; ej = ej + 1) begin
                                        if (ej < spawn_len)
                                            enemy_pos[enemy_base + ej] <= enemy_scan_idx - ej;
                                        else
                                            enemy_pos[enemy_base + ej] <= INVALID_INDEX;
                                    end
                                    pending_enemy_spawn <= 1'b0;
                                    enemy_spawn_countdown <= next_spawn_delay(lfsr ^ enemy_scan_idx);
                                end else if (enemy_scan_idx >= GRID_CELLS - 1) begin
                                    enemy_scan_idx <= 0;
                                end else begin
                                    enemy_scan_idx <= enemy_scan_idx + 1'b1;
                                end
                            end
                        end

                        if (dir_valid && !is_opposite_dir(cur_dir, dir)) begin
                            next_dir <= dir;
                        end
                    end

                    if (tick && state == 1 && !pause && !pending_player_respawn) begin
                        player_gameover = 1'b0;
                        player_grew = 1'b0;
                        player_hit_enemy_body = 1'b0;
                        player_ate_food = 1'b0;
                        eaten_food_type = FOOD_RED;
                        player_damaged = 1'b0;
                        killed_enemy_slot = 3'd0;

                        if (invincible_ticks != 0) begin
                            invincible_ticks <= invincible_ticks - 1'b1;
                            invincible_blink <= ~invincible_blink;
                        end else begin
                            invincible_blink <= 1'b1;
                        end

                        nx = hx;
                        ny = hy;
                        case (next_dir)
                            DIR_UP:    ny = hy - 1;
                            DIR_DOWN:  ny = hy + 1;
                            DIR_LEFT:  nx = hx - 1;
                            DIR_RIGHT: nx = hx + 1;
                        endcase

                        if (slen == 0 || slen > MAXLEN) begin
                            state <= 3;
                            player_gameover = 1'b1;
                        end else if (nx >= COLS || ny >= ROWS) begin
                            if (invincible_ticks == 0) begin
                                player_damaged = 1'b1;
                                if (lives <= 1) begin
                                    lives <= 0;
                                    state <= 3;
                                    player_gameover = 1'b1;
                                end else begin
                                    lives <= lives - 1'b1;
                                    invincible_ticks <= INVINCIBLE_TICKS;
                                    invincible_blink <= 1'b0;
                                end
                            end
                        end else begin
                            nidx = ny * COLS + nx;
                            tailidx = snake_pos[tail_ptr];

                            if ((nidx == head_idx) || (snake_map[nidx] && nidx != tailidx)) begin
                                player_damaged = 1'b1;
                                if (lives <= 1) begin
                                    lives <= 0;
                                    state <= 3;
                                    player_gameover = 1'b1;
                                end else begin
                                    lives <= lives - 1'b1;
                                    invincible_ticks <= INVINCIBLE_TICKS;
                                    invincible_blink <= 1'b0;
                                    growth_pending <= 0;
                                    pending_player_respawn <= 1'b1;
                                    respawn_scan_idx <= 0;
                                    respawn_scan_x <= random_x(lfsr);
                                    respawn_scan_y <= random_y(lfsr);
                                    respawn_head_dir <= lfsr[1:0];
                                    respawn_path_mode <= lfsr[3:2];
                                    respawn_phase <= RESP_SCAN;
                                    respawn_build_idx <= 0;
                                    respawn_bend_seen <= 1'b0;
                                end
                            end else if (enemy_head_at_index(nidx)) begin
                                if (invincible_ticks == 0) begin
                                    player_damaged = 1'b1;
                                    if (lives <= 1) begin
                                        lives <= 0;
                                        state <= 3;
                                        player_gameover = 1'b1;
                                    end else begin
                                        lives <= lives - 1'b1;
                                        invincible_ticks <= INVINCIBLE_TICKS;
                                        invincible_blink <= 1'b0;
                                    end
                                end
                            end else begin
                                for (ei = 0; ei < MAX_ENEMIES; ei = ei + 1) begin
                                    enemy_base = ei * ENEMY_MAX_LEN;
                                    if (enemy_alive[ei]) begin
                                        for (ej = 1; ej < ENEMY_MAX_LEN; ej = ej + 1) begin
                                            if ((ej < enemy_len[ei]) &&
                                                (enemy_pos[enemy_base + ej] == nidx) &&
                                                !player_hit_enemy_body) begin
                                                player_hit_enemy_body = 1'b1;
                                                killed_enemy_slot = ei[2:0];
                                            end
                                        end
                                    end
                                end

                                if (player_hit_enemy_body) begin
                                    enemy_alive[killed_enemy_slot] <= 1'b0;
                                end

                                if (food_valid && (nidx == food_idx)) begin
                                    player_ate_food = 1'b1;
                                    eaten_food_type = FOOD_RED;
                                end else if (yellow_food_valid && (nidx == yellow_food_idx)) begin
                                    player_ate_food = 1'b1;
                                    eaten_food_type = FOOD_YELLOW;
                                end else if (green_food_valid && (nidx == green_food_idx)) begin
                                    player_ate_food = 1'b1;
                                    eaten_food_type = FOOD_GREEN;
                                end

                                if (player_ate_food && !player_hit_enemy_body && (eaten_food_type != FOOD_GREEN)) begin
                                    if (slen < MAXLEN) begin
                                        player_grew = 1'b1;
                                        new_head_ptr = prev_snake_index(head_ptr);
                                        snake_pos[new_head_ptr] <= nidx;
                                        head_ptr <= new_head_ptr;
                                        slen <= slen + 1;
                                        snake_map[head_idx] <= 1'b1;
                                        head_idx <= nidx;
                                        hx <= nx;
                                        hy <= ny;
                                        cur_dir <= next_dir;
                                        if (eaten_food_type == FOOD_RED) begin
                                            score <= score + 1;
                                            food_valid <= 1'b0;
                                        end else begin
                                            score <= score + 2;
                                            yellow_food_valid <= 1'b0;
                                            if (slen < MAXLEN - 1)
                                                growth_pending <= growth_pending + 1'b1;
                                        end
                                    end else begin
                                        state <= 3;
                                        player_gameover = 1'b1;
                                    end
                                end else begin
                                    new_head_ptr = prev_snake_index(head_ptr);
                                    next_tail_ptr = prev_snake_index(tail_ptr);
                                    snake_pos[new_head_ptr] <= nidx;
                                    head_ptr <= new_head_ptr;
                                    if (growth_pending != 0) begin
                                        slen <= slen + 1'b1;
                                        growth_pending <= growth_pending - 1'b1;
                                    end else begin
                                        tail_ptr <= next_tail_ptr;
                                        snake_map[tailidx] <= 1'b0;
                                    end
                                    snake_map[head_idx] <= 1'b1;
                                    head_idx <= nidx;
                                    hx <= nx;
                                    hy <= ny;
                                    cur_dir <= next_dir;
                                    if (player_hit_enemy_body)
                                        score <= score + 5;
                                    else if (player_ate_food && (eaten_food_type == FOOD_GREEN)) begin
                                        green_food_valid <= 1'b0;
                                        if (lives < MAX_LIVES)
                                            lives <= lives + 1'b1;
                                    end
                                end
                            end
                        end

                        if (!player_gameover && !player_damaged) begin
                            for (ei = 0; ei < MAX_ENEMIES; ei = ei + 1) begin
                                enemy_base = ei * ENEMY_MAX_LEN;
                                if (enemy_alive[ei] &&
                                    !(player_hit_enemy_body && (killed_enemy_slot == ei[2:0]))) begin
                                    case (ei)
                                        0: rand_dir = lfsr[1:0];
                                        1: rand_dir = lfsr[3:2];
                                        2: rand_dir = lfsr[5:4];
                                        3: rand_dir = lfsr[7:6];
                                        default: rand_dir = lfsr[9:8];
                                    endcase

                                    if (is_opposite_dir(enemy_dir[ei], rand_dir))
                                        try_dir = turn_right(enemy_dir[ei]);
                                    else
                                        try_dir = rand_dir;

                                    enemy_next_idx = next_grid_index(enemy_pos[enemy_base], try_dir);
                                    enemy_can_move = enemy_move_valid(ei[2:0], try_dir);
                                    if (enemy_can_move) begin
                                        enemy_hit_player =
                                            (enemy_next_idx == nidx) ||
                                            (enemy_next_idx == head_idx) ||
                                            (snake_map[enemy_next_idx] &&
                                             (player_grew || (enemy_next_idx != tailidx)));

                                        if (enemy_hit_player && (invincible_ticks == 0)) begin
                                            if (lives <= 1) begin
                                                lives <= 0;
                                                state <= 3;
                                                player_gameover = 1'b1;
                                            end else begin
                                                lives <= lives - 1'b1;
                                                invincible_ticks <= INVINCIBLE_TICKS;
                                                invincible_blink <= 1'b0;
                                                player_damaged = 1'b1;
                                            end
                                        end

                                        for (ej = ENEMY_MAX_LEN - 1; ej > 0; ej = ej - 1) begin
                                            enemy_pos[enemy_base + ej] <= enemy_pos[enemy_base + ej - 1];
                                        end
                                        enemy_pos[enemy_base] <= enemy_next_idx;
                                        enemy_dir[ei] <= try_dir;
                                    end
                                end
                            end

                            if (enemy_alive_count(1'b0) >= active_enemy_limit) begin
                                pending_enemy_spawn <= 1'b0;
                                enemy_spawn_countdown <= next_spawn_delay(lfsr);
                            end else if (!pending_enemy_spawn) begin
                                if (enemy_spawn_countdown == 0) begin
                                    pending_enemy_spawn <= 1'b1;
                                    enemy_scan_idx <= lfsr % GRID_CELLS;
                                end else begin
                                    enemy_spawn_countdown <= enemy_spawn_countdown - 1'b1;
                                end
                            end

                            if (all_food_present(1'b0)) begin
                                pending_food <= 1'b0;
                                food_spawn_countdown <= next_food_delay(lfsr ^ 16'h55AA);
                            end else if (!pending_food) begin
                                if (food_spawn_countdown == 0) begin
                                    pending_food_type <= select_food_type(lfsr ^ head_idx);
                                    pending_food <= 1'b1;
                                    food_scan_idx <= lfsr % GRID_CELLS;
                                end else begin
                                    food_spawn_countdown <= food_spawn_countdown - 1'b1;
                                end
                            end
                        end
                    end
                end
            end
        end
    end

endmodule
