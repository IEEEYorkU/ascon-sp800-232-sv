/*
 * Module Name: ascon_top
 * Author(s): Kiet Le
 * Description:
 * Top-level wrapper and routing arbiter for the Ascon Cryptographic 
 * Hardware Accelerator, supporting AEAD128, Hash256, XOF128, and CXOF128.
 *
 * Architecture Overview:
 * This design employs a "Decoupled Data/Control" strategy, strictly dividing
 * the cryptographic mathematics from the protocol-specific state machines:
 *
 * 1. The "Pure" Ascon Core (The Muscle): A centralized, protocol-agnostic
 * module that solely maintains the 320-bit state and executes the
 * mathematical permutation rounds (p_C, p_S, p_L). It possesses no
 * knowledge of encryption, hashing rules, or padding.
 *
 * 2. Dedicated Sub-FSMs (The Brains): Protocol-specific controllers
 * (e.g., aead_fsm, hash_fsm) that manage AXI-Stream handshaking,
 * domain separation, sponge padding rules, and external XOR computations
 * (resolving the Ascon decryption state-update conflict).
 *
 * 3. Top-Level Arbiter (This Module): Acts as a traffic director. Based
 * on the selected operating mode (mode_i), it multiplexes the AXI4-Stream
 * interfaces and core control signals (write_en, word_sel, start_perm)
 * between the active Sub-FSM and the centralized Ascon Core.
 *
 * Datapath Logistics:
 * - The 64-bit AXI4-Stream data input (s_axis_tdata) is routed directly
 * to the Ascon Core's input to minimize datapath latency and FSM bloating.
 * - The Sub-FSMs tap into the core's state output (core_data_o) as a
 * read-only bus to externally compute Plaintext (during decryption),
 * extract Hash digests, and verify the 128-bit MAC Tag.
 *
 * Interface Notes (Phase 1 Development):
 * High-speed payload data is streamed via standard AXI4-Stream interfaces.
 * Configuration and triggers are temporarily managed via discrete control
 * wires (mode_i, start_i, busy_o) to isolate and simplify datapath verification
 * before migrating to a standard memory-mapped AXI4-Lite CSR interface.
 *
 * Ref: NIST SP 800-232
 */

