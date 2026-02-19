/*
 * Module Name: constant_addition_layer_tb
 * Author(s): Patrick De Leo
 * Description:
 * Ref: NIST SP 800-232
 */

`timescale 1ns/1ps

import ascon_pkg::*;

module constant_addition_layer_tb;

    // Input and output signals for the dut
    logic round_config_i;
    rnd_t rnd_i;
    ascon_state_t state_array_i;
    ascon_state_t state_array_o;

    // Test signals
    ascon_state_t test_array_i;
    rnd_t test_rnd_i;

    constant_addition_layer dut (
        .round_config_i(round_config_i),
        .rnd_i(rnd_i),
        .state_array_i(state_array_i),
        .state_array_o(state_array_o)
    );

    /*
     * Checks that the s0 = x1, s1 = x1, s3 = x3 and s4 = x4
     * In other words, that these registers remainded unchanged from the input.
     * As per ascon blah blah blah
     */
    task automatic check_unchanged(
        input rnd_t rnd,
        input ascon_state_t exp,
        input ascon_state_t dut_out
    );
        assert(
            dut_out[0] == exp[0] &
            dut_out[1] == exp[1] &
            dut_out[3] == exp[3] &
            dut_out[4] == exp[4]
        )
            $display("OK. x0, x1, x3, x4 unchanged for Round: %d", rnd);
        else
            $error("Failed. Problem with x0, x1, x3, or x4 for Round: %d", rnd);
    endtask

    /*
     * Checks that the output register s2 = expected output
     */
    task automatic check_output(
        input rnd_t rnd,
        input ascon_state_t exp,
        input ascon_state_t dut_out
    );
        assert(
            dut_out[2] == (exp[2] ^ dut.AsconRcLut[rnd])
        )
            $display("OK. s2 = expected s2");
        else
            $error("Failed. Problem with s2.");
    endtask

    // Creates a random round number to aid in verifying correctness of hardware.
    task automatic rand_rnd(output rnd_t test_rnd);
        test_rnd = rnd_t'($urandom_range(0, 12));
    endtask

    // Generates a random input state array.
    task automatic rand_array(output ascon_state_t test_array);
        for (int i = 0; i < 5; i++) begin
            test_array[i] = {$urandom(), $urandom()};
        end
    endtask

    // Create clock
    logic clk;
    // Set up clock
    initial clk = 0;
    always #1 clk = ~clk;

    integer max_tests = 20;

    initial begin
        // *** Required for verilator ***
        $dumpfile("constant_addition_layer_tb.vcd");
        $dumpvars(0, constant_addition_layer_tb);

        // Test 1 All Zero Input Array
        $display("Test 1: All Zero Input...");
        test_array_i = '0;
        state_array_i = test_array_i;
        round_config_i = 1'd1;
        for (int i = 0; i < 12; i++) begin
            test_rnd_i = rnd_t'(i);
            rnd_i = test_rnd_i;
            #1;
            check_unchanged(test_rnd_i, test_array_i, state_array_o);
            check_output(test_rnd_i, test_array_i, state_array_o);
        end

        #1;

        // Test 2 Exhaustive Cases
        $display("Test 2: Exhaustive Random Input...");
        round_config_i = 1'd1;
        for (int i = 0; i < max_tests; i++) begin
            rand_rnd(test_rnd_i);
            rand_array(test_array_i);
            state_array_i = test_array_i;
            rnd_i = test_rnd_i;
            #1;
            check_unchanged(test_rnd_i, test_array_i, state_array_o);
            check_output(test_rnd_i, test_array_i, state_array_o);
        end

        #1;

        // Test 3 Round 8 All Zeros
        $display("Test 3: All Zero Input...");
        test_array_i = '0;
        state_array_i = test_array_i;
        round_config_i = 1'd0;
        for (int i = 0; i < 12; i++) begin
            test_rnd_i = rnd_t'(i);
            rnd_i = test_rnd_i;
            #1;
            check_unchanged(test_rnd_i + 4, test_array_i, state_array_o);
            check_output(test_rnd_i + 4, test_array_i, state_array_o);
        end

        #1;

        // Test 4 Round 8 Exhaustive Cases
        $display("Test 4: Exhaustive Random Input...");
        round_config_i = 0;
        for (int i = 0; i < max_tests; i++) begin
            rand_rnd(test_rnd_i);
            rand_array(test_array_i);
            state_array_i = test_array_i;
            rnd_i = test_rnd_i;
            #1;
            check_unchanged(test_rnd_i + 4, test_array_i, state_array_o);
            check_output(test_rnd_i + 4, test_array_i, state_array_o);
        end

        $finish;
    end

endmodule
