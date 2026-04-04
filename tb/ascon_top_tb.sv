/* =============================================================================
 * Module Name: ascon_top_tb
 * Author(s):   Kiet Le
 * Description:
 * End-to-end integration testbench for the Ascon Hardware Accelerator.
 * Dynamically compares the RTL output against the `permutations_sim_pkg`
 * software reference model to guarantee mathematical correctness.
 * ============================================================================= */

`timescale 1ns / 1ps
import ascon_pkg::*;
import permutations_sim_pkg::*;

module ascon_top_tb;

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
    logic           tag_fail_o;

    logic [63:0]    s_axis_tdata;
    logic [7:0]     s_axis_tkeep;
    logic [3:0]     s_axis_tuser;
    logic           s_axis_tlast;
    logic           s_axis_tvalid;
    logic           s_axis_tready;

    logic [63:0]    m_axis_tdata;
    logic [7:0]     m_axis_tkeep;
    logic [3:0]     m_axis_tuser;
    logic           m_axis_tlast;
    logic           m_axis_tvalid;
    logic           m_axis_tready;

    ascon_top dut (
        .clk            (clk),
        .rst            (rst),
        .mode_i         (mode_i),
        .xof_len_i      (xof_len_i),
        .start_i        (start_i),
        .abort_i        (abort_i),
        .busy_o         (busy_o),
        .done_o         (done_o),
        .tag_fail_o     (tag_fail_o),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tkeep   (s_axis_tkeep),
        .s_axis_tuser   (s_axis_tuser),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tkeep   (m_axis_tkeep),
        .m_axis_tuser   (m_axis_tuser),
        .m_axis_tlast   (m_axis_tlast),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready)
    );

    // =======================================================================
    // Clock & Simulated DMA (Backpressure)
    // =======================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    // Simulate downstream AXI DMA backpressure (Randomly stalls 20% of the time)
    always @(posedge clk) begin
        if (rst) m_axis_tready <= 1'b0;
        else m_axis_tready <= ($urandom_range(0, 100) > 20);
    end

    // =======================================================================
    // Testbench Helper Tasks
    // =======================================================================
    // Helper to simulate the Endian swap for comparison against the pure math model
    function automatic ascon_word_t swap_bytes(input ascon_word_t data);
        return {data[7:0],   data[15:8],  data[23:16], data[31:24],
                data[39:32], data[47:40], data[55:48], data[63:56]};
    endfunction

    task automatic apply_reset();
        rst = 1;
        start_i = 0; abort_i = 0;
        mode_i = MODE_HASH256; xof_len_i = 0;
        s_axis_tvalid = 0; s_axis_tlast = 0;
        s_axis_tdata = '0; s_axis_tkeep = '0; s_axis_tuser = '0;
        @(posedge clk); #1; rst = 0; @(posedge clk); #1;
    endtask

    // Simulates the host pushing raw unpadded data into the core
    task automatic send_axi_beat(
        input logic [63:0] data,
        input logic [7:0]  keep,
        input axi_tuser_t  tuser,
        input logic        is_last
    );
        s_axis_tdata  = data;
        s_axis_tkeep  = keep;
        s_axis_tuser  = tuser;
        s_axis_tlast  = is_last;
        s_axis_tvalid = 1'b1;

        do @(posedge clk); while (!s_axis_tready);
        #1;
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
    endtask

    // Captures the squeezed digest words outputted by the hardware
    task automatic collect_digest(input int expected_words, output ascon_word_t captured_data [16]);
        int words_collected = 0;
        while (words_collected < expected_words) begin
            @(posedge clk);
            if (m_axis_tvalid && m_axis_tready) begin
                captured_data[words_collected] = m_axis_tdata;
                words_collected++;

                if (m_axis_tlast && words_collected != expected_words) begin
                    $fatal(1, "[ERROR] Premature TLAST asserted by hardware at word %0d!", words_collected);
                end
            end
        end
        $display("   ---> Collected %0d squeezed words from AXI Master.", words_collected);
    endtask

    // =======================================================================
    // Main Test Execution
    // =======================================================================
    ascon_state_t sw_ref_state;
    ascon_word_t  hw_digest [16];
    ascon_word_t exp_digest [4];

    initial begin
        $display("\n===========================================================");
        $display("   Ascon System Integration & Math Verification");
        $display("===========================================================\n");

        // -------------------------------------------------------------------
        // TEST 1: Empty Message Debug (0 Bytes)
        // -------------------------------------------------------------------
        $display("[TEST 1] Empty Message Hash256 (0 Bytes)");
        apply_reset();

        // Set the mode BEFORE kicking off the hardware
        mode_i = MODE_HASH256; xof_len_i = 0;

        // 1. Calculate Expected Result using Software Reference Model (BIG ENDIAN)

        // --- Initialization ---
        sw_ref_state[0] = 64'h0000080100cc0002;
        sw_ref_state[1] = 64'b0;
        sw_ref_state[2] = 64'b0;
        sw_ref_state[3] = 64'b0;
        sw_ref_state[4] = 64'b0;

        sw_ref_state = ascon_perm(1'b1, sw_ref_state);

        // --- Absorbing (0 Bytes) ---
        sw_ref_state[0] = sw_ref_state[0] ^ 64'h8000_0000_0000_0000;

        // --- Squeezing ---
        sw_ref_state = ascon_perm(1'b1, sw_ref_state);

        // Pre-calculate all 4 expected output words
        exp_digest[0] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state);
        exp_digest[1] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state);
        exp_digest[2] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state);
        exp_digest[3] = sw_ref_state[0];

        // ===================================================================
        // 2. Drive the Hardware
        // ===================================================================
        // Pulse start EXACTLY ONCE to initialize the IV
        @(posedge clk); #1 start_i = 1; @(posedge clk); #1 start_i = 0;

        // 3. TRUE EMPTY MESSAGE INJECTION
        // The hardware is now permuting the IV. We queue up the AXI beat.
        // The FSM will naturally accept it as soon as it reaches STATE_ABSORB.
        send_axi_beat(64'h0000_0000_0000_0000, 8'h00, TUSER_MSG, 1'b1);

        // 4. Collect & Verify
        collect_digest(4, hw_digest);

        // Assert Pass/Fail
        if (swap_bytes(hw_digest[0]) !== exp_digest[0] ||
            swap_bytes(hw_digest[1]) !== exp_digest[1] ||
            swap_bytes(hw_digest[2]) !== exp_digest[2] ||
            swap_bytes(hw_digest[3]) !== exp_digest[3]) begin
            $fatal(1, "   [FAIL] Test 1: Digest mismatch detected. See debug output above.");
        end

        wait_for_done();
        $display("   [PASS] Test 1: Math perfectly matches Software Reference!\n");

        // -------------------------------------------------------------------
        // TEST 2: Exact Block Boundary (8 Bytes: "password")
        // -------------------------------------------------------------------
        $display("[TEST 2] Exact Block Boundary (String: 'password')");
        apply_reset();
        mode_i = MODE_HASH256; xof_len_i = 0;

        // 1. Calculate Expected Result using Software Reference Model (BIG ENDIAN)
        sw_ref_state[0] = 64'h0000080100cc0002;
        sw_ref_state[1] = 64'b0; sw_ref_state[2] = 64'b0; sw_ref_state[3] = 64'b0; sw_ref_state[4] = 64'b0;
        sw_ref_state    = ascon_perm(1'b1, sw_ref_state);

        // --- Absorbing ---
        // Block 1: "password" -> 64'h70617373776f7264
        sw_ref_state[0] = sw_ref_state[0] ^ 64'h70617373776f7264;
        sw_ref_state    = ascon_perm(1'b1, sw_ref_state);
        // Block 2: Padder spillover (0x80)
        sw_ref_state[0] = sw_ref_state[0] ^ 64'h8000_0000_0000_0000;
        // --- Squeezing ---
        sw_ref_state    = ascon_perm(1'b1, sw_ref_state);

        exp_digest[0] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state); exp_digest[1] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state); exp_digest[2] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state); exp_digest[3] = sw_ref_state[0];

        // 2. Drive the Hardware (LITTLE ENDIAN INJECTION)
        @(posedge clk); #1 start_i = 1; @(posedge clk); #1 start_i = 0;
        send_axi_beat(64'h6472_6f77_7373_6170, 8'hFF, TUSER_MSG, 1'b1); // tkeep=0xFF, tlast=1 forces padder carry block

        // 3. Collect & Verify
        collect_digest(4, hw_digest);
        if (swap_bytes(hw_digest[0]) !== exp_digest[0] || swap_bytes(hw_digest[1]) !== exp_digest[1] ||
            swap_bytes(hw_digest[2]) !== exp_digest[2] || swap_bytes(hw_digest[3]) !== exp_digest[3]) begin
            $fatal(1, "   [FAIL] Test 2: Digest mismatch on block boundary.");
        end
        wait_for_done();
        $display("   [PASS] Test 2: Block Boundary math matches!\n");

        // -------------------------------------------------------------------
        // TEST 3: Multi-Beat Unaligned (11 Bytes: "hello world")
        // -------------------------------------------------------------------
        $display("[TEST 3] Multi-Beat Unaligned (String: 'hello world')");
        apply_reset();
        mode_i = MODE_HASH256; xof_len_i = 0;

        // 1. Calculate Expected Result using Software Reference Model (BIG ENDIAN)
        sw_ref_state[0] = 64'h0000080100cc0002;
        sw_ref_state[1] = 64'b0; sw_ref_state[2] = 64'b0; sw_ref_state[3] = 64'b0; sw_ref_state[4] = 64'b0;
        sw_ref_state    = ascon_perm(1'b1, sw_ref_state);

        // --- Absorbing ---
        // Block 1: "hello wo" -> 64'h68656c6c6f20776f
        sw_ref_state[0] = sw_ref_state[0] ^ 64'h68656c6c6f20776f;
        sw_ref_state    = ascon_perm(1'b1, sw_ref_state);
        // Block 2: "rld" + padding -> 64'h726c648000000000
        sw_ref_state[0] = sw_ref_state[0] ^ 64'h726c648000000000;
        // --- Squeezing ---
        sw_ref_state    = ascon_perm(1'b1, sw_ref_state);

        exp_digest[0] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state); exp_digest[1] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state); exp_digest[2] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state); exp_digest[3] = sw_ref_state[0];

        // 2. Drive the Hardware (LITTLE ENDIAN INJECTION)
        @(posedge clk); #1 start_i = 1; @(posedge clk); #1 start_i = 0;
        send_axi_beat(64'h6f77_206f_6c6c_6568, 8'hFF, TUSER_MSG, 1'b0); // Beat 1: Full word, tlast=0
        send_axi_beat(64'h0000_0000_0064_6c72, 8'h07, TUSER_MSG, 1'b1); // Beat 2: 3 bytes valid, tlast=1

        // 3. Collect & Verify
        collect_digest(4, hw_digest);
        if (swap_bytes(hw_digest[0]) !== exp_digest[0] || swap_bytes(hw_digest[1]) !== exp_digest[1] ||
            swap_bytes(hw_digest[2]) !== exp_digest[2] || swap_bytes(hw_digest[3]) !== exp_digest[3]) begin
            $fatal(1, "   [FAIL] Test 3: Digest mismatch on multi-beat.");
        end
        wait_for_done();
        $display("   [PASS] Test 3: Multi-Beat math matches!\n");

        // -------------------------------------------------------------------
        // TEST 4: Single-Beat Unaligned (5 Bytes: "ascon")
        // -------------------------------------------------------------------
        $display("[TEST 4] Single-Beat Unaligned (String: 'ascon')");
        apply_reset();
        mode_i = MODE_HASH256; xof_len_i = 0;

        // 1. Calculate Expected Result using Software Reference Model (BIG ENDIAN)
        sw_ref_state[0] = 64'h0000080100cc0002;
        sw_ref_state[1] = 64'b0; sw_ref_state[2] = 64'b0; sw_ref_state[3] = 64'b0; sw_ref_state[4] = 64'b0;
        sw_ref_state    = ascon_perm(1'b1, sw_ref_state);

        // --- Absorbing ---
        sw_ref_state[0] = sw_ref_state[0] ^ 64'h6173636f6e800000;
        // --- Squeezing ---
        sw_ref_state    = ascon_perm(1'b1, sw_ref_state);

        exp_digest[0] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state); exp_digest[1] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state); exp_digest[2] = sw_ref_state[0];
        sw_ref_state  = ascon_perm(1'b1, sw_ref_state); exp_digest[3] = sw_ref_state[0];

        // 2. Drive the Hardware (LITTLE ENDIAN INJECTION)
        @(posedge clk); #1 start_i = 1; @(posedge clk); #1 start_i = 0;
        send_axi_beat(64'h0000_006e_6f63_7361, 8'h1F, TUSER_MSG, 1'b1);

        // 3. Collect & Verify
        collect_digest(4, hw_digest);
        if (swap_bytes(hw_digest[0]) !== exp_digest[0] || swap_bytes(hw_digest[1]) !== exp_digest[1] ||
            swap_bytes(hw_digest[2]) !== exp_digest[2] || swap_bytes(hw_digest[3]) !== exp_digest[3]) begin
            $fatal(1, "   [FAIL] Test 4: Digest mismatch on 'ascon'.");
        end
        wait_for_done();
        $display("   [PASS] Test 4: 'ascon' math matches!\n");

        $finish;
    end

    // Helper to monitor the done pulse
    task automatic wait_for_done();
        int timeout = 0;
        while (!done_o) begin
            @(posedge clk);
            timeout++;
            if (timeout > 2000) $fatal(1, "[TIMEOUT] Hardware locked up!");
        end
    endtask

endmodule