`timescale 1ns / 1ps

import ascon_pkg::*; // Imports TUSER enum definitions

module ascon_top #(
    // AXI4-Stream Parameters
    parameter int C_AXIS_TDATA_WIDTH = 64,
    parameter int C_AXIS_TUSER_WIDTH = 3
)(
    // -----------------------------------------------------------------------
    // Global Clock and Reset
    // -----------------------------------------------------------------------
    input  logic                                clk,
    input  logic                                rst,

    // -----------------------------------------------------------------------
    // Basic Control & Status Interface (Phase 1)
    // -----------------------------------------------------------------------
    // 00: AEAD128, 01: Hash256, 10: XOF128, 11: CXOF128
    input  logic [1:0]                          mode_i,
    input  logic                                start_i,     // Pulse high to begin
    output logic                                busy_o,      // High when FSM is active
    output logic                                done_o,      // Pulse high when complete
    output logic                                tag_fail_o,  // High if AEAD decryption MAC check fails

    // Note: If you plan to implement XOF128 in Phase 1, you will also need
    // an input here for the requested length L (e.g., input logic [31:0] xof_len_i).

    // -----------------------------------------------------------------------
    // AXI4-Stream Slave Interface (Data IN: Key, Nonce, AD, PT, CT)
    // -----------------------------------------------------------------------
    input  logic [C_AXIS_TDATA_WIDTH-1:0]       s_axis_tdata,
    input  logic [(C_AXIS_TDATA_WIDTH/8)-1:0]   s_axis_tkeep,  // Byte enables for padding
    input  logic [C_AXIS_TUSER_WIDTH-1:0]       s_axis_tuser,  // Packet type indicator
    input  logic                                s_axis_tlast,  // Boundary marker
    input  logic                                s_axis_tvalid,
    output logic                                s_axis_tready, // Tells master FSM is ready

    // -----------------------------------------------------------------------
    // AXI4-Stream Master Interface (Data OUT: CT, PT, Tag, Hash Digest)
    // -----------------------------------------------------------------------
    output logic [C_AXIS_TDATA_WIDTH-1:0]       m_axis_tdata,
    output logic [(C_AXIS_TDATA_WIDTH/8)-1:0]   m_axis_tkeep,
    output logic [C_AXIS_TUSER_WIDTH-1:0]       m_axis_tuser,  // Tells downstream if CT or Tag
    output logic                                m_axis_tlast,  // End of output stream
    output logic                                m_axis_tvalid,
    input  logic                                m_axis_tready
);

    // =========================================================================
    // Type Definitions
    // =========================================================================

    // --- Ascon Core Data-In Select Enum ---
    // Selects what data is being fed into the ascon core
    typedef enum logic [1:0] {
        DATA_IN_AXI_SEL    = 2'b00;
        DATA_IN_AEAD_SEL   = 2'b01;
        DATA_IN_HASH_SEL   = 2'b10;
        DATA_IN_XOR_SEL    = 2'b11;
    } data_sel_t;

    // =========================================================================
    // Logic Instantiations
    // =========================================================================

    // --- Ascon Core Signals ---
    logic           core_start_perm_i;
    logic           core_round_config_i;
    logic   [2:0]   core_word_sel_i;
    ascon_word_t    core_data_i;
    logic           core_write_en_i;
    logic           core_xor_en_i;
    ascon_word_t    core_data_o;
    logic           core_ready_o;

    // --- Arbiter Muxing FSM Logic ---
    // We define internal wires coming OUT of the sub-FSMs
    ascon_word_t    aead_data_i, hash_data_i;
    logic           aead_write_en, hash_write_en;
    logic [2:0]     aead_word_sel, hash_word_sel;
    logic           aead_start_perm, hash_start_perm;
    logic           aead_xor_en, hash_xor_en;
    logic [1:0]     aead_sel_data, hash_sel_data;
    ascon_word_t    aead_data_o, hash_data_o;

    // --- XOR Module Signals ---
    ascon_word_t xor_op1, xor_op2, xor_res;

    // --- AEAD FSM Intermediate Outputs ---
    logic        aead_busy, aead_done, aead_tag_fail;
    logic        aead_s_axis_tready;
    logic [63:0] aead_m_axis_tdata;
    logic [7:0]  aead_m_axis_tkeep;
    logic [2:0]  aead_m_axis_tuser;
    logic        aead_m_axis_tlast;
    logic        aead_m_axis_tvalid;

    // --- Hash FSM Intermediate Outputs ---
    logic        hash_busy, hash_done;
    logic        hash_s_axis_tready;
    logic [63:0] hash_m_axis_tdata;
    logic [7:0]  hash_m_axis_tkeep;
    logic [2:0]  hash_m_axis_tuser;
    logic        hash_m_axis_tlast;
    logic        hash_m_axis_tvalid;

    // =======================================================================
    // INTERNAL ARCHITECTURE & INSTANTIATIONS
    // =======================================================================

    // 1. Controller FSM
    // Your state machine that monitors `start_i` and `mode_i`.
    // It asserts `s_axis_tready` to pull data in, decodes `s_axis_tuser` to
    // know what the data is, and applies Ascon padding using `s_axis_tkeep`
    // when `s_axis_tlast` goes high.

    // The Top Level Mux directly feeds the Core based on the Mode
    always_comb begin
        if (mode_i == MODE_AEAD_ENC || mode_i == MODE_AEAD_DEC) begin
            // Core Control Muxing
            core_start_perm_i   = aead_start_perm;
            core_round_config_i = aead_round_config;
            core_word_sel_i     = aead_word_sel_i;
            core_write_en_i     = aead_write_en;
            core_xor_en_i       = aead_xor_en;
            core_in_data_sel    = aead_in_data_sel;

            // AXI Stream Handshake Muxing
            s_axis_tready       = aead_s_axis_tready;
            m_axis_tdata        = aead_m_axis_tdata;
            m_axis_tvalid       = aead_m_axis_tvalid;
            m_axis_tlast        = aead_m_axis_tlast;
            m_axis_tuser        = aead_m_axis_tuser;
            m_axis_tkeep        = aead_m_axis_tkeep;
        end else begin
            // Core Control Muxing
            core_start_perm_i   = hash_start_perm;
            core_round_config_i = hash_round_config;
            core_word_sel_i     = hash_word_sel_i;
            core_write_en_i     = hash_write_en;
            core_xor_en_i       = hash_xor_en;
            core_in_data_sel    = hash_in_data_sel;

            // AXI Stream Handshake Muxing
            s_axis_tready       = hash_s_axis_tready;
            m_axis_tdata        = hash_m_axis_tdata;
            m_axis_tvalid       = hash_m_axis_tvalid;
            m_axis_tlast        = hash_m_axis_tlast;
            m_axis_tuser        = hash_m_axis_tuser;
            m_axis_tkeep        = hash_m_axis_tkeep;
        end
    end

    // --- AEAD FSM ---
    aead_fsm u_aead_fsm (
        .clk            (clk),
        .rst            (rst),

        // AEAD FSM Control I/O
        .mode_i         (mode_i),
        .start_i        (start_i),           // Direct from top-level
        .busy_o         (aead_busy),         // Intermediate wire for muxing
        .done_o         (aead_done),         // Intermediate wire for muxing
        .tag_fail_o     (aead_tag_fail),     // Intermediate wire for muxing

        // Ascon Control I/O
        .ascon_ready_i  (core_ready_o),
        .start_perm_o   (aead_start_perm),
        .round_config_o (aead_round_config),
        .word_sel_o     (aead_word_sel),
        .data_o         (aead_data_o),
        .write_en_o     (aead_write_en),
        // .xor_en_o       (aead_xor_en),
        .in_data_sel_o  (aead_in_data_sel),
        .core_data_i    (core_data_o),       // Read state from core for Decryption/Tag

        // --- AXI4-Stream Slave (Data coming IN) ---
        // .s_axis_tdata_i  (s_axis_tdata),     // Direct from top-level
        .s_axis_tkeep_i  (s_axis_tkeep),     // Direct from top-level
        .s_axis_tuser_i  (s_axis_tuser),     // Direct from top-level
        .s_axis_tlast_i  (s_axis_tlast),     // Direct from top-level
        .s_axis_tvalid_i (s_axis_tvalid),    // Direct from top-level
        .s_axis_tready_o (aead_s_axis_tready), // Intermediate wire for muxing

        // --- AXI4-Stream Master (Data going OUT) ---
        //.m_axis_tdata_o  (aead_m_axis_tdata),  // Intermediate wire for muxing
        .m_axis_tkeep_o  (aead_m_axis_tkeep),  // Intermediate wire for muxing
        .m_axis_tuser_o  (aead_m_axis_tuser),  // Intermediate wire for muxing
        .m_axis_tlast_o  (aead_m_axis_tlast),  // Intermediate wire for muxing
        .m_axis_tvalid_o (aead_m_axis_tvalid), // Intermediate wire for muxing
        .m_axis_tready_i (m_axis_tready)       // Direct from top-level
    );

    hash_fsm u_hash_fsm (
        .clk            (clk),
        .rst            (rst),

        // Hash FSM Control I/O
        .mode_i         (mode_i),
        .start_i        (start_i),           // Direct from top-level
        .busy_o         (hash_busy),         // Intermediate wire for muxing
        .done_o         (hash_done),         // Intermediate wire for muxing
        // Note: No tag_fail_o needed for Hash/XOF operations

        // Ascon Control I/O
        .ascon_ready_i  (core_ready_o),
        .start_perm_o   (hash_start_perm),
        .round_config_o (hash_round_config),
        .word_sel_o     (hash_word_sel),
        .data_o         (hash_data_o),
        .write_en_o     (hash_write_en),
        // .xor_en_o       (hash_xor_en),
        .in_data_sel_o  (hash_in_data_sel),
        .core_data_i    (core_data_o),       // Read state from core for Squeezing!

        // --- AXI4-Stream Slave (Data coming IN) ---
        //.s_axis_tdata_i  (s_axis_tdata),     // Direct from top-level
        .s_axis_tkeep_i  (s_axis_tkeep),     // Direct from top-level
        .s_axis_tuser_i  (s_axis_tuser),     // Direct from top-level
        .s_axis_tlast_i  (s_axis_tlast),     // Direct from top-level
        .s_axis_tvalid_i (s_axis_tvalid),    // Direct from top-level
        .s_axis_tready_o (hash_s_axis_tready), // Intermediate wire for muxing

        // --- AXI4-Stream Master (Data going OUT) ---
        .m_axis_tdata_o  (hash_m_axis_tdata),  // Intermediate wire for muxing
        .m_axis_tkeep_o  (hash_m_axis_tkeep),  // Intermediate wire for muxing
        .m_axis_tuser_o  (hash_m_axis_tuser),  // Intermediate wire for muxing
        .m_axis_tlast_o  (hash_m_axis_tlast),  // Intermediate wire for muxing
        .m_axis_tvalid_o (hash_m_axis_tvalid), // Intermediate wire for muxing
        .m_axis_tready_i (m_axis_tready)       // Direct from top-level
    );

    xor64 u_xor64 (
        .op1_i  (xor_op1),
        .op2_i  (xor_op2),
        .res_o  (xor_res)
    )
    assign xor_op1 = core_data_o;
    // assign xor_op2 = 

    // --- Ascon Core ---
    ascon_core u_core (
        .clk            (clk),
        .rst            (rst),
        .start_perm_i   (core_start_perm_i),
        .round_config_i (core_round_config_i),
        .word_sel_i     (core_word_sel_i),
        .data_i         (core_data_i),
        .write_en_i     (core_write_en_i),
        // .xor_en_i       (core_xor_en_i),
        .data_o         (core_data_o),
        .ready_o        (core_ready_o)
    );
    // Select Data Input
    always_comb begin
        case(core_in_data_sel)
            DATA_IN_AXI_SEL  : core_data_i = s_axis_tdata;
            DATA_IN_AEAD_SEL : core_data_i = aead_core_data_o;
            DATA_IN_HASH_SEL : core_data_i = hash_core_data_o;
            DATA_IN_XOR_SEL  : core_data_i = xor_res;
            default          : core_data_i = 64'd0;
        endcase
    end

endmodule
