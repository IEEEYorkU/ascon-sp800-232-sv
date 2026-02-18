/* =============================================================================
 * Module Name: ascon_padder
 * Author(s):   Kiet Le
 * Description:
 * AXI4-Stream pre-processor (Data Formatter/Framer) for the Ascon Hardware
 * Accelerator. This module acts as a pipeline stage between the raw external
 * AXI4-Stream data and the internal protocol-specific FSMs (AEAD and Hash).
 *
 * Architecture & Role:
 * By intercepting the raw AXI stream, this module abstracts away the complex
 * bit-level padding and rate-alignment rules of the NIST SP 800-232 standard.
 * This allows the downstream sub-FSMs to act as incredibly simple block-counters
 * that only trigger permutations when they see `padded_tlast == 1`.
 *
 * Key Responsibilities & Design Requirements:
 * * 1. The Ascon Padding Rule (TKEEP Translation)
 * - Ascon requires a single `1` bit appended immediately after the last
 * valid byte of a message, followed by `0`s to fill the block.
 * - The padder monitors `s_axis_tkeep` on the final word (`s_axis_tlast == 1`).
 * - It dynamically masks the invalid bytes and injects the `1000...0` bit
 * pattern. It then outputs `padded_tkeep = 8'hFF` so the FSMs do not
 * need to handle fractional bytes.
 *
 * 2. Rate Alignment State Machine (The 64-bit vs 128-bit Challenge)
 * - Ascon-Hash256 uses a 64-bit rate (1 word).
 * - Ascon-AEAD128 uses a 128-bit rate (2 words).
 * - If `mode_i` is AEAD, and a padded message ends perfectly on the *first*
 *   64-bit word of the 128-bit block, the padder must NOT assert `padded_tlast`.
 * - Instead, it must halt the upstream stream (`s_axis_tready = 0`), stall
 * for one clock cycle, output a *second* 64-bit word of pure `0`s, and
 * then assert `padded_tlast = 1` to tell the AEAD FSM the block is full.
 *
 * 3. TUSER Packet Filtering & The Decryption Exception
 * The module routes and modifies data strictly based on the `s_axis_tuser` flag:
 * * - GROUP A (Pass-through): TUSER_KEY, TUSER_NONCE, TUSER_TAG.
 * Action: Pass data and tlast through unmodified. Do not apply padding.
 * * - GROUP B (Pad on TLAST): TUSER_AD, TUSER_PT, TUSER_MSG, TUSER_Z.
 * Action: When `tlast == 1`, consume `tkeep`, apply the Ascon bit-padding
 * rule, handle rate alignment, and output `padded_tkeep = 8'hFF`.
 * * - GROUP C (The Decryption Exception): TUSER_CT (Ciphertext).
 * Action: STRICT PASS-THROUGH. Do not apply padding. Do not alter `tkeep`.
 * Why? During decryption, the AEAD FSM needs the exact fractional Ciphertext
 * bytes to overwrite the state, AND it needs the raw `TKEEP` signal to know
 * exactly where (\ell) to manually inject the padding bits via XOR.
 *
 * Ref: NIST SP 800-232 (Algorithm 4 Decryption, Algorithm 5 Hashing)
 * ============================================================================= */

`timescale 1ns / 1ps

import ascon_pkg::*;

module ascon_padder (
    input  logic          clk,
    input  logic          rst,

    // -----------------------------------------------------------------------
    // Configuration
    // -----------------------------------------------------------------------
    input  ascon_mode_t   mode_i,

    // -----------------------------------------------------------------------
    // Raw AXI4-Stream Slave (Data FROM Outside World)
    // -----------------------------------------------------------------------
    input  ascon_word_t   s_axis_tdata,
    input  logic [7:0]    s_axis_tkeep,
    input  axi_tuser_t    s_axis_tuser,
    input  logic          s_axis_tlast,
    input  logic          s_axis_tvalid,
    output logic          s_axis_tready,

    // -----------------------------------------------------------------------
    // Padded AXI4-Stream Master (Data TO Top-Level Mux -> FSMs/Core)
    // -----------------------------------------------------------------------
    output ascon_word_t   padded_tdata,
    output logic [7:0]    padded_tkeep,  // Forced to 8'hFF, EXCEPT for TUSER_CT
    output axi_tuser_t    padded_tuser,
    output logic          padded_tlast,  // High only when the block is fully rate-aligned
    output logic          padded_tvalid,
    input  logic          padded_tready
);

    // =======================================================================
    // INTERNAL LOGIC DECLARATIONS
    // =======================================================================

    // State machine definition for tracking rate alignment (e.g., 64 vs 128 bit blocks)
    // and generating extra padding cycles if a block is perfectly aligned.
    typedef enum logic [1:0] {
        STATE_IDLE_PASS = 2'b00, // Passing data through normally
        STATE_PAD_WORD1 = 2'b01, // Padding the first word of a block
        STATE_PAD_WORD2 = 2'b10  // Generating the second empty padded word (AEAD only)
    } padder_state_t;

    padder_state_t state, next_state;

    // Combinational logic for the masked data output
    ascon_word_t masked_data;

endmodule