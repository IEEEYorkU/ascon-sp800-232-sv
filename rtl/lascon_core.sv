/*
 * Module Name: lascon_core
 * Author(s):   Kiet Le, Arthur Sabadini
 * Description:
 * The central mathematical engine ("The Muscle") for the Lascon Cryptographic
 * Accelerator. This module encapsulates the 320-bit Ascon state and iteratively
 * executes the three permutation layers (Constant Addition, Substitution, and
 * Linear Diffusion) for a configurable number of rounds.
 *
 * Design Philosophy (Decoupled Data/Control):
 * This core is designed as a "dumb" slave permutation block. It possesses strictly
 * zero knowledge of higher-level cryptographic protocols, AXI4-Stream handshaking,
 * padding rules, or the difference between AEAD and Hashing. It relies entirely
 * on external protocol-specific orchestrators (FSMs) to feed it data, dictate
 * the number of rounds, and trigger the permutation.
 *
 * Implementation Details:
 * - Datapath Pipeline: Instantiates the three combinatorial layers of the Ascon
 * round logic (p_C -> p_S -> p_L).
 * - Control FSM: Built using a robust 4-process methodology (State Register,
 * Next State Logic, Output Decoder, Action Logic) to ensure glitch-free
 * synthesis and predictable timing.
 * - Memory Mapping: The 320-bit internal state is addressable as five distinct
 * 64-bit words via `word_sel_i`, allowing external controllers to overwrite
 * specific lanes (S_0 ... S_4) independently.
 * - Round Indexing: Implements a 0-indexed round counter (`rnd_cnt`). For the
 * 8-round permutation (p^8), the required mathematical suffix offset (+4) is
 * delegated to the `constant_addition_layer` module to extract the correct
 * round constants.
 *
 * Ref: NIST SP 800-232, Section 3
 */
`timescale 1ns / 1ps

import lascon_pkg::*;

module lascon_core #(
    parameter int LASCON_VARIANT = 0
)(
    input   logic           clk,
    input   logic           rst,

    // Permutation Control
    input   logic           start_perm_i,
    input   logic           round_config_i,

    // Read/Write Word Address
    input   logic [2:0]     word_sel_i,

    // Data I/O Control
    input   ascon_word_t    data_i,
    input   logic           write_en_i,


    // Data Output (according to word_sel_i)
    output  ascon_word_t    data_o,

    // Permutation Complete
    output  logic           ready_o
);

    localparam int SBOX_WIDTH = (LASCON_VARIANT == 1) ? 1 : 64;
    localparam int SBOX_CYCLES = 64 / SBOX_WIDTH;

    // FSM States
    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_PERM,
        STATE_PERM_DIFF
    } state_t;
    state_t state, next_state;

    rnd_t rnd_cnt;
    ascon_state_t state_array;

    // Permutation Layers Output
    ascon_state_t addition_state_array_o, diffusion_state_array_o;
    logic [4:0][SBOX_WIDTH-1:0] sbox_chunk_in;
    logic [4:0][SBOX_WIDTH-1:0] sbox_chunk_out;
    ascon_state_t diff_input_array;

    // Permutation Layers Instances
    constant_addition_layer const_add(
        .rnd_i(rnd_cnt),
        .state_array_i(state_array),
        .state_array_o(addition_state_array_o)
    );

    generate
        if (SBOX_WIDTH == 64) begin : gen_comb_64
            always_comb begin
                for (int i = 0; i < 5; i++) begin
                    sbox_chunk_in[i] = addition_state_array_o[i];
                    diff_input_array[i] = sbox_chunk_out[i];
                end
            end
        end else begin : gen_comb_serial
            logic [7:0] round_const;
            assign round_const = {~rnd_cnt, rnd_cnt};
            always_comb begin
                for (int i = 0; i < 5; i++) begin
                    sbox_chunk_in[i] = state_array[i][0 +: SBOX_WIDTH];
                end
                if (gen_col_cnt.col_cnt * SBOX_WIDTH < 8) begin
                    sbox_chunk_in[2] = state_array[2][0 +: SBOX_WIDTH] ^ round_const[gen_col_cnt.col_cnt * SBOX_WIDTH +: SBOX_WIDTH];
                end
                diff_input_array = state_array;
            end
        end
    endgenerate

    substitution_layer #(
        .SBOX_WIDTH(SBOX_WIDTH)
    ) substitution (
        .state_chunk_i(sbox_chunk_in),
        .state_chunk_o(sbox_chunk_out)
    );

    linear_diffusion_layer diffusion(
        .state_array_i(diff_input_array),
        .state_array_o(diffusion_state_array_o)
    );

    // FSM Control Process 1: State Register (Sequential)
    // ----------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end

    generate
        if (SBOX_WIDTH == 64) begin : gen_fsm_64
            // Next State Logic
            always_comb begin
                next_state = state;
                case(state)
                    STATE_IDLE:      if (start_perm_i) next_state = STATE_PERM;
                    STATE_PERM:      if (rnd_cnt >= 4'd11) next_state = STATE_IDLE;
                    STATE_PERM_DIFF: next_state = STATE_IDLE; // Should not reach
                    default:         next_state = STATE_IDLE;
                endcase
            end

            // Action Logic
            always_ff @(posedge clk) begin
                case (state)
                    STATE_IDLE: begin
                        if (start_perm_i) rnd_cnt <= round_config_i ? 4'd0 : 4'd4;
                        if (write_en_i) state_array[word_sel_i] <= data_i;
                    end
                    STATE_PERM: begin
                        state_array <= diffusion_state_array_o;
                        if (rnd_cnt < 4'd11) rnd_cnt <= rnd_cnt + 4'd1;
                    end
                endcase
            end

        end else begin : gen_col_cnt
            logic [6:0] col_cnt;

            always_ff @(posedge clk or posedge rst) begin
                if (rst) col_cnt <= '0;
                else begin
                    if (state == STATE_IDLE && start_perm_i) col_cnt <= '0;
                    else if (state == STATE_PERM) col_cnt <= col_cnt + 1;
                    else if (state == STATE_PERM_DIFF) col_cnt <= '0;
                end
            end

            // Next State Logic
            always_comb begin
                next_state = state;
                case(state)
                    STATE_IDLE:      if (start_perm_i) next_state = STATE_PERM;
                    STATE_PERM:      if (col_cnt == SBOX_CYCLES - 1) next_state = STATE_PERM_DIFF;
                    STATE_PERM_DIFF: if (rnd_cnt >= 4'd11) next_state = STATE_IDLE; else next_state = STATE_PERM;
                    default:         next_state = STATE_IDLE;
                endcase
            end

            // Action Logic
            always_ff @(posedge clk) begin
                case (state)
                    STATE_IDLE: begin
                        if (start_perm_i) rnd_cnt <= round_config_i ? 4'd0 : 4'd4;
                        if (write_en_i) state_array[word_sel_i] <= data_i;
                    end
                    STATE_PERM: begin
                        for (int i = 0; i < 5; i++) begin
                            state_array[i] <= {sbox_chunk_out[i], state_array[i][63 : SBOX_WIDTH]};
                        end
                    end
                    STATE_PERM_DIFF: begin
                        state_array <= diffusion_state_array_o;
                        if (rnd_cnt < 4'd11) rnd_cnt <= rnd_cnt + 4'd1;
                    end
                endcase
            end
        end
    endgenerate

    assign ready_o = (state == STATE_IDLE);

    // Combinational Output Data
    assign data_o = state_array[word_sel_i];

endmodule
