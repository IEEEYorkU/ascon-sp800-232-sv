/* =============================================================================
 * Module Name: hash_fsm_tb
 * Author(s):   Kiet Le
 * Description:
 * Verification environment for the Ascon-Hash/XOF Control FSM.
 * Simulates AXI-Stream backpressure and the Ascon datapath delay.
 * ============================================================================= */

`timescale 1ns / 1ps
import ascon_pkg::*;

module hash_fsm_tb;

    // =======================================================================
    // Signals & DUT Instantiation
    // =======================================================================
    logic           clk;
    logic           rst;

    ascon_mode_t    mode_i;
    logic [31:0]    xof_len_i;
    logic           start_i;
    logic           abort_i;
    logic           busy_o;
    logic           done_o;

    logic           ascon_ready_i;
    logic           start_perm_o;
    logic           round_config_o;
    logic [2:0]     word_sel_o;
    ascon_word_t    data_o;
    logic           write_en_o;
    logic [1:0]     core_in_data_sel_o;
    logic [1:0]     xor_sel_o;

    axi_tuser_t     padded_tuser_i;
    logic           padded_tlast_i;
    logic           padded_tvalid_i;
    logic           padded_tready_o;

    logic [7:0]     m_axis_tkeep_o;
    axi_tuser_t     m_axis_tuser_o;
    logic           m_axis_tlast_o;
    logic           m_axis_tvalid_o;
    logic           m_axis_tready_i;

    hash_fsm dut (.*);

    // =======================================================================
    // Phase 1: The "Mock" Environment
    // =======================================================================

    // 1. Clock Generation
    initial clk = 0;
    always #5 clk = ~clk;

    // 2. The Mock Ascon Core (Delay Simulator)
    initial begin
        ascon_ready_i = 1'b1;
        forever begin
            @(posedge clk);
            if (start_perm_o) begin
                #1 ascon_ready_i = 1'b0; // Core goes busy
                // Simulate 12 clock cycles of permutation math
                repeat(12) @(posedge clk);
                #1 ascon_ready_i = 1'b1; // Core is done
            end
        end
    end

    // 3. The Mock AXI Sink (Downstream DMA)
    initial begin
        m_axis_tready_i = 1'b1; // Always ready for this test
    end

    // =======================================================================
    // Testbench Handshake Tasks
    // =======================================================================
    task automatic apply_reset();
        rst = 1;
        start_i = 0; abort_i = 0;
        mode_i = MODE_HASH256; xof_len_i = 0;
        padded_tvalid_i = 0; padded_tlast_i = 0; padded_tuser_i = TUSER_MSG;
        @(posedge clk); #1; rst = 0; @(posedge clk); #1;
    endtask

    // Simulates the Padder sending a 64-bit word
    task automatic send_padded_beat(input logic is_last);
        padded_tvalid_i = 1'b1;
        padded_tlast_i  = is_last;
        // Wait until the FSM accepts the beat
        do @(posedge clk); while (!padded_tready_o);
        #1;
        padded_tvalid_i = 1'b0;
        padded_tlast_i  = 1'b0;
    endtask

    // Waits for the FSM to pulse the done signal
    task automatic wait_for_done();
        int timeout = 0;
        while (!done_o) begin
            @(posedge clk);
            timeout++;
            if (timeout > 500) begin
                $error("[TIMEOUT] FSM never asserted done_o!");
                $finish;
            end
        end
        $display(" ---> FSM Done Pulse Received.");
    endtask

    // =======================================================================
    // Phase 3: Hardware Monitors (The "Security" Checks)
    // =======================================================================

    // Snoop the internal FSM state for our assertions
    wire [2:0] internal_state = dut.state;

    always @(posedge clk) begin
        if (!rst) begin
            // 1. The Capacity Leak Monitor
            // 3'd4 is STATE_ABSORB, 3'd5 is STATE_SQUEEZE
            if ((internal_state == 3'd4 || internal_state == 3'd5) && word_sel_o != 3'd0) begin
                $fatal(1, "[SECURITY BREACH] FSM attempted to read/write capacity (lane %0d) during data transfer!", word_sel_o);
            end

            // 2. The Handshake Collision Monitor
            if (start_perm_o && !ascon_ready_i) begin
                $fatal(1, "[HANDSHAKE ERROR] FSM pulsed start_perm_o while core was already busy!");
            end
        end
    end

    // =======================================================================
    // Phase 2: Main Test Execution
    // =======================================================================
    initial begin
        $dumpfile("hash_fsm_tb.vcd");
        $dumpvars(0, hash_fsm_tb);

        $display("\n==================================================");
        $display("   Starting Ascon Hash FSM Verification");
        $display("==================================================\n");

        // -------------------------------------------------------------------
        // TEST 1: The "Happy Path" (Single-Block Hash256)
        // -------------------------------------------------------------------
        $display("[TEST 1] Single-Block Hash256 (1 Absorb, 4 Squeezes)");
        apply_reset();
        mode_i    = MODE_HASH256;
        xof_len_i = 0; // standard 256-bit hash

        @(posedge clk); #1 start_i = 1;
        @(posedge clk); #1 start_i = 0;

        // Send exactly 1 padded message block
        send_padded_beat(.is_last(1'b1));

        wait_for_done();
        $display("   [PASS] Test 1 Completed.\n");

        // -------------------------------------------------------------------
        // TEST 2: Multi-Block Absorb
        // -------------------------------------------------------------------
        $display("[TEST 2] Multi-Block Absorb (3 Absorbs, 4 Squeezes)");
        apply_reset();

        @(posedge clk); #1 start_i = 1;
        @(posedge clk); #1 start_i = 0;

        send_padded_beat(.is_last(1'b0)); // Block 1 (Not last)
        send_padded_beat(.is_last(1'b0)); // Block 2 (Not last)
        send_padded_beat(.is_last(1'b1)); // Block 3 (Last)

        wait_for_done();
        $display("   [PASS] Test 2 Completed.\n");

        // -------------------------------------------------------------------
        // TEST 3: Variable Length XOF Squeeze
        // -------------------------------------------------------------------
        $display("[TEST 3] Ascon-XOF Squeeze (10 Bytes = 2 Squeeze Words)");
        apply_reset();
        mode_i    = MODE_XOF;
        xof_len_i = 10; // 10 bytes should trigger the ceiling division to 2 words

        @(posedge clk); #1 start_i = 1;
        @(posedge clk); #1 start_i = 0;

        send_padded_beat(.is_last(1'b1));

        wait_for_done();
        $display("   [PASS] Test 3 Completed.\n");

        // -------------------------------------------------------------------
        $display("==================================================");
        $display("   ALL TESTS PASSED SUCCESSFULLY!");
        $display("==================================================\n");
        $finish;
    end

endmodule
