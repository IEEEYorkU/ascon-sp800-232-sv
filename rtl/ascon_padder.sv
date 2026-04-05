/* =============================================================================
 * Module Name: ascon_padder
 * Author(s):   Kiet Le, Tirth Patel, Kevin Duong
 * Description:
 * AXI4-Stream pre-processor and framer for the Ascon Hardware Accelerator.
 *
 * Key Responsibilities:
 * 1. Endian Swap: Converts external Little-Endian AXI data to internal Big-Endian.
 * 2. Padding Injection: Appends Ascon's '10...0' pad to partial words (AD, PT, MSG, Z).
 * 3. Rate Alignment: Manages 64-bit (Hash) vs 128-bit (AEAD) block boundaries,
 * automatically generating zero-padded filler words when needed.
 * 4. Pass-Through: Leaves unpadded streams (KEY, NONCE, CT) untouched to
 * allow downstream FSMs to process fractional bytes directly.
 * ============================================================================= */

`timescale 1ns / 1ps

import ascon_pkg::*;

module ascon_padder (
    input  logic          clk,
    input  logic          rst,

    // Configuration
    input  ascon_mode_t   mode_i,

    // Raw AXI4-Stream Slave (Data FROM Outside World - LITTLE ENDIAN)
    input  ascon_word_t   s_axis_tdata_i,
    input  logic [7:0]    s_axis_tkeep_i,
    input  axi_tuser_t    s_axis_tuser_i,
    input  logic          s_axis_tlast_i,
    input  logic          s_axis_tvalid_i,
    output logic          s_axis_tready_o,

    // Padded AXI4-Stream Master (Data TO Internal Logic - BIG ENDIAN)
    output ascon_word_t   padded_tdata_o,
    output logic [7:0]    padded_tkeep_o,
    output axi_tuser_t    padded_tuser_o,
    output logic          padded_tlast_o,
    output logic          padded_tvalid_o,
    input  logic          padded_tready_i
);

    // =======================================================================
    // INTERNAL LOGIC DECLARATIONS
    // =======================================================================
    typedef enum logic [1:0] {
        STATE_IDLE_PASS = 2'b00,
        STATE_PAD_WORD1 = 2'b01, // Generates AEAD alignment zeros
        STATE_PAD_WORD2 = 2'b10  // Generates 0x80... carry blocks
    } padder_state_t;

    padder_state_t state, next_state;

    // Tracks 128-bit block alignment for AEAD (0 = 1st word, 1 = 2nd word)
    logic word_count_reg, word_count_next;

    // Identifies TUSER groups that require Ascon padding
    logic is_padding_group;
    assign is_padding_group = (s_axis_tuser_i == TUSER_AD ||
                               s_axis_tuser_i == TUSER_PT ||
                               s_axis_tuser_i == TUSER_MSG ||
                               s_axis_tuser_i == TUSER_Z);

    logic is_aead_mode;
    assign is_aead_mode = ((mode_i == MODE_AEAD_ENC) || (mode_i == MODE_AEAD_DEC));

    // Registers for multi-cycle padding generation
    ascon_word_t masked_data, pad_word2_data_next, pad_word2_data_reg;
    axi_tuser_t held_tuser_next, held_tuser_reg;

    // -----------------------------------------------------------------------
    // 1. Endianness & Padding Generators
    // -----------------------------------------------------------------------

    // Reverses byte order of a 64-bit word
    function automatic ascon_word_t swap_bytes(input ascon_word_t data);
        return {data[7:0],   data[15:8],  data[23:16], data[31:24],
                data[39:32], data[47:40], data[55:48], data[63:56]};
    endfunction

    // Converts LE AXI data directly into padded BE Ascon data based on TKEEP
    function automatic ascon_word_t apply_padding(
        input ascon_word_t data,
        input logic [7:0]  keep
    );
        case (keep)
            8'h00:   apply_padding = {8'h80, 56'h00_00_00_00_00_00_00};
            8'h01:   apply_padding = {data[7:0], 8'h80, 48'h00_00_00_00_00_00};
            8'h03:   apply_padding = {data[7:0], data[15:8], 8'h80, 40'h00_00_00_00_00};
            8'h07:   apply_padding = {data[7:0], data[15:8], data[23:16], 8'h80, 32'h00_00_00_00};
            8'h0F:   apply_padding = {data[7:0], data[15:8], data[23:16], data[31:24], 8'h80, 24'h00_00_00};
            8'h1F:   apply_padding = {data[7:0], data[15:8], data[23:16], data[31:24], data[39:32], 8'h80, 16'h00_00};
            8'h3F:   apply_padding = {data[7:0], data[15:8], data[23:16], data[31:24], data[39:32], data[47:40], 8'h80, 8'h00};
            8'h7F:   apply_padding = {data[7:0], data[15:8], data[23:16], data[31:24], data[39:32], data[47:40], data[55:48], 8'h80};
            default: apply_padding = swap_bytes(data);
        endcase
    endfunction

    // Power Optimization: Only compute padding on valid, final, partial words
    // belonging to a padding group. Otherwise, just execute the byte-swap.
    always_comb begin
        masked_data = swap_bytes(s_axis_tdata_i);

        if (s_axis_tvalid_i && is_padding_group && s_axis_tlast_i && (s_axis_tkeep_i != 8'hFF)) begin
            masked_data = apply_padding(s_axis_tdata_i, s_axis_tkeep_i);
        end
    end

    // -----------------------------------------------------------------------
    // 2. Rate Alignment & Carry FSM
    // -----------------------------------------------------------------------

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state              <= STATE_IDLE_PASS;
            held_tuser_reg     <= TUSER_RESERVED;
            pad_word2_data_reg <= '0;
            word_count_reg     <= 1'b0;
        end else begin
            state              <= next_state;
            held_tuser_reg     <= held_tuser_next;
            pad_word2_data_reg <= pad_word2_data_next;
            word_count_reg     <= word_count_next;
        end
    end

    always_comb begin
        next_state          = state;
        word_count_next     = word_count_reg;
        held_tuser_next     = held_tuser_reg;
        pad_word2_data_next = pad_word2_data_reg;

        // Default Pass-Through Assignments
        s_axis_tready_o = padded_tready_i;
        padded_tvalid_o = s_axis_tvalid_i;
        padded_tdata_o  = masked_data;
        padded_tkeep_o  = s_axis_tkeep_i;
        padded_tuser_o  = s_axis_tuser_i;
        padded_tlast_o  = s_axis_tlast_i; // Defaults to transparent pass-through (CT, KEY)

        case (state)
            STATE_IDLE_PASS: begin
                if (is_padding_group) begin
                    // Downstream block-counters expect full words (no fractional TKEEP)
                    padded_tkeep_o = 8'hFF;

                    // Override TLAST based on rate alignment needs
                    if (s_axis_tvalid_i && s_axis_tlast_i) begin
                        if (s_axis_tkeep_i == 8'hFF) begin
                            // Full word requires a spillover carry block, so delay TLAST.
                            // Exception: AEAD block completes on word 1, so assert TLAST now.
                            if (is_aead_mode && word_count_reg != 1'b0) padded_tlast_o = 1'b1;
                            else padded_tlast_o = 1'b0;
                        end else begin
                            // Partial word absorbs the 0x80 padding perfectly.
                            // Exception: AEAD word 0 needs a subsequent zero-word to align 128 bits.
                            if (is_aead_mode && word_count_reg == 1'b0) padded_tlast_o = 1'b0;
                            else padded_tlast_o = 1'b1;
                        end
                    end

                    // FSM Transitions & Carry-Block Generation
                    if (s_axis_tvalid_i && padded_tready_i) begin
                        if (s_axis_tlast_i) begin
                            held_tuser_next = s_axis_tuser_i;
                            word_count_next = 1'b0;

                            if (s_axis_tkeep_i == 8'hFF) begin
                                if (is_aead_mode) begin
                                    if (word_count_reg == 1'b0) begin
                                        // AEAD Word 0 full: Follow with 0x80 carry block
                                        pad_word2_data_next = 64'h8000_0000_0000_0000;
                                        next_state          = STATE_PAD_WORD2;
                                    end else begin
                                        // AEAD Word 1 full: Start new block with [0x80] then [0x00]
                                        pad_word2_data_next = 64'h0000_0000_0000_0000;
                                        next_state          = STATE_PAD_WORD1;
                                    end
                                end else begin
                                    // HASH/XOF full: Follow with 0x80 carry block
                                    pad_word2_data_next = 64'h8000_0000_0000_0000;
                                    next_state          = STATE_PAD_WORD2;
                                end
                            end else begin
                                if (is_aead_mode && (word_count_reg == 1'b0)) begin
                                    // AEAD Word 0 partial: Follow with zero-block to align 128-bit boundary
                                    pad_word2_data_next = 64'h0000_0000_0000_0000;
                                    next_state          = STATE_PAD_WORD2;
                                end
                            end
                        end else begin
                            // Toggle AEAD word count on non-last beats
                            word_count_next = is_aead_mode ? ~word_count_reg : 1'b0;
                        end
                    end
                end
            end

            STATE_PAD_WORD1: begin
                // Emits generated Word 0 for AEAD dual-carry sequences
                s_axis_tready_o = 1'b0;
                padded_tvalid_o = 1'b1;
                padded_tdata_o  = 64'h8000_0000_0000_0000;
                padded_tkeep_o  = 8'hFF;
                padded_tuser_o  = held_tuser_reg;
                padded_tlast_o  = 1'b0;

                if (padded_tready_i) begin
                    next_state = STATE_PAD_WORD2;
                end
            end

           STATE_PAD_WORD2: begin
                // Emits final carry block (0x80... or 0x00...) and completes the packet
                s_axis_tready_o = 1'b0;
                padded_tvalid_o = 1'b1;
                padded_tdata_o  = pad_word2_data_reg;
                padded_tkeep_o  = 8'hFF;
                padded_tuser_o  = held_tuser_reg;
                padded_tlast_o  = 1'b1;

                if (padded_tready_i) begin
                    next_state      = STATE_IDLE_PASS;
                    word_count_next = 1'b0;
                end
            end

            default: next_state = STATE_IDLE_PASS;
        endcase
    end

endmodule
