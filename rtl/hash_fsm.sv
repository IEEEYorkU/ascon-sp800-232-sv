/*
 * Module Name: hash_fsm
 * Author(s): Ailiya Jafri, Kiet Le
 * Description:
 * Control path orchestrator for Ascon-Hash256, Ascon-XOF128, and Ascon-CXOF128.
 * Interfaces with the Ascon Core and the Padder unit to absorb messages and
 * squeeze digests, supporting continuous squeeze mode via the abort_i signal.
 */

`timescale 1ns / 1ps
import ascon_pkg::*;

module hash_fsm (
    input  logic           clk,
    input  logic           rst,

    // -----------------------------------------------------------------------
    // Hash FSM Control I/O
    // -----------------------------------------------------------------------
    input  ascon_mode_t    mode_i,
    input  logic [31:0]    xof_len_i,     // 0 = Infinite/Continuous Mode, else specific byte length
    input  logic           start_i,
    input  logic           abort_i,       // Pulse high to terminate continuous squeezing
    output logic           busy_o,
    output logic           done_o,

    // -----------------------------------------------------------------------
    // Ascon Core Control I/O
    // -----------------------------------------------------------------------
    input  logic           ascon_ready_i,
    output logic           start_perm_o,
    output logic           round_config_o, // e.g., 0 for p^12, 1 for p^8
    output logic [2:0]     word_sel_o,
    output ascon_word_t    data_o,         // Used to write the pre-computed Hash IVs
    output logic           write_en_o,
    output logic [1:0]     core_in_data_sel_o,
    output logic [1:0]     xor_sel_o,

    // -----------------------------------------------------------------------
    // Padded AXI4-Stream Slave (Data coming FROM the Padder)
    // -----------------------------------------------------------------------
    input  axi_tuser_t     padded_tuser_i,
    input  logic           padded_tlast_i,
    input  logic           padded_tvalid_i,
    output logic           padded_tready_o,

    // -----------------------------------------------------------------------
    // AXI4-Stream Master (Data going OUT)
    // -----------------------------------------------------------------------
    output logic [7:0]     m_axis_tkeep_o,
    output axi_tuser_t     m_axis_tuser_o,
    output logic           m_axis_tlast_o,
    output logic           m_axis_tvalid_o,
    input  logic           m_axis_tready_i
);

    // =======================================================================
    // FSM State Declarations & Logic
    // =======================================================================
    typedef enum {
        STATE_IDLE,
        STATE_INIT,
        STATE_PERM,
        STATE_ABSORB,
        STATE_SQUEEZE
    } state_t;
    state_t state, next_state;

    // (State machine logic goes here)

    // =======================================================================
    // CONTROL FSM
    // =======================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // =======================================================================
    // NEXT STATE DECODER
    // =======================================================================
    always_comb begin
        next_state = state;

        unique case (state)
            STATE_IDLE: begin
                if (start_i) next_state = STATE_INIT;
            end

            STATE_INIT: begin
                // Wait until all 5 IV words are loaded
                if (word_cnt == 3'd4) next_state = STATE_PERM;
            end

            STATE_PERM: begin
                // Wait for the Core to finish the permutation cycles
                if (ascon_ready_i) begin
                    // If we just finished INIT or intermediate ABSORB
                    if (!padded_tlast_i)
                        next_state = STATE_ABSORB;
                    else
                        next_state = STATE_SQUEEZE;
                end
            end

            STATE_ABSORB: begin
                // Handshake with Padder; if data is consumed, permute it
                if (padded_tvalid_i && ascon_ready_i) begin
                    next_state = STATE_PERM;
                end
            end

            STATE_SQUEEZE: begin
                // Handshake with Master; if data is sent, check if done
                if (m_axis_tready_i) begin
                    if (squeeze_cnt == 3'd3 || abort_i)
                        next_state = STATE_IDLE;
                    else
                        next_state = STATE_PERM;
                end
            end

            default: next_state = STATE_IDLE;
        endcase
    end

    // =======================================================================
    // OUTPUT DECODER
    // =======================================================================
    always_comb begin
        // Default values
        busy_o             = 1'b1;
        done_o             = 1'b0;
        start_perm_o       = 1'b0;
        round_config_o     = 1'b0;
        write_en_o         = 1'b0;
        word_sel_o         = word_cnt;
        core_in_data_sel_o = 2'b00;
        xor_sel_o          = 2'b00;
        padded_tready_o    = 1'b0;
        m_axis_tvalid_o    = 1'b0;
        m_axis_tlast_o     = 1'b0;
        m_axis_tkeep_o     = 8'hFF;
        data_o             = 64'b0;

        unique case (state)
            STATE_IDLE: begin
                busy_o = 1'b0;
            end

            STATE_INIT: begin
                write_en_o = 1'b1;
                // data_o logic should be assigned here based on word_cnt
                // e.g., data_o = ASCON_HASH_IV[word_cnt];
            end

            STATE_PERM: begin
                // Signal the core to start the p12/p8 permutation
                if (ascon_ready_i) start_perm_o = 1'b1;
            end

            STATE_ABSORB: begin
                padded_tready_o = ascon_ready_i;
                xor_sel_o       = 2'b01; // Tells core to XOR padded_tdata into state
            end

            STATE_SQUEEZE: begin
                m_axis_tvalid_o = 1'b1;
                // Last block signal for AXI-Stream
                if (squeeze_cnt == 3'd3 || abort_i) begin
                    m_axis_tlast_o = 1'b1;
                    done_o = 1'b1;
                end
            end
        endcase
    end

endmodule
